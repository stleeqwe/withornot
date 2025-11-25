//
//  ErrorExtensionsTests.swift
//  withornotTests
//

import Testing
import Foundation
@testable import withornot

struct ErrorExtensionsTests {

    // MARK: - Test Error Types

    enum TestError: Error, LocalizedError {
        case simpleError
        case technicalError

        var errorDescription: String? {
            switch self {
            case .simpleError:
                return "간단한 에러입니다"
            case .technicalError:
                return "Error Domain=TestDomain Code=123 UserInfo={}"
            }
        }
    }

    // MARK: - PostError Tests

    @Test func userFriendlyMessage_postError_notFound() async throws {
        let error: Error = PostError.notFound

        let message = error.userFriendlyMessage

        #expect(message.contains("게시글"))
    }

    @Test func userFriendlyMessage_postError_tooSoon() async throws {
        let error: Error = PostError.tooSoon

        let message = error.userFriendlyMessage

        #expect(message.contains("5분") || message.contains("시간"))
    }

    @Test func userFriendlyMessage_postError_alreadyHasActivePost() async throws {
        let error: Error = PostError.alreadyHasActivePost

        let message = error.userFriendlyMessage

        #expect(message.contains("이미") || message.contains("약속"))
    }

    // MARK: - ChatError Tests

    @Test func userFriendlyMessage_chatError_messageNotFound() async throws {
        let error: Error = ChatError.messageNotFound

        let message = error.userFriendlyMessage

        #expect(message.contains("메시지") || message.contains("찾"))
    }

    // MARK: - NSError Tests (URL Errors)

    @Test func userFriendlyMessage_notConnectedToInternet() async throws {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("인터넷"))
    }

    @Test func userFriendlyMessage_timedOut() async throws {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("시간") || message.contains("초과"))
    }

    @Test func userFriendlyMessage_networkConnectionLost() async throws {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("네트워크") || message.contains("끊어"))
    }

    @Test func userFriendlyMessage_otherURLError() async throws {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotFindHost,
            userInfo: nil
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("네트워크") || message.contains("오류"))
    }

    // MARK: - Firestore Error Tests

    @Test func userFriendlyMessage_firestoreVersionConflict() async throws {
        let error = NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "The stored version does not match"]
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("네트워크") || message.contains("불안정"))
    }

    @Test func userFriendlyMessage_firestoreOffline() async throws {
        let error = NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Client is offline"]
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("네트워크") || message.contains("연결"))
    }

    @Test func userFriendlyMessage_firestorePermissionDenied() async throws {
        let error = NSError(
            domain: "FIRFirestoreErrorDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "permission denied"]
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("권한"))
    }

    // MARK: - Technical Message Detection Tests

    @Test func userFriendlyMessage_technicalErrorDomain_convertsFriendly() async throws {
        let error = TestError.technicalError

        let message = error.userFriendlyMessage

        #expect(message.contains("일시적인 오류") || message.contains("다시 시도"))
    }

    @Test func userFriendlyMessage_simpleError_passesThrough() async throws {
        let error = TestError.simpleError

        let message = error.userFriendlyMessage

        #expect(message == "간단한 에러입니다")
    }

    // MARK: - Edge Cases

    @Test func userFriendlyMessage_nullInMessage() async throws {
        let error = NSError(
            domain: "TestDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Value is null"]
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("일시적인 오류") || message.contains("다시 시도"))
    }

    @Test func userFriendlyMessage_nilInMessage() async throws {
        let error = NSError(
            domain: "TestDomain",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Found nil value"]
        )

        let message = error.userFriendlyMessage

        #expect(message.contains("일시적인 오류") || message.contains("다시 시도"))
    }
}
