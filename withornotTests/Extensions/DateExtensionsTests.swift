//
//  DateExtensionsTests.swift
//  withornotTests
//

import Testing
import Foundation
@testable import withornot

struct DateExtensionsTests {

    // MARK: - timeString Tests

    @Test func timeString_formatsHoursAndMinutes() async throws {
        // 특정 시간 생성 (14:30)
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 30

        let calendar = Calendar.current
        let date = calendar.date(from: components)!

        #expect(date.timeString == "14:30")
    }

    @Test func timeString_formatsMidnight() async throws {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 0
        components.minute = 0

        let calendar = Calendar.current
        let date = calendar.date(from: components)!

        #expect(date.timeString == "00:00")
    }

    @Test func timeString_formatsSingleDigitMinutes() async throws {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 9
        components.minute = 5

        let calendar = Calendar.current
        let date = calendar.date(from: components)!

        #expect(date.timeString == "09:05")
    }

    // MARK: - relativeTimeText Tests

    @Test func relativeTimeText_pastDate_returnsExpired() async throws {
        let pastDate = Date().addingTimeInterval(-60) // 1분 전

        #expect(pastDate.relativeTimeText == "종료됨")
    }

    @Test func relativeTimeText_lessThan60Minutes_returnsMinutes() async throws {
        let futureDate = Date().addingTimeInterval(30 * 60) // 30분 후

        let text = futureDate.relativeTimeText

        // "29분 후" 또는 "30분 후" (타이밍에 따라)
        #expect(text.contains("분 후"))
        #expect(!text.contains("시간"))
    }

    @Test func relativeTimeText_lessThan24Hours_returnsHoursAndMinutes() async throws {
        let futureDate = Date().addingTimeInterval(2 * 60 * 60 + 30 * 60) // 2시간 30분 후

        let text = futureDate.relativeTimeText

        #expect(text.contains("시간"))
        #expect(text.contains("분 후"))
    }

    @Test func relativeTimeText_moreThan24Hours_returnsTomorrow() async throws {
        let futureDate = Date().addingTimeInterval(25 * 60 * 60) // 25시간 후

        #expect(futureDate.relativeTimeText == "내일")
    }

    @Test func relativeTimeText_exactly60Minutes_returnsHours() async throws {
        let futureDate = Date().addingTimeInterval(60 * 60) // 정확히 1시간 후

        let text = futureDate.relativeTimeText

        #expect(text.contains("시간"))
    }

    // MARK: - chatTimerText Tests

    @Test func chatTimerText_expiredChat_returnsClosedMessage() async throws {
        let meetTime = Date().addingTimeInterval(-10 * 60) // 10분 전 meetTime
        let currentDate = Date()

        let text = currentDate.chatTimerText(from: meetTime)

        #expect(text == "채팅방이 종료되었습니다")
    }

    @Test func chatTimerText_activeChat_returnsRemainingTime() async throws {
        let meetTime = Date().addingTimeInterval(3 * 60) // 3분 후 meetTime (채팅방 열림)
        let currentDate = Date()

        let text = currentDate.chatTimerText(from: meetTime)

        // meetTime + 5분 = 8분 후 종료
        #expect(text.contains("⏱"))
        #expect(text.contains("채팅방이"))
        #expect(text.contains("후 사라집니다"))
    }

    @Test func chatTimerText_justBeforeExpiry_returnsSmallTime() async throws {
        // meetTime이 4분 50초 전이면, 채팅방 종료까지 약 10초 남음
        let meetTime = Date().addingTimeInterval(-4 * 60 - 50) // 4분 50초 전
        let currentDate = Date()

        let text = currentDate.chatTimerText(from: meetTime)

        // 약 10초 남음
        #expect(text.contains("0분") || text.contains("채팅방이 종료되었습니다"))
    }

    @Test func chatTimerText_atExactEndTime_returnsClosedMessage() async throws {
        // meetTime + 5분 = 정확히 종료 시점
        let meetTime = Date().addingTimeInterval(-5 * 60) // 정확히 5분 전
        let currentDate = Date()

        let text = currentDate.chatTimerText(from: meetTime)

        #expect(text == "채팅방이 종료되었습니다")
    }
}
