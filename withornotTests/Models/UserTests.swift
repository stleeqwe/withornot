//
//  UserTests.swift
//  withornotTests
//

import Testing
import Foundation
@testable import withornot

struct UserTests {

    // MARK: - Test Helpers

    func createMockUser(
        id: String = "user-test-id",
        fcmToken: String? = nil,
        createdAt: Date = Date()
    ) -> User {
        return User(
            id: id,
            fcmToken: fcmToken,
            createdAt: createdAt
        )
    }

    // MARK: - Basic Properties Tests

    @Test func user_hasCorrectId() async throws {
        let user = createMockUser(id: "unique-id-123")

        #expect(user.id == "unique-id-123")
    }

    @Test func user_fcmTokenIsNilByDefault() async throws {
        let user = createMockUser()

        #expect(user.fcmToken == nil)
    }

    @Test func user_fcmTokenCanBeSet() async throws {
        let user = createMockUser(fcmToken: "fcm-token-12345")

        #expect(user.fcmToken == "fcm-token-12345")
    }

    @Test func user_hasCreatedAt() async throws {
        let specificDate = Date(timeIntervalSince1970: 1700000000)
        let user = createMockUser(createdAt: specificDate)

        #expect(user.createdAt == specificDate)
    }

    // MARK: - Identifiable Tests

    @Test func user_identifiableUsesIdProperty() async throws {
        let user = createMockUser(id: "identifiable-test")

        #expect(user.id == "identifiable-test")
    }

    // MARK: - Mutability Tests

    @Test func user_fcmTokenCanBeModified() async throws {
        var user = createMockUser(fcmToken: nil)
        #expect(user.fcmToken == nil)

        user.fcmToken = "new-fcm-token"
        #expect(user.fcmToken == "new-fcm-token")
    }

    // MARK: - Codable Tests

    @Test func user_canBeEncodedAndDecoded() async throws {
        let originalUser = createMockUser(
            id: "encode-decode-test",
            fcmToken: "test-token",
            createdAt: Date(timeIntervalSince1970: 1700000000)
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalUser)

        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: data)

        #expect(decodedUser.id == originalUser.id)
        #expect(decodedUser.fcmToken == originalUser.fcmToken)
        #expect(decodedUser.createdAt == originalUser.createdAt)
    }

    @Test func user_canBeEncodedWithNilFcmToken() async throws {
        let user = createMockUser(fcmToken: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(user)

        let decoder = JSONDecoder()
        let decodedUser = try decoder.decode(User.self, from: data)

        #expect(decodedUser.fcmToken == nil)
    }
}
