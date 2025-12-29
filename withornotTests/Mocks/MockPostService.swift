//
//  MockPostService.swift
//  withornotTests
//

import Foundation
import Combine
import CoreLocation
import FirebaseFirestore
@testable import withornot

class MockPostService: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: String?

    // 호출 추적
    var startListeningCalled = false
    var stopListeningCalled = false
    var createPostCalled = false
    var toggleParticipationCalled = false
    var deletePostCalled = false
    var reportPostCalled = false

    // 마지막 호출 파라미터
    var lastCreatedCategory: Post.Category?
    var lastCreatedMessage: String?
    var lastCreatedLocationText: String?
    var lastCreatedMeetTime: Date?
    var lastTogglePostId: String?
    var lastToggleUserId: String?
    var lastDeletedPostId: String?
    var lastReportedPostId: String?

    // 에러 시뮬레이션
    var shouldThrowError = false
    var errorToThrow: Error = PostError.notFound

    func startListening() {
        startListeningCalled = true
        isLoading = true
        // 시뮬레이션: 로딩 완료
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isLoading = false
        }
    }

    func stopListening() {
        stopListeningCalled = true
    }

    func hasActivePost(userId: String) -> Bool {
        return posts.contains { post in
            post.creatorId == userId &&
            (post.status == .active || post.status == .chatOpen) &&
            !post.isExpired
        }
    }

    func createPost(category: Post.Category, message: String, locationText: String, meetTime: Date, userLocation: CLLocation?, userId: String) async throws {
        createPostCalled = true
        lastCreatedCategory = category
        lastCreatedMessage = message
        lastCreatedLocationText = locationText
        lastCreatedMeetTime = meetTime

        if shouldThrowError {
            throw errorToThrow
        }

        // Mock 게시글 생성
        let geoPoint = GeoPoint(
            latitude: userLocation?.coordinate.latitude ?? 37.5665,
            longitude: userLocation?.coordinate.longitude ?? 126.9780
        )

        var newPost = Post(
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
        newPost.id = UUID().uuidString

        await MainActor.run {
            self.posts.append(newPost)
        }
    }

    func toggleParticipation(postId: String, userId: String) async throws {
        toggleParticipationCalled = true
        lastTogglePostId = postId
        lastToggleUserId = userId

        if shouldThrowError {
            throw errorToThrow
        }

        await MainActor.run {
            if let index = self.posts.firstIndex(where: { $0.id == postId }) {
                if self.posts[index].participantIds.contains(userId) {
                    self.posts[index].participantIds.removeAll { $0 == userId }
                } else {
                    self.posts[index].participantIds.append(userId)
                }
            }
        }
    }

    func deletePost(postId: String) async throws {
        deletePostCalled = true
        lastDeletedPostId = postId

        if shouldThrowError {
            throw errorToThrow
        }

        await MainActor.run {
            self.posts.removeAll { $0.id == postId }
        }
    }

    func reportPost(postId: String) async throws {
        reportPostCalled = true
        lastReportedPostId = postId

        if shouldThrowError {
            throw errorToThrow
        }

        await MainActor.run {
            if let index = self.posts.firstIndex(where: { $0.id == postId }) {
                self.posts[index].reportCount += 1
                if self.posts[index].reportCount >= 3 {
                    self.posts.remove(at: index)
                }
            }
        }
    }

    // 테스트 헬퍼 메서드
    func addMockPost(_ post: Post) {
        posts.append(post)
    }

    func reset() {
        posts.removeAll()
        isLoading = false
        error = nil
        startListeningCalled = false
        stopListeningCalled = false
        createPostCalled = false
        toggleParticipationCalled = false
        deletePostCalled = false
        reportPostCalled = false
        shouldThrowError = false
        lastCreatedCategory = nil
        lastCreatedMessage = nil
        lastCreatedLocationText = nil
        lastCreatedMeetTime = nil
    }
}
