const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// 채팅방 열림 알림 (T-5분)
exports.notifyChatOpen = functions.https.onCall(async (data, context) => {
    const { postId } = data;
    
    if (!postId) {
        throw new functions.https.HttpsError('invalid-argument', 'postId is required');
    }
    
    try {
        const postDoc = await db.collection('posts').doc(postId).get();
        
        if (!postDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Post not found');
        }
        
        const post = postDoc.data();
        const participantIds = post.participantIds || [];
        
        const userTokens = [];
        for (const userId of participantIds) {
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists && userDoc.data().fcmToken) {
                userTokens.push(userDoc.data().fcmToken);
            }
        }
        
        if (userTokens.length === 0) {
            return { success: true, message: 'No tokens to send' };
        }
        
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
            }
        };
        
        const response = await messaging.sendMulticast({
            ...message,
            tokens: userTokens
        });
        
        return {
            success: true,
            successCount: response.successCount,
            failureCount: response.failureCount
        };
        
    } catch (error) {
        console.error('Error sending notifications:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

// 스케줄된 작업: 채팅방 자동 열기 (매분 실행)
// 채팅방 열림 기준: meetTime 5분 전 ~ meetTime 5분 후 (총 10분)
exports.scheduledChatRoomCreation = functions.pubsub
    .schedule('every 1 minutes')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const fiveMinutesFromNow = new Date(now.toDate().getTime() + 5 * 60 * 1000);
        const fiveMinutesAgo = new Date(now.toDate().getTime() - 5 * 60 * 1000);

        try {
            // meetTime이 5분 후 이하인 active 게시글 조회
            // (meetTime - 5분 <= now, 즉 now >= meetTime - 5분)
            const postsSnapshot = await db.collection('posts')
                .where('status', '==', 'active')
                .where('meetTime', '<=', admin.firestore.Timestamp.fromDate(fiveMinutesFromNow))
                .get();

            const batch = db.batch();
            let updatedCount = 0;

            postsSnapshot.docs.forEach(doc => {
                const post = doc.data();
                const meetTime = post.meetTime.toDate();

                // meetTime + 5분이 현재 시간보다 이후인 경우에만 chatOpen으로 변경
                // (아직 채팅 시간이 끝나지 않은 경우)
                const chatEndTime = new Date(meetTime.getTime() + 5 * 60 * 1000);
                if (chatEndTime > now.toDate()) {
                    batch.update(doc.ref, { status: 'chatOpen' });
                    updatedCount++;
                }
            });

            if (updatedCount > 0) {
                await batch.commit();
            }

            console.log(`Processed ${updatedCount} posts for chat room creation`);
            return null;

        } catch (error) {
            console.error('Error in scheduled chat room creation:', error);
            return null;
        }
    });

// 스케줄된 작업: 만료된 게시글 정리 (매시간 실행)
exports.scheduledCleanup = functions.pubsub
    .schedule('every 1 hours')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const oneDayAgo = new Date(now.toDate().getTime() - 24 * 60 * 60 * 1000);
        
        try {
            const expiredPostsSnapshot = await db.collection('posts')
                .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(oneDayAgo))
                .get();
            
            const batch = db.batch();
            
            for (const doc of expiredPostsSnapshot.docs) {
                const chatRef = db.collection('chats').doc(doc.id);
                const messagesSnapshot = await chatRef.collection('messages').get();
                
                messagesSnapshot.docs.forEach(msgDoc => {
                    batch.delete(msgDoc.ref);
                });
                
                batch.delete(chatRef);
                batch.delete(doc.ref);
            }
            
            await batch.commit();
            
            console.log(`Cleaned up ${expiredPostsSnapshot.size} expired posts`);
            return null;
            
        } catch (error) {
            console.error('Error in cleanup:', error);
            return null;
        }
    });