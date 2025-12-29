import Foundation
import UserNotifications
import FirebaseFunctions
import Combine

/// 알림 관련 에러 타입
enum NotificationError: LocalizedError {
    case permissionDenied
    case schedulingFailed(Error)
    case sendFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "알림 권한이 거부되었습니다. 설정에서 알림을 허용해주세요."
        case .schedulingFailed:
            return "알림 예약에 실패했습니다."
        case .sendFailed:
            return "알림 전송에 실패했습니다."
        }
    }
}

@MainActor
class NotificationService: ObservableObject, NotificationServiceProtocol {
    @Published var hasPermission = false
    @Published var error: String?

    private lazy var functions = Functions.functions(region: FirebaseConstants.functionsRegion)

    init() {
        Task {
            await checkPermission()
        }
    }

    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        hasPermission = settings.authorizationStatus == .authorized
    }

    func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
                hasPermission = granted

                if !granted {
                    error = NotificationError.permissionDenied.localizedDescription
                }
            } catch {
                print("❌ Notification permission error: \(error.localizedDescription)")
                self.error = NotificationError.permissionDenied.localizedDescription
            }
        }
    }

    /// 로컬 알림 예약 (채팅방 열림 5분 전)
    func scheduleChatNotification(for post: Post) {
        guard hasPermission else {
            print("⚠️ Notification permission not granted")
            return
        }

        guard let postId = post.id else { return }

        let notificationTime = post.meetTime.addingTimeInterval(-TimeConstants.notificationBeforeMeetTime)
        guard notificationTime > Date() else {
            print("⚠️ Notification time is in the past")
            return
        }

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

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("❌ Notification scheduling error: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.error = NotificationError.schedulingFailed(error).localizedDescription
                }
            } else {
                print("✅ Notification scheduled for post: \(postId)")
            }
        }
    }

    /// 알림 취소
    func cancelNotification(for postId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["chat-\(postId)"]
        )
        print("🗑 Notification cancelled for post: \(postId)")
    }

    /// Cloud Function 호출 (채팅방 참가자에게 푸시)
    func notifyChatParticipants(postId: String) async throws {
        let data = ["postId": postId]

        do {
            let result = try await functions.httpsCallable("notifyChatOpen").call(data)
            print("✅ Notification sent: \(result.data)")
        } catch {
            print("❌ Failed to send notification: \(error.localizedDescription)")
            self.error = NotificationError.sendFailed(error).localizedDescription
            throw NotificationError.sendFailed(error)
        }
    }

    /// 에러 상태 초기화
    func clearError() {
        error = nil
    }
}
