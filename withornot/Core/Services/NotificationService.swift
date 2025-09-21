import Foundation
import UserNotifications
import FirebaseFunctions
import Combine

class NotificationService: ObservableObject {
    @Published var hasPermission = false
    
    private lazy var functions = Functions.functions()
    
    init() {
        checkPermission()
    }
    
    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.hasPermission = granted
            }
        }
    }
    
    // 로컬 알림 예약 (채팅방 열림 5분 전)
    func scheduleChatNotification(for post: Post) {
        guard hasPermission else { return }
        guard let postId = post.id else { return }
        
        let notificationTime = post.meetTime.addingTimeInterval(-5 * 60)
        guard notificationTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "채팅방이 열렸습니다!"
        content.body = "\(post.locationText) 런닝 채팅방이 열렸어요"
        content.sound = .default
        content.userInfo = ["postId": postId]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: notificationTime.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "chat-\(postId)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    // 알림 취소
    func cancelNotification(for postId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["chat-\(postId)"]
        )
    }
    
    // Cloud Function 호출 (채팅방 참가자에게 푸시)
    func notifyChatParticipants(postId: String) async throws {
        let data = ["postId": postId]
        
        do {
            let result = try await functions.httpsCallable("notifyChatOpen").call(data)
            print("Notification sent: \(result.data)")
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
}
