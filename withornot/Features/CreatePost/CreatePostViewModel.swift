import Foundation
import CoreLocation
import Combine

class CreatePostViewModel: ObservableObject {
    @Published var message = ""
    @Published var locationText = ""
    @Published var meetTime = Date().addingTimeInterval(30 * 60) // 기본 30분 후
    @Published var isLoading = false
    @Published var error: String?
    @Published var isComplete = false

    private let postService: PostService
    private var locationService: LocationService?
    private var authService: AuthService?
    private var notificationService: NotificationService?
    private var isConfigured = false

    // 빠른 선택 옵션
    let quickMessages = [
        "출발만 같이해요",
        "런닝 초보끼리",
        "페이스 맞춰서 뛰실 분"
    ]

    let quickLocations = [
        "어린이대공원"
    ]

    let quickTimes = [
        (minutes: 30, label: "30분 후"),
        (minutes: 60, label: "1시간 후"),
        (minutes: 120, label: "2시간 후"),
        (minutes: 180, label: "3시간 후")
    ]

    var minimumDate: Date {
        Date().addingTimeInterval(5 * 60) // 최소 5분 후
    }

    var maximumDate: Date {
        // 오늘 자정 전까지만 가능
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let endOfToday = calendar.startOfDay(for: tomorrow).addingTimeInterval(-1)
        return endOfToday
    }

    init(postService: PostService = PostService()) {
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

        // 이미 활성 게시글이 있는지 먼저 확인
        if postService.hasActivePost(userId: userId) {
            error = "이미 진행 중인 약속이 있습니다.\n기존 약속이 끝난 후 새로운 약속을 만들어주세요."
            return
        }

        isLoading = true

        Task {
            do {
                try await postService.createPost(
                    message: message.isEmpty ? "같이 달려요!" : message,
                    locationText: locationText,
                    meetTime: meetTime,
                    userLocation: locationService?.currentLocation,
                    userId: userId
                )

                // 알림 예약
                if let post = postService.posts.first(where: { $0.creatorId == userId }) {
                    notificationService?.scheduleChatNotification(for: post)
                }

                await MainActor.run {
                    isLoading = false
                    isComplete = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    self.error = error.userFriendlyMessage
                }
            }
        }
    }
    
    private func validateInput() -> Bool {
        if locationText.isEmpty {
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
}
