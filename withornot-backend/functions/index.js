const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================================
// 상수 정의
// ============================================================================
const TimeConstants = {
    CHAT_WINDOW_BUFFER: 5 * 60 * 1000,      // 5분 (밀리초)
    POST_VALIDITY_PERIOD: 24 * 60 * 60 * 1000, // 24시간 (밀리초)
    REPORT_DELETE_THRESHOLD: 3,              // 신고 삭제 기준
    BATCH_SIZE: 500                          // Firestore 배치 제한
};

// ============================================================================
// 헬퍼 함수
// ============================================================================

/**
 * 여러 사용자 문서를 한 번에 조회 (N+1 문제 해결)
 */
async function getUserTokens(participantIds) {
    if (!participantIds || participantIds.length === 0) {
        return { tokens: [], userIdToTokenMap: {} };
    }

    const userRefs = participantIds.map(id => db.collection('users').doc(id));
    const userDocs = await db.getAll(...userRefs);

    const tokens = [];
    const userIdToTokenMap = {};

    userDocs.forEach((doc, index) => {
        if (doc.exists && doc.data().fcmToken) {
            const token = doc.data().fcmToken;
            tokens.push(token);
            userIdToTokenMap[token] = participantIds[index];
        }
    });

    return { tokens, userIdToTokenMap };
}

/**
 * 실패한 FCM 토큰 정리
 */
async function cleanupInvalidTokens(response, userIdToTokenMap) {
    const tokensToRemove = [];

    response.responses.forEach((resp, idx) => {
        if (!resp.success) {
            const error = resp.error;
            if (error && (
                error.code === 'messaging/invalid-registration-token' ||
                error.code === 'messaging/registration-token-not-registered'
            )) {
                const token = Object.keys(userIdToTokenMap)[idx];
                const userId = userIdToTokenMap[token];
                if (userId) {
                    tokensToRemove.push(userId);
                }
            }
        }
    });

    // 무효한 토큰 삭제
    const deletePromises = tokensToRemove.map(userId =>
        db.collection('users').doc(userId).update({
            fcmToken: admin.firestore.FieldValue.delete()
        }).catch(err => console.error(`Failed to remove token for ${userId}:`, err))
    );

    await Promise.all(deletePromises);

    if (tokensToRemove.length > 0) {
        console.log(`Cleaned up ${tokensToRemove.length} invalid FCM tokens`);
    }
}

/**
 * 배치 분할 커밋 (500개 제한 처리)
 */
async function commitBatchesWithLimit(operations) {
    if (operations.length === 0) return 0;

    let totalCommitted = 0;

    for (let i = 0; i < operations.length; i += TimeConstants.BATCH_SIZE) {
        const batch = db.batch();
        const chunk = operations.slice(i, i + TimeConstants.BATCH_SIZE);

        chunk.forEach(op => op(batch));
        await batch.commit();
        totalCommitted += chunk.length;
    }

    return totalCommitted;
}

// ============================================================================
// HTTP Callable Functions
// ============================================================================

/**
 * 채팅방 열림 알림 (T-5분)
 * - 인증 필수
 * - 참가자만 호출 가능
 */
exports.notifyChatOpen = functions
    .region('asia-northeast3')
    .https.onCall(async (data, context) => {
        // 1. 인증 검증
        if (!context.auth) {
            throw new functions.https.HttpsError(
                'unauthenticated',
                '로그인이 필요합니다'
            );
        }

        const { postId } = data;
        const callerId = context.auth.uid;

        if (!postId) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'postId가 필요합니다'
            );
        }

        try {
            const postDoc = await db.collection('posts').doc(postId).get();

            if (!postDoc.exists) {
                throw new functions.https.HttpsError('not-found', '게시글을 찾을 수 없습니다');
            }

            const post = postDoc.data();
            const participantIds = post.participantIds || [];

            // 2. 호출자가 참가자인지 검증
            if (!participantIds.includes(callerId)) {
                throw new functions.https.HttpsError(
                    'permission-denied',
                    '참가자만 알림을 보낼 수 있습니다'
                );
            }

            // 3. 배치로 사용자 토큰 조회 (N+1 문제 해결)
            const { tokens: userTokens, userIdToTokenMap } = await getUserTokens(participantIds);

            if (userTokens.length === 0) {
                return { success: true, message: '전송할 토큰이 없습니다' };
            }

            // 4. FCM 메시지 전송
            const message = {
                notification: {
                    title: '채팅방이 열렸습니다!',
                    body: `${post.locationText} 런닝 채팅방이 열렸어요`,
                },
                data: {
                    postId: postId,
                    type: 'chat_open'
                },
                apns: {
                    payload: {
                        aps: {
                            sound: 'default',
                            badge: 1
                        }
                    }
                },
                android: {
                    notification: {
                        sound: 'default',
                        priority: 'high'
                    }
                }
            };

            const response = await messaging.sendEachForMulticast({
                ...message,
                tokens: userTokens
            });

            // 5. 실패한 토큰 정리
            await cleanupInvalidTokens(response, userIdToTokenMap);

            console.log(`Notifications sent: ${response.successCount} success, ${response.failureCount} failed`);

            return {
                success: true,
                successCount: response.successCount,
                failureCount: response.failureCount
            };

        } catch (error) {
            console.error('Error sending notifications:', error);

            if (error instanceof functions.https.HttpsError) {
                throw error;
            }

            throw new functions.https.HttpsError(
                'internal',
                '알림 전송 중 오류가 발생했습니다'
            );
        }
    });

/**
 * 게시글/메시지 신고 (중복 방지)
 */
exports.reportContent = functions
    .region('asia-northeast3')
    .https.onCall(async (data, context) => {
        // 1. 인증 검증
        if (!context.auth) {
            throw new functions.https.HttpsError(
                'unauthenticated',
                '로그인이 필요합니다'
            );
        }

        const { contentType, contentId, postId } = data;
        const reporterId = context.auth.uid;

        if (!contentType || !contentId) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'contentType과 contentId가 필요합니다'
            );
        }

        if (contentType !== 'post' && contentType !== 'message') {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'contentType은 post 또는 message여야 합니다'
            );
        }

        if (contentType === 'message' && !postId) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                '메시지 신고에는 postId가 필요합니다'
            );
        }

        try {
            let docRef;
            if (contentType === 'post') {
                docRef = db.collection('posts').doc(contentId);
            } else {
                docRef = db.collection('chats').doc(postId).collection('messages').doc(contentId);
            }

            const result = await db.runTransaction(async (transaction) => {
                const doc = await transaction.get(docRef);

                if (!doc.exists) {
                    throw new functions.https.HttpsError('not-found', '콘텐츠를 찾을 수 없습니다');
                }

                const data = doc.data();
                const reportedBy = data.reportedBy || [];

                // 중복 신고 방지
                if (reportedBy.includes(reporterId)) {
                    return { alreadyReported: true };
                }

                const newReportedBy = [...reportedBy, reporterId];
                const newReportCount = newReportedBy.length;

                // 신고 기준 도달 시 삭제
                if (newReportCount >= TimeConstants.REPORT_DELETE_THRESHOLD) {
                    transaction.delete(docRef);
                    return { deleted: true, reportCount: newReportCount };
                } else {
                    transaction.update(docRef, {
                        reportedBy: newReportedBy,
                        reportCount: newReportCount
                    });
                    return { deleted: false, reportCount: newReportCount };
                }
            });

            if (result.alreadyReported) {
                return { success: true, message: '이미 신고한 콘텐츠입니다' };
            }

            return {
                success: true,
                deleted: result.deleted,
                reportCount: result.reportCount
            };

        } catch (error) {
            console.error('Error reporting content:', error);

            if (error instanceof functions.https.HttpsError) {
                throw error;
            }

            throw new functions.https.HttpsError(
                'internal',
                '신고 처리 중 오류가 발생했습니다'
            );
        }
    });

// ============================================================================
// Scheduled Functions
// ============================================================================

/**
 * 채팅방 자동 열기 (매분 실행)
 *
 * 채팅방 열림 기준:
 * - meetTime - 5분 <= now (5분 전부터 열림)
 * - meetTime + 5분 > now (5분 후까지 유지)
 */
exports.scheduledChatRoomCreation = functions
    .region('asia-northeast3')
    .runWith({ timeoutSeconds: 60, memory: '256MB' })
    .pubsub.schedule('every 1 minute')
    .timeZone('Asia/Seoul')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const nowMs = now.toDate().getTime();

        // 현재 시간 + 5분 = 5분 후까지의 약속을 찾음
        // meetTime <= now + 5분 → "5분 후 이내에 만남 시간인 약속"
        const fiveMinutesFromNow = new Date(nowMs + TimeConstants.CHAT_WINDOW_BUFFER);

        console.log('Chat room creation started', {
            now: now.toDate().toISOString(),
            lookingForMeetTimesBefore: fiveMinutesFromNow.toISOString()
        });

        try {
            // active 상태이고 meetTime이 5분 후 이하인 게시글 조회
            const postsSnapshot = await db.collection('posts')
                .where('status', '==', 'active')
                .where('meetTime', '<=', admin.firestore.Timestamp.fromDate(fiveMinutesFromNow))
                .get();

            const operations = [];

            postsSnapshot.docs.forEach(doc => {
                const post = doc.data();
                const meetTime = post.meetTime.toDate();
                const meetTimeMs = meetTime.getTime();

                // 채팅 시작: meetTime - 5분
                const chatStartTime = meetTimeMs - TimeConstants.CHAT_WINDOW_BUFFER;
                // 채팅 종료: meetTime + 5분
                const chatEndTime = meetTimeMs + TimeConstants.CHAT_WINDOW_BUFFER;

                // 현재 시간이 채팅 윈도우 내에 있는지 확인
                // chatStartTime <= now <= chatEndTime
                if (nowMs >= chatStartTime && nowMs <= chatEndTime) {
                    operations.push((batch) => {
                        batch.update(doc.ref, {
                            status: 'chatOpen',
                            chatOpenedAt: admin.firestore.FieldValue.serverTimestamp()
                        });
                    });

                    console.log('Opening chat room', {
                        postId: doc.id,
                        meetTime: meetTime.toISOString(),
                        participantCount: post.participantIds?.length || 0
                    });
                }
            });

            if (operations.length > 0) {
                await commitBatchesWithLimit(operations);
            }

            console.log(`Chat room creation completed: ${operations.length} posts updated`);
            return null;

        } catch (error) {
            console.error('Error in scheduled chat room creation:', error);
            return null;
        }
    });

/**
 * 만료된 게시글 정리 (매시간 실행)
 *
 * 정리 기준:
 * - meetTime + 1시간이 지난 게시글 (충분한 버퍼)
 */
exports.scheduledCleanup = functions
    .region('asia-northeast3')
    .runWith({ timeoutSeconds: 540, memory: '512MB' })
    .pubsub.schedule('every 1 hour')
    .timeZone('Asia/Seoul')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const nowMs = now.toDate().getTime();

        // meetTime + 1시간이 지난 게시글 정리
        const cleanupThreshold = new Date(nowMs - 60 * 60 * 1000);

        console.log('Cleanup started', {
            now: now.toDate().toISOString(),
            cleaningMeetTimesBefore: cleanupThreshold.toISOString()
        });

        try {
            // meetTime 기준으로 만료된 게시글 조회
            const expiredPostsSnapshot = await db.collection('posts')
                .where('meetTime', '<=', admin.firestore.Timestamp.fromDate(cleanupThreshold))
                .get();

            if (expiredPostsSnapshot.empty) {
                console.log('No expired posts to cleanup');
                return null;
            }

            const operations = [];

            // 각 게시글과 관련 채팅 메시지 삭제
            for (const doc of expiredPostsSnapshot.docs) {
                const chatRef = db.collection('chats').doc(doc.id);
                const messagesSnapshot = await chatRef.collection('messages').get();

                // 메시지 삭제 작업 추가
                messagesSnapshot.docs.forEach(msgDoc => {
                    operations.push((batch) => batch.delete(msgDoc.ref));
                });

                // 채팅 문서 및 게시글 삭제
                operations.push((batch) => batch.delete(chatRef));
                operations.push((batch) => batch.delete(doc.ref));

                console.log('Scheduling cleanup', {
                    postId: doc.id,
                    messageCount: messagesSnapshot.size
                });
            }

            const totalCommitted = await commitBatchesWithLimit(operations);

            console.log(`Cleanup completed: ${expiredPostsSnapshot.size} posts, ${totalCommitted} total operations`);
            return null;

        } catch (error) {
            console.error('Error in cleanup:', error);
            return null;
        }
    });

/**
 * 만료된 게시글 상태 업데이트 (매분 실행)
 *
 * chatOpen → expired 상태 변경
 */
exports.scheduledExpireChats = functions
    .region('asia-northeast3')
    .runWith({ timeoutSeconds: 60, memory: '256MB' })
    .pubsub.schedule('every 1 minute')
    .timeZone('Asia/Seoul')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const nowMs = now.toDate().getTime();

        // meetTime + 5분이 지난 게시글 = 채팅 종료
        const expireThreshold = new Date(nowMs - TimeConstants.CHAT_WINDOW_BUFFER);

        try {
            const expiredChatsSnapshot = await db.collection('posts')
                .where('status', '==', 'chatOpen')
                .where('meetTime', '<=', admin.firestore.Timestamp.fromDate(expireThreshold))
                .get();

            const operations = [];

            expiredChatsSnapshot.docs.forEach(doc => {
                operations.push((batch) => {
                    batch.update(doc.ref, { status: 'expired' });
                });

                console.log('Expiring chat room', { postId: doc.id });
            });

            if (operations.length > 0) {
                await commitBatchesWithLimit(operations);
            }

            console.log(`Expire chats completed: ${operations.length} posts expired`);
            return null;

        } catch (error) {
            console.error('Error expiring chats:', error);
            return null;
        }
    });
