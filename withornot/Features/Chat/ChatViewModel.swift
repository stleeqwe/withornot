import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var newMessageText = ""
    @Published var timeRemaining = ""
    @Published var isChatExpired = false
    @Published var isLoading = false
    @Published var error: String?

    private let post: Post
    private let chatService: ChatService
    private let postService: PostService
    private var authService: AuthService?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false

    var chatEndTime: Date {
        post.meetTime.addingTimeInterval(5 * 60)
    }

    init(post: Post,
         chatService: ChatService = ChatService(),
         postService: PostService = PostService()) {
        self.post = post
        self.chatService = chatService
        self.postService = postService

        setupBindings()
        startChat()
    }

    /// EnvironmentObject에서 실제 서비스를 주입받아 설정
    func configure(authService: AuthService) {
        guard !isConfigured else { return }

        self.authService = authService
        self.isConfigured = true
    }

    private func setupBindings() {
        chatService.$messages
            .assign(to: &$messages)

        chatService.$isLoading
            .assign(to: &$isLoading)
    }

    private func startChat() {
        guard let postId = post.id else { return }

        chatService.joinChat(postId: postId, meetTime: post.meetTime)
        startTimer()

        // 시스템 메시지 추가
        var systemMessage = Message(
            userId: "system",
            text: "채팅방이 열렸습니다. 5분 후 자동으로 사라집니다.",
            timestamp: Date()
        )
        systemMessage.id = UUID().uuidString
        messages.insert(systemMessage, at: 0)
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
    }
    
    private func updateTimeRemaining() {
        let remaining = chatEndTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            timeRemaining = "채팅방이 종료되었습니다"
            isChatExpired = true
            timer?.invalidate()
            timer = nil
            chatService.leaveChat()
        } else {
            let minutes = Int(remaining / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            timeRemaining = "⏱ 채팅방이 \(minutes)분 \(seconds)초 후 사라집니다"
        }
    }
    
    func sendMessage() {
        guard !newMessageText.isEmpty,
              let postId = post.id,
              let userId = authService?.currentUser?.id else { return }
        
        let text = newMessageText
        newMessageText = ""
        
        Task {
            do {
                try await chatService.sendMessage(
                    postId: postId,
                    text: text,
                    userId: userId
                )
            } catch {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                }
            }
        }
    }
    
    func reportMessage(_ message: Message) {
        guard let postId = post.id,
              let messageId = message.id else { return }
        
        Task {
            do {
                try await chatService.reportMessage(
                    postId: postId,
                    messageId: messageId
                )
            } catch {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                }
            }
        }
    }
    
    func isMyMessage(_ message: Message) -> Bool {
        guard let userId = authService?.currentUser?.id else { return false }
        return message.userId == userId
    }

    /// 채팅방(게시글) 신고
    func reportChatRoom() {
        guard let postId = post.id else { return }

        Task {
            do {
                try await postService.reportPost(postId: postId)
            } catch {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                }
            }
        }
    }

    deinit {
        timer?.invalidate()
        chatService.leaveChat()
    }
}
