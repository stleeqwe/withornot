//
//  ChatViewModelTests.swift
//  withornotTests
//

import Testing
import Foundation
import FirebaseFirestore
@testable import withornot

@MainActor
struct ChatViewModelTests {

    // MARK: - Test Helpers

    func createMockPost(
        id: String = "post-123",
        meetTime: Date = Date().addingTimeInterval(2 * 60) // 2분 후 (채팅방 열림 상태)
    ) -> Post {
        var post = Post(
            creatorId: "creator1",
            message: "테스트 메시지",
            locationText: "테스트 장소",
            meetTime: meetTime,
            createdAt: Date(),
            creatorLocation: GeoPoint(latitude: 37.5665, longitude: 126.9780),
            participantIds: ["creator1", "user2"],
            status: .chatOpen,
            reportCount: 0
        )
        post.id = id
        return post
    }

    func createViewModel(post: Post? = nil) -> ChatViewModel {
        let testPost = post ?? createMockPost()
        return ChatViewModel(post: testPost)
    }

    // MARK: - Initial State Tests

    @Test func viewModel_initialState_hasEmptyNewMessageText() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.newMessageText == "")
    }

    @Test func viewModel_initialState_isChatExpiredIsFalse() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.isChatExpired == false)
    }

    @Test func viewModel_initialState_errorIsNil() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.error == nil)
    }

    @Test func viewModel_initialState_hasSystemMessage() async throws {
        let viewModel = createViewModel()

        // 시스템 메시지가 추가되어야 함
        #expect(viewModel.messages.count >= 1)

        if let firstMessage = viewModel.messages.first {
            #expect(firstMessage.userId == "system")
            #expect(firstMessage.text.contains("채팅방이 열렸습니다"))
        }
    }

    // MARK: - chatEndTime Tests

    @Test func chatEndTime_is5MinutesAfterMeetTime() async throws {
        let meetTime = Date().addingTimeInterval(10 * 60)
        let post = createMockPost(meetTime: meetTime)
        let viewModel = createViewModel(post: post)

        let expectedEndTime = meetTime.addingTimeInterval(5 * 60)
        let timeDifference = abs(viewModel.chatEndTime.timeIntervalSince(expectedEndTime))

        #expect(timeDifference < 1) // 1초 오차 허용
    }

    // MARK: - Configure Tests

    @Test func configure_setsAuthService() async throws {
        let viewModel = createViewModel()
        let authService = AuthService()

        viewModel.configure(authService: authService)

        // 중복 호출해도 에러 없음
        viewModel.configure(authService: authService)

        #expect(viewModel.error == nil)
    }

    // MARK: - isMyMessage Tests

    @Test func isMyMessage_withoutAuthService_returnsFalse() async throws {
        let viewModel = createViewModel()
        var message = Message(userId: "test-user", text: "테스트", timestamp: Date())
        message.id = "msg-1"

        // authService가 configure되지 않으면 false 반환
        #expect(viewModel.isMyMessage(message) == false)
    }

    @Test func isMyMessage_withSystemMessage_returnsFalse() async throws {
        let viewModel = createViewModel()
        var message = Message(userId: "system", text: "시스템 메시지", timestamp: Date())
        message.id = "msg-system"

        #expect(viewModel.isMyMessage(message) == false)
    }

    // MARK: - timeRemaining Tests

    @Test func timeRemaining_isNotEmpty() async throws {
        let viewModel = createViewModel()

        // 약간의 딜레이 후 확인 (타이머가 시작된 후)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1초

        #expect(viewModel.timeRemaining.isEmpty == false)
    }

    // MARK: - Chat Expiration Tests

    @Test func viewModel_withExpiredChat_setIsChatExpired() async throws {
        // 이미 만료된 시간으로 게시글 생성
        let expiredMeetTime = Date().addingTimeInterval(-10 * 60) // 10분 전
        let post = createMockPost(meetTime: expiredMeetTime)
        let viewModel = createViewModel(post: post)

        // 약간의 딜레이 후 확인 (타이머가 업데이트된 후)
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2초

        #expect(viewModel.isChatExpired == true)
        #expect(viewModel.timeRemaining == "채팅방이 종료되었습니다")
    }

    // MARK: - sendMessage Tests

    @Test func sendMessage_withEmptyText_doesNothing() async throws {
        let viewModel = createViewModel()
        viewModel.newMessageText = ""

        viewModel.sendMessage()

        // 에러 없이 완료 (아무것도 하지 않음)
        #expect(viewModel.error == nil)
    }

    @Test func sendMessage_withoutAuthService_doesNothing() async throws {
        let viewModel = createViewModel()
        viewModel.newMessageText = "테스트 메시지"

        viewModel.sendMessage()

        // authService가 nil이므로 early return
        // newMessageText가 변경되지 않음
        #expect(viewModel.newMessageText == "테스트 메시지")
    }

    // MARK: - reportMessage Tests

    @Test func reportMessage_withoutPostId_doesNothing() async throws {
        var post = createMockPost()
        post.id = nil
        let viewModel = createViewModel(post: post)

        var message = Message(userId: "user1", text: "테스트", timestamp: Date())
        message.id = "msg-1"

        viewModel.reportMessage(message)

        // post.id가 nil이므로 early return
        #expect(viewModel.error == nil)
    }

    @Test func reportMessage_withoutMessageId_doesNothing() async throws {
        let viewModel = createViewModel()

        var message = Message(userId: "user1", text: "테스트", timestamp: Date())
        message.id = nil

        viewModel.reportMessage(message)

        // message.id가 nil이므로 early return
        #expect(viewModel.error == nil)
    }

    // MARK: - reportChatRoom Tests

    @Test func reportChatRoom_withoutPostId_doesNothing() async throws {
        var post = createMockPost()
        post.id = nil
        let viewModel = createViewModel(post: post)

        viewModel.reportChatRoom()

        // post.id가 nil이므로 early return
        #expect(viewModel.error == nil)
    }
}
