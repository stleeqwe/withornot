import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
class CreatePostViewModel: ObservableObject {
    @Published var message = ""
    @Published var locationText = ""
    @Published var meetTime = Date().addingTimeInterval(30 * 60) // 기본 30분 후
    @Published var isLoading = false
    @Published var error: String?
    @Published var isComplete = false
    @Published var showLocationPermissionAlert = false

    let category: Post.Category

    private let postService: PostService
    private var locationService: LocationService?
    private var authService: AuthService?
    private var notificationService: NotificationService?
    private var isConfigured = false

    // 카테고리별 빠른 선택 옵션
    var quickMessages: [String] {
        switch category {
        case .run:
            return ["출발만 같이해요", "런닝 초보끼리", "페이스 맞춰서 뛰실 분"]
        case .meal:
            return ["점심 같이해요", "저녁 한잔?", "간단히 커피 한잔"]
        }
    }

    var quickLocations: [String] {
        switch category {
        case .run:
            return ["어린이대공원", "한강공원", "올림픽공원"]
        case .meal:
            return ["회사 근처", "강남역", "홍대입구"]
        }
    }

    let quickTimes = [
        (minutes: 30, label: "30분 후"),
        (minutes: 60, label: "1시간 후"),
        (minutes: 120, label: "2시간 후"),
        (minutes: 180, label: "3시간 후")
    ]

    var minimumDate: Date {
        Date().addingTimeInterval(TimeConstants.chatOpenBeforeMeetTime)
    }

    var maximumDate: Date {
        // 오늘 자정 전까지만 가능
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let endOfToday = calendar.startOfDay(for: tomorrow).addingTimeInterval(-1)
        return endOfToday
    }

    init(category: Post.Category, postService: PostService = PostService()) {
        self.category = category
        self.postService = postService
    }

    /// EnvironmentObject에서 실제 서비스를 주입받아 설정
    func configure(
        locationService: LocationService,
        authService: AuthService,
        notificationService: NotificationService
    ) {
        guard !isConfigured else { return }

        self.locationService = locationService
        self.authService = authService
        self.notificationService = notificationService
        self.isConfigured = true
    }

    func createPost() {
        guard validateInput() else { return }
        guard let userId = authService?.currentUser?.id else {
            error = "사용자 정보를 찾을 수 없습니다"
            return
        }

        // 위치 권한 확인
        guard let locationService = locationService else {
            error = "위치 서비스를 사용할 수 없습니다"
            return
        }

        switch locationService.authorizationStatus {
        case .notDetermined:
            // 아직 권한 요청 안함 → 시스템 팝업 호출
            locationService.requestLocationPermission()
            return
        case .denied, .restricted:
            // 거부됨 → 설정 이동 안내
            showLocationPermissionAlert = true
            return
        case .authorizedWhenInUse, .authorizedAlways:
            // 권한 있음 → 위치 데이터 확인
            if locationService.currentLocation == nil {
                error = "현재 위치를 확인 중입니다. 잠시 후 다시 시도해주세요."
                return
            }
        @unknown default:
            break
        }

        // 이미 활성 게시글이 있는지 먼저 확인
        if postService.hasActivePost(userId: userId) {
            error = "이미 진행 중인 약속이 있습니다.\n기존 약속이 끝난 후 새로운 약속을 만들어주세요."
            return
        }

        // 위치 정보 캡처 (Task 진입 전)
        let currentLocation = locationService.currentLocation

        isLoading = true

        Task { [weak self] in
            guard let self = self else { return }

            do {
                let defaultMessage = category == .run ? "같이 달려요!" : "같이 먹어요!"
                try await postService.createPost(
                    category: category,
                    message: message.isEmpty ? defaultMessage : message,
                    locationText: locationText,
                    meetTime: meetTime,
                    userLocation: currentLocation,
                    userId: userId
                )

                // 알림 예약 - 약간의 딜레이 후 게시글 찾기
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초 대기

                if let post = postService.posts.first(where: { $0.creatorId == userId && !$0.isExpired }) {
                    notificationService?.scheduleChatNotification(for: post)
                }

                isLoading = false
                isComplete = true
            } catch {
                isLoading = false
                self.error = error.userFriendlyMessage
            }
        }
    }

    private func validateInput() -> Bool {
        // 문자열 길이 제한 검사
        if locationText.count > ValidationConstants.maxLocationLength {
            error = "장소명이 너무 깁니다 (최대 \(ValidationConstants.maxLocationLength)자)"
            return false
        }

        if message.count > ValidationConstants.maxPostMessageLength {
            error = "메시지가 너무 깁니다 (최대 \(ValidationConstants.maxPostMessageLength)자)"
            return false
        }

        if locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "만남 장소를 입력해주세요"
            return false
        }

        if meetTime < minimumDate {
            error = "최소 5분 이후 시간을 선택해주세요"
            return false
        }

        if meetTime > maximumDate {
            error = "오늘 약속만 생성 가능합니다"
            return false
        }

        return true
    }

    func setQuickTime(minutes: Int) {
        meetTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    func setQuickLocation(_ location: String) {
        locationText = location
    }

    func setQuickMessage(_ quickMessage: String) {
        message = quickMessage
    }

    /// 에러 상태 초기화
    func clearError() {
        error = nil
    }

    /// 설정 앱으로 이동
    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}
