import Foundation
import CoreLocation
import Combine

class PostListViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var sortType: SortType = .time
    @Published var isLoading = false
    @Published var error: String?

    enum SortType {
        case time
        case distance
    }

    private let postService: PostService
    private var locationService: LocationService?
    private var authService: AuthService?
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false

    init(postService: PostService = PostService()) {
        self.postService = postService

        // 기본 바인딩 설정 (로딩, 에러 상태)
        postService.$isLoading
            .assign(to: &$isLoading)

        postService.$error
            .assign(to: &$error)

        postService.startListening()
    }

    /// EnvironmentObject에서 실제 서비스를 주입받아 설정
    func configure(locationService: LocationService, authService: AuthService) {
        guard !isConfigured else { return } // 중복 호출 방지

        self.locationService = locationService
        self.authService = authService
        self.isConfigured = true

        setupBindings()
    }

    private func setupBindings() {
        guard let locationService = locationService else { return }

        // PostService의 posts를 구독하고 정렬
        Publishers.CombineLatest3(
            postService.$posts,
            $sortType,
            locationService.$currentLocation
        )
        .map { [weak self] posts, sortType, location in
            self?.sortedPosts(posts, by: sortType, location: location) ?? posts
        }
        .assign(to: &$posts)
    }
    
    private func sortedPosts(_ posts: [Post], by sortType: SortType, location: CLLocation?) -> [Post] {
        switch sortType {
        case .time:
            return posts.sorted { $0.meetTime < $1.meetTime }
        case .distance:
            guard let location = location else { return posts }
            return posts.sorted { p1, p2 in
                p1.distance(from: location) < p2.distance(from: location)
            }
        }
    }
    
    func toggleParticipation(for post: Post) {
        guard let postId = post.id,
              let userId = authService?.currentUser?.id else { return }
        
        Task {
            do {
                try await postService.toggleParticipation(postId: postId, userId: userId)
            } catch {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                }
            }
        }
    }
    
    func deletePost(_ post: Post) {
        guard let postId = post.id else { return }

        Task {
            do {
                try await postService.deletePost(postId: postId)
            } catch {
                await MainActor.run {
                    self.error = error.userFriendlyMessage
                }
            }
        }
    }

    func reportPost(_ post: Post) {
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
    
    func isUserParticipating(in post: Post) -> Bool {
        guard let userId = authService?.currentUser?.id else { return false }
        return post.participantIds.contains(userId)
    }

    func hasActivePost(userId: String) -> Bool {
        return postService.hasActivePost(userId: userId)
    }
    
    deinit {
        postService.stopListening()
    }
}
