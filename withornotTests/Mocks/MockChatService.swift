//
//  MockChatService.swift
//  withornotTests
//

import Foundation
import Combine
@testable import withornot

class MockChatService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var chatEndTime: Date?

    // 호출 추적
    var joinChatCalled = false
    var leaveChatCalled = false
    var sendMessageCalled = false
    var reportMessageCalled = false

    // 마지막 호출 파라미터
    var lastJoinedPostId: String?
    var lastJoinedMeetTime: Date?
    var lastSentPostId: String?
    var lastSentText: String?
    var lastSentUserId: String?
    var lastReportedPostId: String?
    var lastReportedMessageId: String?

    // 에러 시뮬레이션
    var shouldThrowError = false
    var errorToThrow: Error = ChatError.messageNotFound

    func joinChat(postId: String, meetTime: Date) {
        joinChatCalled = true
        lastJoinedPostId = postId
        lastJoinedMeetTime = meetTime
        chatEndTime = meetTime.addingTimeInterval(5 * 60)
        isLoading = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isLoading = false
        }
    }

    func leaveChat() {
        leaveChatCalled = true
        messages.removeAll()
        chatEndTime = nil
    }

    func sendMessage(postId: String, text: String, userId: String) async throws {
        sendMessageCalled = true
        lastSentPostId = postId
        lastSentText = text
        lastSentUserId = userId

        if shouldThrowError {
            throw errorToThrow
        }

        var newMessage = Message(
            userId: userId,
            text: text,
            timestamp: Date(),
            reportCount: 0
        )
        newMessage.id = UUID().uuidString

        await MainActor.run {
            self.messages.append(newMessage)
        }
    }

    func reportMessage(postId: String, messageId: String) async throws {
        reportMessageCalled = true
        lastReportedPostId = postId
        lastReportedMessageId = messageId

        if shouldThrowError {
            throw errorToThrow
        }

        await MainActor.run {
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                self.messages[index].reportCount += 1
                if self.messages[index].reportCount >= 3 {
                    self.messages.remove(at: index)
                }
            }
        }
    }

    // 테스트 헬퍼 메서드
    func addMockMessage(_ message: Message) {
        messages.append(message)
    }

    func reset() {
        messages.removeAll()
        isLoading = false
        chatEndTime = nil
        joinChatCalled = false
        leaveChatCalled = false
        sendMessageCalled = false
        reportMessageCalled = false
        shouldThrowError = false
    }
}
