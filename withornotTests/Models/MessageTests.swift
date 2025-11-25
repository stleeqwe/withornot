//
//  MessageTests.swift
//  withornotTests
//

import Testing
import Foundation
@testable import withornot

struct MessageTests {

    // MARK: - Test Helpers

    func createMockMessage(
        userId: String = "testUser123456789",
        text: String = "테스트 메시지",
        reportCount: Int = 0
    ) -> Message {
        return Message(
            userId: userId,
            text: text,
            timestamp: Date(),
            reportCount: reportCount
        )
    }

    // MARK: - displayUserId Tests

    @Test func displayUserId_returnsFirst4Characters() async throws {
        let message = createMockMessage(userId: "abcdefghijklmn")

        #expect(message.displayUserId == "abcd")
    }

    @Test func displayUserId_withShortId_returnsEntireId() async throws {
        let message = createMockMessage(userId: "ab")

        #expect(message.displayUserId == "ab")
    }

    @Test func displayUserId_withExactly4Characters_returnsAllCharacters() async throws {
        let message = createMockMessage(userId: "test")

        #expect(message.displayUserId == "test")
    }

    @Test func displayUserId_withEmptyId_returnsEmptyString() async throws {
        let message = createMockMessage(userId: "")

        #expect(message.displayUserId == "")
    }

    // MARK: - Basic Properties Tests

    @Test func message_hasCorrectText() async throws {
        let message = createMockMessage(text: "안녕하세요")

        #expect(message.text == "안녕하세요")
    }

    @Test func message_hasCorrectUserId() async throws {
        let message = createMockMessage(userId: "user123")

        #expect(message.userId == "user123")
    }

    @Test func message_hasDefaultReportCount() async throws {
        let message = createMockMessage()

        #expect(message.reportCount == 0)
    }

    @Test func message_hasCorrectReportCount() async throws {
        let message = createMockMessage(reportCount: 2)

        #expect(message.reportCount == 2)
    }

    // MARK: - Identifiable Tests

    @Test func message_idIsInitiallyNil() async throws {
        let message = createMockMessage()

        #expect(message.id == nil)
    }

    @Test func message_idCanBeSet() async throws {
        var message = createMockMessage()
        message.id = "message-123"

        #expect(message.id == "message-123")
    }

    // MARK: - Timestamp Tests

    @Test func message_timestampIsSet() async throws {
        let beforeCreate = Date()
        let message = createMockMessage()
        let afterCreate = Date()

        #expect(message.timestamp >= beforeCreate)
        #expect(message.timestamp <= afterCreate)
    }
}
