//
//  MockAuthService.swift
//  withornotTests
//

import Foundation
import Combine
@testable import withornot

class MockAuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false

    var signInAnonymouslyCalled = false
    var updateFCMTokenCalled = false
    var lastUpdatedToken: String?

    init(currentUser: User? = nil, isAuthenticated: Bool = false) {
        self.currentUser = currentUser
        self.isAuthenticated = isAuthenticated
    }

    func signInAnonymously() {
        signInAnonymouslyCalled = true
        isAuthenticated = true
        if currentUser == nil {
            currentUser = User(id: "test-user-id", fcmToken: nil, createdAt: Date())
        }
    }

    func updateFCMToken(_ token: String) {
        updateFCMTokenCalled = true
        lastUpdatedToken = token
        if var user = currentUser {
            user.fcmToken = token
            currentUser = user
        }
    }

    // 테스트 헬퍼 메서드
    func setMockUser(_ user: User) {
        currentUser = user
        isAuthenticated = true
    }

    func reset() {
        currentUser = nil
        isAuthenticated = false
        signInAnonymouslyCalled = false
        updateFCMTokenCalled = false
        lastUpdatedToken = nil
    }
}
