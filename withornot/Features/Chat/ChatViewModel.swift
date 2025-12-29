import Foundation
import Combine
import FirebaseFunctions

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var timeRemaining = ""
    @Published var isChatExpired = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var isSending = false

    private let post: Post
    private let chatService: ChatService
    private var authService: AuthService?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    private lazy var functions = Functions.functions(region: FirebaseConstants.functionsRegion)

    var chatEndTime: Date {
        post.meetTime.addingTimeInterval(post.chatCloseAfterTime)
    }

    init(post: Post, chatService: ChatService? = nil) {
        self.post = post
        self.chatService = chatService ?? ChatService()

        setupBindings()
    }

    /// EnvironmentObject에서 실제 서비스를 주입받아 설정
    func configure(authService: AuthService) {
        guard !isConfigured else { return }

        self.authService = authService
        self.isConfigured = true
    }

    /// 채팅방 입장 (View의 onAppear에서 호출)
    func joinChat() {
        guard let postId = post.id else { return }

        chatService.joinChat(postId: postId, meetTime: post.meetTime)
        startTimer()
        insertSystemMessage()
    }

    private func setupBindings() {
        chatService.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                // 시스템 메시지를 유지하면서 새 메시지 추가
                let systemMessages = self?.messages.filter { $0.userId == "system" } ?? []
                self?.messages = systemMessages + messages
            }
            .store(in: &cancellables)

        chatService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        chatService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)
    }

    private func insertSystemMessage() {
        let totalDuration = Int((post.chatOpenBeforeTime + post.chatCloseAfterTime) / 60)
        var systemMessage = Message(
            userId: "system",
            text: "채팅방이 열렸습니다. 약속 시간 전후 총 \(totalDuration)분간 유지됩니다.",
            timestamp: Date()
        )
        systemMessage.id = UUID().uuidString
        messages.insert(systemMessage, at: 0)
    }

    // MARK: - Timer Management

    private func startTimer() {
        stopTimer()

        updateTimeRemaining()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimeRemaining()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTimeRemaining() {
        let remaining = chatEndTime.timeIntervalSinceNow

        if remaining <= 0 {
            timeRemaining = "채팅방이 종료되었습니다"
            isChatExpired = true
            stopTimer()
            chatService.leaveChat()
        } else {
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            timeRemaining = "채팅방이 \(minutes)분 \(seconds)초 후 사라집니다"
        }
    }

    // MARK: - Message Operations

    func sendMessage() {
        let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty,
              let postId = post.id,
              let userId = authService?.currentUser?.id else { return }

        let previousText = newMessageText
        newMessageText = ""
        isSending = true

        Task { [weak self] in
            do {
                try await self?.chatService.sendMessage(
                    postId: postId,
                    text: text,
                    userId: userId
                )
                self?.isSending = false
            } catch {
                // 전송 실패 시 메시지 복원
                self?.newMessageText = previousText
                self?.isSending = false
                self?.error = error.userFriendlyMessage
            }
        }
    }

    func reportMessage(_ message: Message) {
        guard let postId = post.id,
              let messageId = message.id else { return }

        Task { [weak self] in
            do {
                try await self?.chatService.reportMessage(
                    postId: postId,
                    messageId: messageId
                )
            } catch {
                self?.error = error.userFriendlyMessage
            }
        }
    }

    func isMyMessage(_ message: Message) -> Bool {
        guard let userId = authService?.currentUser?.id else { return false }
        return message.userId == userId
    }

    func isSystemMessage(_ message: Message) -> Bool {
        return message.userId == "system"
    }

    /// 채팅방(게시글) 신고
    func reportChatRoom() {
        guard let postId = post.id else { return }

        Task { [weak self] in
            do {
                let data: [String: Any] = [
                    "contentType": "post",
                    "contentId": postId
                ]

                let result = try await self?.functions.httpsCallable("reportContent").call(data)

                if let resultData = result?.data as? [String: Any] {
                    if resultData["deleted"] as? Bool == true {
                        print("🗑 Chat room deleted due to reports")
                    } else if resultData["alreadyReported"] as? Bool == true {
                        self?.error = "이미 신고한 채팅방입니다"
                    } else {
                        print("✅ Chat room reported")
                    }
                }
            } catch {
                self?.error = error.userFriendlyMessage
            }
        }
    }

    /// 에러 상태 초기화
    func clearError() {
        error = nil
    }

    /// 채팅방 퇴장
    func leaveChat() {
        stopTimer()
        chatService.leaveChat()
    }

    deinit {
        timer?.invalidate()
    }
}
