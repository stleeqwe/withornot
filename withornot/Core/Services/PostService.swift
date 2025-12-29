import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

class PostService: ObservableObject, PostServiceProtocol {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var lastCleanupTime: Date?
    private let cleanupInterval = TimeConstants.cleanupMinimumInterval
    private var allPosts: [Post] = [] // 필터링 전 전체 게시글
    private var expirationTimer: Timer?
    
    // MARK: - Listening

    func startListening() {
        // 이미 리스닝 중이면 무시
        guard listener == nil else { return }

        isLoading = true
        print("🔥 Firebase: Starting to listen for posts...")

        // 만료 기준 시간 (현재 시간 - 5분)
        // 참고: 쿼리 시작 시점 기준으로 필터링됨. 이후 만료되는 게시글은 shouldIncludePost에서 로컬 필터링
        let expirationThreshold = Date().addingTimeInterval(-TimeConstants.postExpirationBuffer)

        listener = db.collection("posts")
            .whereField("meetTime", isGreaterThan: expirationThreshold)
            .order(by: "meetTime", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false

                if let error = error {
                    self?.handleListenerError(error)
                    return
                }

                guard let documents = snapshot?.documents else { return }
                print("✅ Firebase: Received \(documents.count) posts")

                // 전체 게시글 저장 후 필터링
                self?.allPosts = documents.compactMap { try? $0.data(as: Post.self) }
                self?.refreshFilteredPosts()
                self?.updatePostStatuses()
                self?.cleanupExpiredPosts()
            }

        // 다음 만료 시간에 맞춰 타이머 설정
        scheduleNextExpiration()
    }

    private func scheduleNextExpiration() {
        expirationTimer?.invalidate()
        expirationTimer = nil

        // 현재 표시 중인 게시글 중 가장 빠른 만료 시간 찾기
        let now = Date()
        let nextExpiration = posts.compactMap { post -> Date? in
            let expirationTime = post.meetTime.addingTimeInterval(TimeConstants.postExpirationBuffer)
            return expirationTime > now ? expirationTime : nil
        }.min()

        guard let nextTime = nextExpiration else { return }

        let interval = nextTime.timeIntervalSince(now) + 0.5 // 0.5초 여유
        guard interval > 0 else { return }

        print("⏰ Next post expiration in \(Int(interval))s")
        expirationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.refreshFilteredPosts()
        }
    }

    private func refreshFilteredPosts() {
        posts = allPosts.filter { shouldIncludePost($0) }
        scheduleNextExpiration()
    }

    private func handleListenerError(_ error: Error) {
        print("❌ Firebase Error: \(error.localizedDescription)")

        if isRetryableError(error) {
            print("🔄 Retrying connection in 3 seconds...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.startListening()
            }
        } else {
            self.error = error.userFriendlyMessage
        }
    }

    private func isRetryableError(_ error: Error) -> Bool {
        let description = error.localizedDescription
        return description.contains("offline") ||
               description.contains("network") ||
               description.contains("stored version")
    }

    private func shouldIncludePost(_ post: Post) -> Bool {
        let currentTime = Date()

        // 만료 시간 체크 (meetTime + 5분이 지났는지)
        let isNotExpired = !post.isExpired

        // 활성 상태 체크
        let isActiveStatus = post.status == .active || post.status == .chatOpen

        // 24시간 이내 게시글만 표시
        let isRecent = post.createdAt.timeIntervalSince(currentTime) > -TimeConstants.postValidityPeriod

        return isNotExpired && isActiveStatus && isRecent
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        expirationTimer?.invalidate()
        expirationTimer = nil
        print("🛑 Firebase: Stopped listening for posts")
    }
    
    // 사용자가 이미 활성 게시글을 가지고 있는지 확인
    func hasActivePost(userId: String) -> Bool {
        return posts.contains { post in
            post.creatorId == userId &&
            (post.status == .active || post.status == .chatOpen) &&
            !post.isExpired
        }
    }

    // 게시글 생성
    func createPost(category: Post.Category, message: String, locationText: String, meetTime: Date, userLocation: CLLocation?, userId: String) async throws {
        print("🔥 Firebase: Creating new post...")

        // 위치 정보 필수 확인
        guard let userLocation = userLocation else {
            print("❌ Post creation failed: Location required")
            throw PostError.locationRequired
        }

        // 이미 활성 게시글이 있는지 확인
        if hasActivePost(userId: userId) {
            print("❌ Post creation failed: User already has active post")
            throw PostError.alreadyHasActivePost
        }

        guard meetTime.timeIntervalSinceNow >= TimeConstants.chatOpenBeforeMeetTime else {
            print("❌ Post creation failed: Time too soon")
            throw PostError.tooSoon
        }

        let geoPoint = GeoPoint(
            latitude: userLocation.coordinate.latitude,
            longitude: userLocation.coordinate.longitude
        )

        let post = Post(
            creatorId: userId,
            category: category,
            message: message,
            locationText: locationText,
            meetTime: meetTime,
            createdAt: Date(),
            creatorLocation: geoPoint,
            participantIds: [userId],
            status: .active,
            reportCount: 0
        )

        let docRef = try db.collection("posts").addDocument(from: post)
        print("✅ Post created with ID: \(docRef.documentID)")
    }
    
    // 참가/취소
    func toggleParticipation(postId: String, userId: String) async throws {
        print("🔄 Toggling participation for post: \(postId), user: \(userId)")

        let postRef = db.collection("posts").document(postId)

        _ = try await db.executeTransaction { transaction in
            var post = try postRef.getDecodedDocument(in: transaction, as: Post.self)

            if post.participantIds.contains(userId) {
                post.participantIds.removeAll { $0 == userId }
                print("➖ Removed user from participants")
            } else {
                post.participantIds.append(userId)
                print("➕ Added user to participants")
            }

            try transaction.setData(from: post, forDocument: postRef)
            return ()
        }
    }
    
    // 게시글 삭제
    func deletePost(postId: String) async throws {
        print("🗑 Firebase: Deleting post \(postId)...")
        let postRef = db.collection("posts").document(postId)

        do {
            try await postRef.delete()
            print("✅ Post deleted successfully: \(postId)")
        } catch {
            print("❌ Failed to delete post: \(error.localizedDescription)")
            throw error
        }
    }

    // 신고
    func reportPost(postId: String) async throws {
        let postRef = db.collection("posts").document(postId)

        _ = try await db.executeTransaction { transaction in
            var post = try postRef.getDecodedDocument(in: transaction, as: Post.self)
            post.reportCount += 1

            if post.reportCount >= ReportThreshold.deleteAt {
                transaction.deleteDocument(postRef)
            } else {
                try transaction.setData(from: post, forDocument: postRef)
            }
            return ()
        }
    }
    
    // 상태 업데이트
    private func updatePostStatuses() {
        for post in posts {
            Task {
                await updatePostStatus(post)
            }
        }
    }

    private func updatePostStatus(_ post: Post) async {
        guard let postId = post.id else { return }

        // 채팅방이 열려야 하는 시간이면 상태 업데이트
        if post.shouldOpenChat && post.status != .chatOpen {
            do {
                try await db.collection("posts").document(postId).updateData([
                    "status": Post.PostStatus.chatOpen.rawValue
                ])
                print("✅ Post status updated to chatOpen: \(postId)")
            } catch {
                print("❌ Error updating post status: \(error)")
            }
        }
    }

    // 만료된 게시글 정리 (60초 간격 제한)
    private func cleanupExpiredPosts() {
        let currentTime = Date()

        // 마지막 정리 이후 60초가 지나지 않았으면 건너뜀
        if let lastCleanup = lastCleanupTime,
           currentTime.timeIntervalSince(lastCleanup) < cleanupInterval {
            print("⏭ Skipping cleanup - last cleanup was \(Int(currentTime.timeIntervalSince(lastCleanup)))s ago")
            return
        }

        lastCleanupTime = currentTime

        Task {
            do {
                let expiredThreshold = currentTime.addingTimeInterval(-TimeConstants.postExpirationBuffer)

                let snapshot = try await db.collection("posts")
                    .whereField("meetTime", isLessThan: expiredThreshold)
                    .getDocuments()

                print("🧹 Found \(snapshot.documents.count) expired posts to cleanup")

                for document in snapshot.documents {
                    do {
                        try await document.reference.delete()
                        print("✅ Deleted expired post: \(document.documentID)")
                    } catch {
                        print("❌ Error deleting expired post \(document.documentID): \(error)")
                    }
                }

                if snapshot.documents.count > 0 {
                    print("🧹 Cleanup completed: \(snapshot.documents.count) expired posts removed")
                }
            } catch {
                print("❌ Error during cleanup: \(error)")
            }
        }
    }
}

enum PostError: LocalizedError {
    case tooSoon
    case notFound
    case alreadyHasActivePost
    case locationRequired

    var errorDescription: String? {
        switch self {
        case .tooSoon:
            return "최소 5분 이후 시간을 선택해주세요"
        case .notFound:
            return "게시글을 찾을 수 없습니다"
        case .alreadyHasActivePost:
            return "이미 진행 중인 약속이 있습니다.\n기존 약속이 끝난 후 새로운 약속을 만들어주세요."
        case .locationRequired:
            return "위치 정보가 필요합니다. 위치 권한을 허용해주세요."
        }
    }
}
