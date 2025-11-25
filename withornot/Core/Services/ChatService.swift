import Foundation
import FirebaseFirestore
import Combine

class ChatService: ObservableObject, ChatServiceProtocol {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var chatEndTime: Date?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var timer: Timer?
    
    // 채팅방 입장
    func joinChat(postId: String, meetTime: Date) {
        // 채팅 종료 시간 설정 (만남 시간 + 5분)
        chatEndTime = meetTime.addingTimeInterval(5 * 60)
        
        // 기존 메시지 로드 및 실시간 리스닝
        startListening(postId: postId)
        
        // 채팅방 자동 종료 타이머
        startExpirationTimer()
    }
    
    func leaveChat() {
        stopListening()
        timer?.invalidate()
        timer = nil
        messages.removeAll()
        chatEndTime = nil
    }
    
    private func startListening(postId: String) {
        isLoading = true
        
        listener = db.collection("chats")
            .document(postId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false
                
                if let error = error {
                    print("Chat error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self?.messages = documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                }
            }
    }
    
    private func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // 메시지 전송
    func sendMessage(postId: String, text: String, userId: String) async throws {
        let message = Message(
            userId: userId,
            text: text,
            timestamp: Date(),
            reportCount: 0
        )
        
        _ = try db.collection("chats")
            .document(postId)
            .collection("messages")
            .addDocument(from: message)
    }
    
    // 메시지 신고
    func reportMessage(postId: String, messageId: String) async throws {
        let messageRef = db.collection("chats")
            .document(postId)
            .collection("messages")
            .document(messageId)

        _ = try await db.executeTransaction { transaction in
            var message = try messageRef.getDecodedDocument(in: transaction, as: Message.self)
            message.reportCount += 1

            if message.reportCount >= ReportThreshold.deleteAt {
                transaction.deleteDocument(messageRef)
            } else {
                try transaction.setData(from: message, forDocument: messageRef)
            }
            return ()
        }
    }
    
    // 채팅방 만료 타이머
    private func startExpirationTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let endTime = self?.chatEndTime else { return }
            
            if Date() >= endTime {
                self?.leaveChat()
            }
        }
    }
}

enum ChatError: LocalizedError {
    case messageNotFound
    
    var errorDescription: String? {
        switch self {
        case .messageNotFound:
            return "메시지를 찾을 수 없습니다"
        }
    }
}
