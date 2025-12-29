//
//  PostTests.swift
//  withornotTests
//

import Testing
import Foundation
import CoreLocation
import FirebaseFirestore
@testable import withornot

struct PostTests {

    // MARK: - Test Helpers

    func createMockPost(
        meetTime: Date = Date().addingTimeInterval(30 * 60),
        category: Post.Category = .run,
        status: Post.PostStatus = .active,
        participantIds: [String] = ["user1"],
        reportCount: Int = 0
    ) -> Post {
        return Post(
            creatorId: "creator1",
            category: category,
            message: "테스트 메시지",
            locationText: "테스트 장소",
            meetTime: meetTime,
            createdAt: Date(),
            creatorLocation: GeoPoint(latitude: 37.5665, longitude: 126.9780),
            participantIds: participantIds,
            status: status,
            reportCount: reportCount
        )
    }

    // MARK: - participantCount Tests

    @Test func participantCount_withEmptyParticipants_returnsZero() async throws {
        var post = createMockPost()
        post.participantIds = []

        #expect(post.participantCount == 0)
    }

    @Test func participantCount_withMultipleParticipants_returnsCorrectCount() async throws {
        var post = createMockPost()
        post.participantIds = ["user1", "user2", "user3"]

        #expect(post.participantCount == 3)
    }

    // MARK: - timeUntilMeet Tests

    @Test func timeUntilMeet_withFutureMeetTime_returnsPositiveInterval() async throws {
        let futureTime = Date().addingTimeInterval(60 * 60) // 1시간 후
        let post = createMockPost(meetTime: futureTime)

        #expect(post.timeUntilMeet > 0)
        #expect(post.timeUntilMeet <= 60 * 60)
    }

    @Test func timeUntilMeet_withPastMeetTime_returnsNegativeInterval() async throws {
        let pastTime = Date().addingTimeInterval(-60 * 60) // 1시간 전
        let post = createMockPost(meetTime: pastTime)

        #expect(post.timeUntilMeet < 0)
    }

    // MARK: - shouldOpenChat Tests

    @Test func shouldOpenChat_moreThan5MinutesAway_returnsFalse() async throws {
        let futureTime = Date().addingTimeInterval(10 * 60) // 10분 후
        let post = createMockPost(meetTime: futureTime)

        #expect(post.shouldOpenChat == false)
    }

    @Test func shouldOpenChat_within5MinutesBefore_returnsTrue() async throws {
        let soonTime = Date().addingTimeInterval(3 * 60) // 3분 후
        let post = createMockPost(meetTime: soonTime)

        #expect(post.shouldOpenChat == true)
    }

    @Test func shouldOpenChat_within5MinutesAfter_returnsTrue() async throws {
        let recentPastTime = Date().addingTimeInterval(-3 * 60) // 3분 전
        let post = createMockPost(meetTime: recentPastTime)

        #expect(post.shouldOpenChat == true)
    }

    @Test func shouldOpenChat_moreThan5MinutesAgo_returnsFalse() async throws {
        let pastTime = Date().addingTimeInterval(-10 * 60) // 10분 전
        let post = createMockPost(meetTime: pastTime)

        #expect(post.shouldOpenChat == false)
    }

    // MARK: - isExpired Tests

    @Test func isExpired_withinValidTime_returnsFalse() async throws {
        let recentPastTime = Date().addingTimeInterval(-3 * 60) // 3분 전
        let post = createMockPost(meetTime: recentPastTime)

        #expect(post.isExpired == false)
    }

    @Test func isExpired_moreThan5MinutesAgo_returnsTrue() async throws {
        let expiredTime = Date().addingTimeInterval(-10 * 60) // 10분 전
        let post = createMockPost(meetTime: expiredTime)

        #expect(post.isExpired == true)
    }

    @Test func isExpired_futureMeetTime_returnsFalse() async throws {
        let futureTime = Date().addingTimeInterval(30 * 60) // 30분 후
        let post = createMockPost(meetTime: futureTime)

        #expect(post.isExpired == false)
    }

    // MARK: - distance Tests

    @Test func distance_fromSameLocation_returnsZero() async throws {
        let post = createMockPost()
        let userLocation = CLLocation(latitude: 37.5665, longitude: 126.9780)

        let distance = post.distance(from: userLocation)

        #expect(distance < 0.01) // 거의 0km
    }

    @Test func distance_fromDifferentLocation_returnsCorrectDistance() async throws {
        let post = createMockPost() // 서울 시청 좌표
        let userLocation = CLLocation(latitude: 37.5796, longitude: 126.9770) // 광화문 좌표

        let distance = post.distance(from: userLocation)

        #expect(distance > 0)
        #expect(distance < 5) // 5km 이내
    }

    // MARK: - PostStatus Tests

    @Test func postStatus_activeRawValue() async throws {
        #expect(Post.PostStatus.active.rawValue == "active")
    }

    @Test func postStatus_chatOpenRawValue() async throws {
        #expect(Post.PostStatus.chatOpen.rawValue == "chatOpen")
    }

    @Test func postStatus_expiredRawValue() async throws {
        #expect(Post.PostStatus.expired.rawValue == "expired")
    }

    // MARK: - Category Tests

    @Test func category_runRawValue() async throws {
        #expect(Post.Category.run.rawValue == "run")
    }

    @Test func category_mealRawValue() async throws {
        #expect(Post.Category.meal.rawValue == "meal")
    }

    @Test func category_runDisplayName() async throws {
        #expect(Post.Category.run.displayName == "런벙")
    }

    @Test func category_mealDisplayName() async throws {
        #expect(Post.Category.meal.displayName == "밥벙")
    }

    @Test func category_runIcon() async throws {
        #expect(Post.Category.run.icon == "figure.run")
    }

    @Test func category_mealIcon() async throws {
        #expect(Post.Category.meal.icon == "fork.knife")
    }

    @Test func createPost_withRunCategory() async throws {
        let post = createMockPost(category: .run)
        #expect(post.category == .run)
    }

    @Test func createPost_withMealCategory() async throws {
        let post = createMockPost(category: .meal)
        #expect(post.category == .meal)
    }

    // MARK: - canToggleParticipation Tests

    @Test func canToggleParticipation_moreThan5MinutesBefore_returnsTrue() async throws {
        let futureTime = Date().addingTimeInterval(10 * 60) // 10분 후
        let post = createMockPost(meetTime: futureTime)

        #expect(post.canToggleParticipation == true)
    }

    @Test func canToggleParticipation_lessThan5MinutesBefore_returnsFalse() async throws {
        let soonTime = Date().addingTimeInterval(3 * 60) // 3분 후
        let post = createMockPost(meetTime: soonTime)

        #expect(post.canToggleParticipation == false)
    }

    @Test func canToggleParticipation_afterMeetTime_returnsFalse() async throws {
        let pastTime = Date().addingTimeInterval(-1 * 60) // 1분 전
        let post = createMockPost(meetTime: pastTime)

        #expect(post.canToggleParticipation == false)
    }
}
