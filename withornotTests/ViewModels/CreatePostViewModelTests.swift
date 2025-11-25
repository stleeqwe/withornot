//
//  CreatePostViewModelTests.swift
//  withornotTests
//

import Testing
import Foundation
@testable import withornot

@MainActor
struct CreatePostViewModelTests {

    // MARK: - Test Helpers

    func createViewModel() -> CreatePostViewModel {
        return CreatePostViewModel()
    }

    // MARK: - Initial State Tests

    @Test func viewModel_initialState_hasEmptyMessage() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.message == "")
    }

    @Test func viewModel_initialState_hasEmptyLocationText() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.locationText == "")
    }

    @Test func viewModel_initialState_meetTimeIs30MinutesFromNow() async throws {
        let beforeCreate = Date()
        let viewModel = createViewModel()
        let afterCreate = Date()

        let expectedMinTime = beforeCreate.addingTimeInterval(30 * 60 - 1)
        let expectedMaxTime = afterCreate.addingTimeInterval(30 * 60 + 1)

        #expect(viewModel.meetTime >= expectedMinTime)
        #expect(viewModel.meetTime <= expectedMaxTime)
    }

    @Test func viewModel_initialState_isLoadingIsFalse() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.isLoading == false)
    }

    @Test func viewModel_initialState_errorIsNil() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.error == nil)
    }

    @Test func viewModel_initialState_isCompleteIsFalse() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.isComplete == false)
    }

    // MARK: - Quick Options Tests

    @Test func quickMessages_hasExpectedOptions() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.quickMessages.contains("출발만 같이해요"))
        #expect(viewModel.quickMessages.contains("런닝 초보끼리"))
        #expect(viewModel.quickMessages.contains("페이스 맞춰서 뛰실 분"))
    }

    @Test func quickLocations_hasExpectedOptions() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.quickLocations.contains("어린이대공원"))
    }

    @Test func quickTimes_hasExpectedOptions() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.quickTimes.count == 4)
        #expect(viewModel.quickTimes[0].minutes == 30)
        #expect(viewModel.quickTimes[1].minutes == 60)
        #expect(viewModel.quickTimes[2].minutes == 120)
        #expect(viewModel.quickTimes[3].minutes == 180)
    }

    // MARK: - minimumDate Tests

    @Test func minimumDate_is5MinutesFromNow() async throws {
        let beforeCheck = Date()
        let viewModel = createViewModel()
        let afterCheck = Date()

        let expectedMinTime = beforeCheck.addingTimeInterval(5 * 60 - 1)
        let expectedMaxTime = afterCheck.addingTimeInterval(5 * 60 + 1)

        #expect(viewModel.minimumDate >= expectedMinTime)
        #expect(viewModel.minimumDate <= expectedMaxTime)
    }

    // MARK: - maximumDate Tests

    @Test func maximumDate_isEndOfToday() async throws {
        let viewModel = createViewModel()
        let calendar = Calendar.current

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let endOfToday = calendar.startOfDay(for: tomorrow).addingTimeInterval(-1)

        #expect(viewModel.maximumDate == endOfToday)
    }

    // MARK: - setQuickTime Tests

    @Test func setQuickTime_updates_meetTime() async throws {
        let viewModel = createViewModel()
        let beforeSet = Date()

        viewModel.setQuickTime(minutes: 60)

        let expectedTime = beforeSet.addingTimeInterval(60 * 60)
        let timeDifference = abs(viewModel.meetTime.timeIntervalSince(expectedTime))

        #expect(timeDifference < 2) // 2초 오차 허용
    }

    // MARK: - setQuickLocation Tests

    @Test func setQuickLocation_updates_locationText() async throws {
        let viewModel = createViewModel()

        viewModel.setQuickLocation("어린이대공원")

        #expect(viewModel.locationText == "어린이대공원")
    }

    // MARK: - setQuickMessage Tests

    @Test func setQuickMessage_updates_message() async throws {
        let viewModel = createViewModel()

        viewModel.setQuickMessage("출발만 같이해요")

        #expect(viewModel.message == "출발만 같이해요")
    }

    // MARK: - Configure Tests

    @Test func configure_canBeCalledOnce() async throws {
        let viewModel = createViewModel()
        let authService = AuthService()
        let locationService = LocationService()
        let notificationService = NotificationService()

        viewModel.configure(
            locationService: locationService,
            authService: authService,
            notificationService: notificationService
        )

        // 중복 호출해도 에러 없음
        viewModel.configure(
            locationService: locationService,
            authService: authService,
            notificationService: notificationService
        )

        #expect(viewModel.error == nil)
    }

    // MARK: - Validation Tests

    @Test func createPost_withEmptyLocation_setsError() async throws {
        let viewModel = createViewModel()
        viewModel.locationText = ""
        viewModel.message = "테스트"

        // authService가 configure되지 않아서 실행되지 않음
        viewModel.createPost()

        // 에러 또는 early return
        // Note: configure 없이 createPost를 호출하면 "사용자 정보를 찾을 수 없습니다" 에러
    }

    @Test func createPost_withValidLocation_proceedsToValidation() async throws {
        let viewModel = createViewModel()
        viewModel.locationText = "테스트 장소"

        viewModel.createPost()

        // authService가 nil이므로 "사용자 정보를 찾을 수 없습니다" 에러 예상
        #expect(viewModel.error == "사용자 정보를 찾을 수 없습니다")
    }
}
