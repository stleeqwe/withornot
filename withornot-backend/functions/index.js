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
exports.scheduledChatRoomCreation = functions.pubsub
    .schedule('every 1 minutes')
    .onRun(async (context) => {
        const now = admin.firestore.Timestamp.now();
        const fiveMinutesLater = new Date(now.toDate().getTime() + 5 * 60 * 1000);
        
        try {
            const postsSnapshot = await db.collection('posts')
                .where('status', '==', 'active')
                .where('meetTime', '>=', now)
                .where('meetTime', '<=', admin.firestore.Timestamp.fromDate(fiveMinutesLater))
                .get();
            
            const batch = db.batch();
            
            postsSnapshot.docs.forEach(doc => {
                batch.update(doc.ref, { status: 'chatOpen' });
            });
            
            await batch.commit();
            
            console.log(`Processed ${postsSnapshot.size} posts for chat room creation`);
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