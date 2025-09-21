import Foundation
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

class PostService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // 게시글 목록 실시간 리스닝
    func startListening() {
        isLoading = true
        print("🔥 Firebase: Starting to listen for posts...")

        listener = db.collection("posts")
            .order(by: "meetTime", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                self?.isLoading = false

                if let error = error {
                    print("❌ Firebase Error: \(error.localizedDescription)")
                    // 네트워크 오류인 경우 재시도
                    if error.localizedDescription.contains("offline") ||
                       error.localizedDescription.contains("network") {
                        print("🔄 Retrying connection in 3 seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self?.startListening()
                        }
                    }
                    self?.error = error.localizedDescription
                    return
                }

                print("✅ Firebase: Received \(snapshot?.documents.count ?? 0) posts")
                guard let documents = snapshot?.documents else { return }
                
                self?.posts = documents.compactMap { doc in
                    do {
                        let post = try doc.data(as: Post.self)
                        print("📝 Post loaded: \(post.id ?? "unknown") - \(post.message)")
                        return post
                    } catch {
                        print("⚠️ Failed to decode post: \(error)")
                        return nil
                    }
                }.filter { post in
                    // 활성 상태 체크
                    let isActiveStatus = post.status == .active || post.status == .chatOpen
                    // 24시간 이내 게시글만 표시
                    let isRecent = post.createdAt.timeIntervalSinceNow > -86400

                    if !isActiveStatus {
                        print("🚫 Filtering out inactive post: \(post.id ?? "unknown") - status: \(post.status)")
                    }
                    if !isRecent {
                        print("🗑 Filtering out old post: \(post.id ?? "unknown")")
                    }

                    return isActiveStatus && isRecent
                }
                
                // 상태 업데이트 체크
                self?.updatePostStatuses()
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
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
    func createPost(message: String, locationText: String, meetTime: Date, userLocation: CLLocation?, userId: String) async throws {
        print("🔥 Firebase: Creating new post...")

        // 이미 활성 게시글이 있는지 확인
        if hasActivePost(userId: userId) {
            print("❌ Post creation failed: User already has active post")
            throw PostError.alreadyHasActivePost
        }

        guard meetTime.timeIntervalSinceNow >= 5 * 60 else {
            print("❌ Post creation failed: Time too soon")
            throw PostError.tooSoon
        }
        
        let geoPoint = GeoPoint(
            latitude: userLocation?.coordinate.latitude ?? 37.5665,
            longitude: userLocation?.coordinate.longitude ?? 126.9780
        )
        
        let post = Post(
            creatorId: userId,
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
        print("🔄 Attempting to toggle participation...")
        print("   PostID: \(postId)")
        print("   UserID: \(userId)")
        print("   Is authenticated: \(Auth.auth().currentUser != nil)")
        print("   Auth UID: \(Auth.auth().currentUser?.uid ?? "nil")")

        let postRef = db.collection("posts").document(postId)

        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let postDoc = try transaction.getDocument(postRef)
                guard var post = try? postDoc.data(as: Post.self) else {
                    print("❌ Post not found or failed to decode")
                    throw PostError.notFound
                }

                print("📝 Current participants: \(post.participantIds)")

                if post.participantIds.contains(userId) {
                    post.participantIds.removeAll { $0 == userId }
                    print("➖ Removing user from participants")
                } else {
                    post.participantIds.append(userId)
                    print("➕ Adding user to participants")
                }

                print("📝 Updated participants: \(post.participantIds)")

                try transaction.setData(from: post, forDocument: postRef)
                print("✅ Transaction completed successfully")
                return nil
            } catch {
                print("❌ Transaction error: \(error)")
                if let errorPointer = errorPointer {
                    errorPointer.pointee = error as NSError
                }
                return nil
            }
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

        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            do {
                let postDoc = try transaction.getDocument(postRef)
                guard var post = try? postDoc.data(as: Post.self) else {
                    throw PostError.notFound
                }

                post.reportCount += 1

                // 3회 이상 신고 시 삭제
                if post.reportCount >= 3 {
                    transaction.deleteDocument(postRef)
                } else {
                    try transaction.setData(from: post, forDocument: postRef)
                }

                return nil
            } catch {
                if let errorPointer = errorPointer {
                    errorPointer.pointee = error as NSError
                }
                return nil
            }
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
        
        var newStatus: Post.PostStatus = .active
        
        if post.isExpired {
            newStatus = .expired
        } else if post.shouldOpenChat {
            newStatus = .chatOpen
        }
        
        if newStatus != post.status {
            do {
                try await db.collection("posts").document(postId).updateData([
                    "status": newStatus.rawValue
                ])
            } catch {
                print("Error updating post status: \(error)")
            }
        }
    }
}

enum PostError: LocalizedError {
    case tooSoon
    case notFound
    case alreadyHasActivePost

    var errorDescription: String? {
        switch self {
        case .tooSoon:
            return "최소 5분 이후 시간을 선택해주세요"
        case .notFound:
            return "게시글을 찾을 수 없습니다"
        case .alreadyHasActivePost:
            return "이미 진행 중인 약속이 있습니다.\n기존 약속이 끝난 후 새로운 약속을 만들어주세요."
        }
    }
}
