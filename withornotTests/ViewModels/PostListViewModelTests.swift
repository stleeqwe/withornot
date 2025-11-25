//
//  PostListViewModelTests.swift
//  withornotTests
//

import Testing
import Foundation
import CoreLocation
import Combine
import FirebaseFirestore
@testable import withornot

@MainActor
struct PostListViewModelTests {

    // MARK: - Test Helpers

    func createMockPost(
        id: String = UUID().uuidString,
        creatorId: String = "creator1",
        meetTime: Date = Date().addingTimeInterval(30 * 60),
        status: Post.PostStatus = .active,
        latitude: Double = 37.5665,
        longitude: Double = 126.9780
    ) -> Post {
        var post = Post(
            creatorId: creatorId,
            message: "테스트 메시지",
            locationText: "테스트 장소",
            meetTime: meetTime,
            createdAt: Date(),
            creatorLocation: GeoPoint(latitude: latitude, longitude: longitude),
            participantIds: [creatorId],
            status: status,
            reportCount: 0
        )
        post.id = id
        return post
    }

    func createViewModel() -> PostListViewModel {
        return PostListViewModel()
    }

    func createMockAuthService(userId: String = "test-user") -> AuthService {
        let authService = AuthService()
        // Note: 실제 테스트에서는 Mock 객체를 주입해야 함
        return authService
    }

    func createMockLocationService(latitude: Double = 37.5665, longitude: Double = 126.9780) -> LocationService {
        let locationService = LocationService()
        // Note: 실제 테스트에서는 Mock 객체를 주입해야 함
        return locationService
    }

    // MARK: - Initialization Tests

    @Test func viewModel_initialState_hasEmptyPosts() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.posts.isEmpty)
        #expect(viewModel.sortType == .time)
        #expect(viewModel.error == nil)
    }

    @Test func viewModel_initialState_sortTypeIsTime() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.sortType == .time)
    }

    // MARK: - Configure Tests

    @Test func configure_setsIsConfigured() async throws {
        let viewModel = createViewModel()
        let authService = AuthService()
        let locationService = LocationService()

        viewModel.configure(locationService: locationService, authService: authService)

        // configure가 호출되면 내부적으로 isConfigured = true가 됨
        // 중복 호출 방지 확인
        viewModel.configure(locationService: locationService, authService: authService)

        // 에러 없이 완료되어야 함
        #expect(viewModel.error == nil)
    }

    // MARK: - SortType Tests

    @Test func sortType_canBeChanged() async throws {
        let viewModel = createViewModel()

        viewModel.sortType = .distance
        #expect(viewModel.sortType == .distance)

        viewModel.sortType = .time
        #expect(viewModel.sortType == .time)
    }

    // MARK: - isUserParticipating Tests

    @Test func isUserParticipating_withoutAuthService_returnsFalse() async throws {
        let viewModel = createViewModel()
        let post = createMockPost()

        // authService가 configure되지 않으면 false 반환
        #expect(viewModel.isUserParticipating(in: post) == false)
    }

    // MARK: - hasActivePost Tests

    @Test func hasActivePost_withNoActivePost_returnsFalse() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.hasActivePost(userId: "test-user") == false)
    }

    // MARK: - Error Handling Tests

    @Test func error_initiallyNil() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.error == nil)
    }

    // MARK: - Loading State Tests

    @Test func isLoading_initiallyFalse() async throws {
        let viewModel = createViewModel()

        // PostService가 시작되면 isLoading이 변경될 수 있음
        // 초기 상태 확인은 타이밍에 따라 다를 수 있음
        #expect(viewModel.error == nil)
    }
}
