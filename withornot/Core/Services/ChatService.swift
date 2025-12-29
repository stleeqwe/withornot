import Foundation
import FirebaseFirestore
import FirebaseFunctions
import Combine

@MainActor
class ChatService: ObservableObject, ChatServiceProtocol {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var chatEndTime: Date?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var timer: Timer?
    private lazy var functions = Functions.functions(region: FirebaseConstants.functionsRegion)

    // MARK: - Chat Lifecycle

    /// 채팅방 입장
    func joinChat(postId: String, meetTime: Date) {
        // 채팅 종료 시간 설정 (만남 시간 + 5분)
        chatEndTime = meetTime.addingTimeInterval(TimeConstants.chatCloseAfterMeetTime)

        // 기존 메시지 로드 및 실시간 리스닝
        startListening(postId: postId)

        // 채팅방 자동 종료 타이머
        startExpirationTimer()

        print("💬 Joined chat room: \(postId)")
    }

    /// 채팅방 퇴장
    func leaveChat() {
        stopListening()
        stopTimer()
        messages.removeAll()
        chatEndTime = nil
        error = nil

        print("👋 Left chat room")
    }

    // MARK: - Message Listening

    private func startListening(postId: String) {
        isLoading = true

        listener = db.collection("chats")
            .document(postId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.isLoading = false

                    if let error = error {
                        print("❌ Chat error: \(error.localizedDescription)")
                        self?.error = error.userFriendlyMessage
                        return
                    }

                    guard let documents = snapshot?.documents else { return }

                    self?.messages = documents.compactMap { doc in
                        try? doc.data(as: Message.self)
                    }
                }
            }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Message Operations

    /// 메시지 전송
    func sendMessage(postId: String, text: String, userId: String) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else { return }
        guard trimmedText.count <= ValidationConstants.maxMessageLength else {
            error = "메시지가 너무 깁니다 (최대 \(ValidationConstants.maxMessageLength)자)"
            return
        }

        let message = Message(
            userId: userId,
            text: trimmedText,
            timestamp: Date(),
            reportCount: 0
        )

        do {
            _ = try db.collection("chats")
                .document(postId)
                .collection("messages")
                .addDocument(from: message)

            print("✅ Message sent")
        } catch {
            print("❌ Failed to send message: \(error.localizedDescription)")
            self.error = "메시지 전송에 실패했습니다"
            throw error
        }
    }

    /// 메시지 신고 (Cloud Functions 호출)
    func reportMessage(postId: String, messageId: String) async throws {
        let data: [String: Any] = [
            "contentType": "message",
            "contentId": messageId,
            "postId": postId
        ]

        do {
            let result = try await functions.httpsCallable("reportContent").call(data)

            if let resultData = result.data as? [String: Any] {
                if resultData["deleted"] as? Bool == true {
                    print("🗑 Message deleted due to reports")
                } else if resultData["alreadyReported"] as? Bool == true {
                    self.error = "이미 신고한 메시지입니다"
                } else {
                    print("✅ Message reported")
                }
            }
        } catch {
            print("❌ Failed to report message: \(error.localizedDescription)")
            self.error = "신고 처리에 실패했습니다"
            throw error
        }
    }

    // MARK: - Timer Management

    private func startExpirationTimer() {
        stopTimer() // 기존 타이머 정리

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let endTime = self?.chatEndTime else { return }

                if Date() >= endTime {
                    self?.leaveChat()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Cleanup

    /// 에러 상태 초기화
    func clearError() {
        error = nil
    }

    deinit {
        timer?.invalidate()
        listener?.remove()
    }
}

// MARK: - Chat Errors

enum ChatError: LocalizedError {
    case messageNotFound
    case messageTooLong
    case sendFailed(Error)

    var errorDescription: String? {
        switch self {
        case .messageNotFound:
            return "메시지를 찾을 수 없습니다"
        case .messageTooLong:
            return "메시지가 너무 깁니다 (최대 1000자)"
        case .sendFailed:
            return "메시지 전송에 실패했습니다"
        }
    }
}
