import Foundation
import CoreLocation
import Combine
import FirebaseFunctions

@MainActor
class PostListViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var sortType: SortType = .time
    @Published var categoryFilter: CategoryFilter = .run
    @Published var isLoading = false
    @Published var error: String?

    enum SortType: String, CaseIterable {
        case time = "시간순"
        case distance = "거리순"
    }

    enum CategoryFilter: String, CaseIterable {
        case run = "런벙"
        case meal = "밥벙"
    }

    private let postService: PostService
    private var locationService: LocationService?
    private var authService: AuthService?
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    private lazy var functions = Functions.functions(region: FirebaseConstants.functionsRegion)

    init(postService: PostService = PostService()) {
        self.postService = postService

        // 기본 바인딩 설정 (로딩, 에러 상태)
        postService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        postService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        // startListening()은 인증 완료 후 configure()에서 호출
    }

    /// EnvironmentObject에서 실제 서비스를 주입받아 설정
    func configure(locationService: LocationService, authService: AuthService) {
        guard !isConfigured else { return }

        self.locationService = locationService
        self.authService = authService
        self.isConfigured = true

        setupBindings()

        // 인증 상태를 구독하여 인증 완료 후 리스닝 시작
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.postService.startListening()
                }
            }
            .store(in: &cancellables)
    }

    private func setupBindings() {
        guard let locationService = locationService else { return }

        // PostService의 posts를 구독하고 필터링 및 정렬
        Publishers.CombineLatest4(
            postService.$posts,
            $sortType,
            $categoryFilter,
            locationService.$currentLocation
        )
        .receive(on: DispatchQueue.main)
        .map { [weak self] posts, sortType, categoryFilter, location in
            let filtered = self?.filteredPosts(posts, by: categoryFilter, location: location) ?? posts
            return self?.sortedPosts(filtered, by: sortType, location: location) ?? filtered
        }
        .assign(to: &$posts)
    }

    private let maxDistanceKm: Double = 3.0

    private func filteredPosts(_ posts: [Post], by filter: CategoryFilter, location: CLLocation?) -> [Post] {
        var result = posts

        // 카테고리 필터
        switch filter {
        case .run:
            result = result.filter { $0.category == .run }
        case .meal:
            result = result.filter { $0.category == .meal }
        }

        // 거리 필터 (3km 이내)
        if let location = location {
            result = result.filter { $0.distance(from: location) <= maxDistanceKm }
        }

        return result
    }

    private func sortedPosts(_ posts: [Post], by sortType: SortType, location: CLLocation?) -> [Post] {
        switch sortType {
        case .time:
            return posts.sorted { $0.meetTime < $1.meetTime }
        case .distance:
            guard let location = location else {
                // 위치 정보 없으면 시간순으로 fallback
                return posts.sorted { $0.meetTime < $1.meetTime }
            }
            return posts.sorted { p1, p2 in
                p1.distance(from: location) < p2.distance(from: location)
            }
        }
    }

    func toggleParticipation(for post: Post) {
        guard let postId = post.id,
              let userId = authService?.currentUser?.id else { return }

        Task { [weak self] in
            do {
                try await self?.postService.toggleParticipation(postId: postId, userId: userId)
            } catch {
                self?.error = error.userFriendlyMessage
            }
        }
    }

    func deletePost(_ post: Post) {
        guard let postId = post.id else { return }

        Task { [weak self] in
            do {
                try await self?.postService.deletePost(postId: postId)
            } catch {
                self?.error = error.userFriendlyMessage
            }
        }
    }

    /// 게시글 신고 (Cloud Functions 호출)
    func reportPost(_ post: Post) {
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
                        print("🗑 Post deleted due to reports")
                    } else if resultData["alreadyReported"] as? Bool == true {
                        self?.error = "이미 신고한 게시글입니다"
                    } else {
                        print("✅ Post reported")
                    }
                }
            } catch {
                self?.error = error.userFriendlyMessage
            }
        }
    }

    func isUserParticipating(in post: Post) -> Bool {
        guard let userId = authService?.currentUser?.id else { return false }
        return post.participantIds.contains(userId)
    }

    func hasActivePost(userId: String) -> Bool {
        return postService.hasActivePost(userId: userId)
    }

    /// 에러 상태 초기화
    func clearError() {
        error = nil
    }

    deinit {
        postService.stopListening()
    }
}
