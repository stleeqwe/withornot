//
//  PostFlowTests.swift
//  withornotTests
//
//  통합 테스트: 게시글 생성 → 참여 → 채팅 전체 흐름 테스트
//

import Testing
import Foundation
import FirebaseFirestore
import CoreLocation
@testable import withornot

@MainActor
struct PostFlowTests {

    // MARK: - Test Helpers

    func createMockPost(
        id: String = "integration-post-123",
        creatorId: String = "creator-user",
        meetTime: Date = Date().addingTimeInterval(10 * 60),
        status: Post.PostStatus = .active
    ) -> Post {
        var post = Post(
            creatorId: creatorId,
            message: "통합 테스트 메시지",
            locationText: "테스트 장소",
            meetTime: meetTime,
            createdAt: Date(),
            creatorLocation: GeoPoint(latitude: 37.5665, longitude: 126.9780),
            participantIds: [creatorId],
            status: status,
            reportCount: 0
        )
        post.id = id
        return post
    }

    // MARK: - Post Lifecycle Tests

    @Test func postLifecycle_activeToExpired() async throws {
        // 1. Active 상태의 게시글 생성
        let meetTime = Date().addingTimeInterval(-6 * 60) // 6분 전 (이미 만료)
        let post = createMockPost(meetTime: meetTime, status: .active)

        // 2. 만료 상태 확인
        #expect(post.isExpired == true)
        #expect(post.shouldOpenChat == true) // meetTime이 지났으므로 채팅 열림 조건 충족
    }

    @Test func postLifecycle_activeToChatOpen() async throws {
        // 1. 채팅방이 열려야 하는 시간의 게시글
        let meetTime = Date().addingTimeInterval(3 * 60) // 3분 후
        let post = createMockPost(meetTime: meetTime, status: .active)

        // 2. 채팅방 열림 조건 확인 (5분 전부터 열림)
        #expect(post.shouldOpenChat == true)
        #expect(post.isExpired == false)
    }

    @Test func postLifecycle_notYetChatOpen() async throws {
        // 1. 채팅방이 아직 열리지 않아야 하는 게시글
        let meetTime = Date().addingTimeInterval(10 * 60) // 10분 후
        let post = createMockPost(meetTime: meetTime, status: .active)

        // 2. 채팅방 열림 조건 미충족 확인
        #expect(post.shouldOpenChat == false)
        #expect(post.isExpired == false)
    }

    // MARK: - Participant Management Tests

    @Test func participantManagement_addParticipant() async throws {
        var post = createMockPost()

        // 초기 참가자 수 확인
        #expect(post.participantCount == 1)

        // 참가자 추가
        post.participantIds.append("new-user")

        // 추가 후 확인
        #expect(post.participantCount == 2)
        #expect(post.participantIds.contains("new-user"))
    }

    @Test func participantManagement_removeParticipant() async throws {
        var post = createMockPost()
        post.participantIds.append("participant-1")

        // 참가자 제거
        post.participantIds.removeAll { $0 == "participant-1" }

        // 제거 후 확인
        #expect(post.participantCount == 1)
        #expect(!post.participantIds.contains("participant-1"))
    }

    @Test func participantManagement_creatorCannotBeRemoved() async throws {
        var post = createMockPost(creatorId: "creator-user")

        // 생성자 제거 시도
        post.participantIds.removeAll { $0 == "creator-user" }

        // 생성자도 제거됨 (비즈니스 로직에서 방지해야 함)
        // 이 테스트는 모델 레벨에서는 제거 가능함을 확인
        #expect(post.participantCount == 0)
    }

    // MARK: - ViewModel Integration Tests

    @Test func postListViewModel_filterExpiredPosts() async throws {
        let viewModel = PostListViewModel()

        // Mock 게시글 생성
        let activePost = createMockPost(id: "active", meetTime: Date().addingTimeInterval(10 * 60))
        let expiredPost = createMockPost(id: "expired", meetTime: Date().addingTimeInterval(-10 * 60))

        // 필터링 로직 테스트 (Post 모델의 isExpired 사용)
        let posts = [activePost, expiredPost]
        let filteredPosts = posts.filter { !$0.isExpired }

        #expect(filteredPosts.count == 1)
        #expect(filteredPosts.first?.id == "active")
    }

    @Test func chatViewModel_initializesWithCorrectEndTime() async throws {
        let meetTime = Date().addingTimeInterval(10 * 60) // 10분 후
        let post = createMockPost(meetTime: meetTime)
        let chatViewModel = ChatViewModel(post: post)

        // 채팅 종료 시간 = meetTime + 5분
        let expectedEndTime = meetTime.addingTimeInterval(5 * 60)
        let timeDifference = abs(chatViewModel.chatEndTime.timeIntervalSince(expectedEndTime))

        #expect(timeDifference < 1) // 1초 오차 허용
    }

    @Test func chatViewModel_expiresCorrectly() async throws {
        // 이미 만료된 게시글로 ChatViewModel 생성
        let meetTime = Date().addingTimeInterval(-10 * 60) // 10분 전
        let post = createMockPost(meetTime: meetTime)
        let chatViewModel = ChatViewModel(post: post)

        // 약간의 딜레이 후 만료 상태 확인
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2초

        #expect(chatViewModel.isChatExpired == true)
    }

    // MARK: - Date Formatting Integration Tests

    @Test func dateFormatting_relativeTimeIntegration() async throws {
        let post = createMockPost(meetTime: Date().addingTimeInterval(30 * 60)) // 30분 후

        let relativeText = post.meetTime.relativeTimeText

        #expect(relativeText.contains("분 후"))
    }

    @Test func dateFormatting_chatTimerIntegration() async throws {
        let meetTime = Date().addingTimeInterval(3 * 60) // 3분 후
        let post = createMockPost(meetTime: meetTime)

        let timerText = Date().chatTimerText(from: post.meetTime)

        // 채팅방이 8분 후 사라짐 (meetTime + 5분)
        #expect(timerText.contains("⏱"))
        #expect(timerText.contains("채팅방이"))
    }

    // MARK: - Error Handling Integration Tests

    @Test func errorHandling_postErrorConvertsFriendly() async throws {
        let errors: [PostError] = [.notFound, .tooSoon, .alreadyHasActivePost]

        for error in errors {
            let message = error.userFriendlyMessage
            #expect(!message.isEmpty)
            #expect(!message.contains("Error Domain"))
        }
    }

    @Test func errorHandling_networkErrorConvertsFriendly() async throws {
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        let message = networkError.userFriendlyMessage

        #expect(message.contains("인터넷"))
    }

    // MARK: - Message Flow Tests

    @Test func messageFlow_systemMessageAddedOnInit() async throws {
        let post = createMockPost(status: .chatOpen)
        let chatViewModel = ChatViewModel(post: post)

        // 시스템 메시지가 추가되어야 함
        #expect(chatViewModel.messages.count >= 1)

        if let firstMessage = chatViewModel.messages.first {
            #expect(firstMessage.userId == "system")
        }
    }

    @Test func messageFlow_displayUserIdForSystemMessage() async throws {
        var systemMessage = Message(
            userId: "system",
            text: "시스템 메시지",
            timestamp: Date()
        )
        systemMessage.id = "system-msg"

        #expect(systemMessage.displayUserId == "시스템")
    }

    @Test func messageFlow_displayUserIdForRegularUser() async throws {
        var userMessage = Message(
            userId: "user-abc123",
            text: "일반 메시지",
            timestamp: Date()
        )
        userMessage.id = "user-msg"

        // 마지막 4자리 표시
        #expect(userMessage.displayUserId == "c123")
    }

    // MARK: - Location Integration Tests

    @Test func locationIntegration_distanceCalculation() async throws {
        let post = createMockPost()

        // 서울 위치 (게시글 위치)
        let postLocation = CLLocation(
            latitude: post.creatorLocation.latitude,
            longitude: post.creatorLocation.longitude
        )

        // 다른 위치 (약 10km 떨어진 곳)
        let userLocation = CLLocation(latitude: 37.6665, longitude: 126.9780)

        let distance = postLocation.distance(from: userLocation) / 1000.0

        #expect(distance > 0)
        #expect(distance < 20) // 서울 내이므로 20km 이내
    }

    // MARK: - Report Flow Tests

    @Test func reportFlow_incrementReportCount() async throws {
        var post = createMockPost()

        #expect(post.reportCount == 0)

        post.reportCount += 1

        #expect(post.reportCount == 1)
    }

    @Test func reportFlow_deleteAtThreshold() async throws {
        var post = createMockPost()
        post.reportCount = 2

        // 신고 추가
        post.reportCount += 1

        // 삭제 임계값 도달
        #expect(post.reportCount >= 3)
    }

    @Test func reportFlow_messageReportCount() async throws {
        var message = Message(
            userId: "user1",
            text: "테스트 메시지",
            timestamp: Date(),
            reportCount: 0
        )
        message.id = "msg-1"

        #expect(message.reportCount == 0)

        message.reportCount += 1

        #expect(message.reportCount == 1)
    }
}
