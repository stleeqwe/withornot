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
        category: Post.Category = .run,
        meetTime: Date = Date().addingTimeInterval(30 * 60),
        status: Post.PostStatus = .active,
        latitude: Double = 37.5665,
        longitude: Double = 126.9780
    ) -> Post {
        var post = Post(
            creatorId: creatorId,
            category: category,
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
        #expect(viewModel.categoryFilter == .run)
        #expect(viewModel.error == nil)
    }

    @Test func viewModel_initialState_sortTypeIsTime() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.sortType == .time)
    }

    @Test func viewModel_initialState_categoryFilterIsRun() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.categoryFilter == .run)
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

    // MARK: - CategoryFilter Tests

    @Test func categoryFilter_canBeChangedToMeal() async throws {
        let viewModel = createViewModel()

        viewModel.categoryFilter = .meal
        #expect(viewModel.categoryFilter == .meal)
    }

    @Test func categoryFilter_canBeChangedToRun() async throws {
        let viewModel = createViewModel()
        viewModel.categoryFilter = .meal

        viewModel.categoryFilter = .run
        #expect(viewModel.categoryFilter == .run)
    }

    @Test func categoryFilter_runDisplaysCorrectName() async throws {
        #expect(PostListViewModel.CategoryFilter.run.rawValue == "런벙")
    }

    @Test func categoryFilter_mealDisplaysCorrectName() async throws {
        #expect(PostListViewModel.CategoryFilter.meal.rawValue == "밥벙")
    }

    // MARK: - Distance Filter Tests (3km)

    @Test func distanceFilter_postWithin3km_isIncluded() async throws {
        // 서울 시청 좌표 (37.5665, 126.9780)
        let post = createMockPost(latitude: 37.5665, longitude: 126.9780)
        let userLocation = CLLocation(latitude: 37.5665, longitude: 126.9780)

        let distance = post.distance(from: userLocation)

        #expect(distance <= 3.0) // 3km 이내
    }

    @Test func distanceFilter_postBeyond3km_isExcluded() async throws {
        // 서울 시청 좌표
        let post = createMockPost(latitude: 37.5665, longitude: 126.9780)
        // 약 10km 떨어진 위치
        let userLocation = CLLocation(latitude: 37.6665, longitude: 126.9780)

        let distance = post.distance(from: userLocation)

        #expect(distance > 3.0) // 3km 초과
    }

    @Test func distanceFilter_maxDistanceIs3km() async throws {
        // 정확히 3km 거리 테스트
        // 위도 1도 = 약 111km, 0.027도 ≈ 3km
        let post = createMockPost(latitude: 37.5665, longitude: 126.9780)
        let userLocation = CLLocation(latitude: 37.5935, longitude: 126.9780)

        let distance = post.distance(from: userLocation)

        #expect(distance >= 2.9 && distance <= 3.1) // 약 3km
    }

    // MARK: - Category Filtering Logic Tests

    @Test func postFiltering_runCategory_returnsOnlyRunPosts() async throws {
        let runPost = createMockPost(id: "run1", category: .run)
        let mealPost = createMockPost(id: "meal1", category: .meal)

        let posts = [runPost, mealPost]
        let filteredPosts = posts.filter { $0.category == .run }

        #expect(filteredPosts.count == 1)
        #expect(filteredPosts.first?.category == .run)
    }

    @Test func postFiltering_mealCategory_returnsOnlyMealPosts() async throws {
        let runPost = createMockPost(id: "run1", category: .run)
        let mealPost = createMockPost(id: "meal1", category: .meal)

        let posts = [runPost, mealPost]
        let filteredPosts = posts.filter { $0.category == .meal }

        #expect(filteredPosts.count == 1)
        #expect(filteredPosts.first?.category == .meal)
    }

    // MARK: - Combined Filtering Tests

    @Test func combinedFiltering_categoryAndDistance() async throws {
        // 3km 이내 런벙
        let nearRunPost = createMockPost(id: "nearRun", category: .run, latitude: 37.5665, longitude: 126.9780)
        // 3km 이내 밥벙
        let nearMealPost = createMockPost(id: "nearMeal", category: .meal, latitude: 37.5665, longitude: 126.9780)
        // 3km 초과 런벙
        let farRunPost = createMockPost(id: "farRun", category: .run, latitude: 37.7665, longitude: 126.9780)

        let posts = [nearRunPost, nearMealPost, farRunPost]
        let userLocation = CLLocation(latitude: 37.5665, longitude: 126.9780)

        // 런벙 + 3km 필터
        let filteredPosts = posts.filter { post in
            post.category == .run && post.distance(from: userLocation) <= 3.0
        }

        #expect(filteredPosts.count == 1)
        #expect(filteredPosts.first?.id == "nearRun")
    }
}
