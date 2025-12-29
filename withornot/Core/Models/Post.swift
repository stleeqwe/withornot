import Foundation
import FirebaseFirestore
import CoreLocation

struct Post: Identifiable, Codable, Equatable {
    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id &&
        lhs.participantIds == rhs.participantIds &&
        lhs.status == rhs.status
    }

    @DocumentID var id: String?
    let creatorId: String
    let category: Category
    let message: String
    let locationText: String // 텍스트로만 저장
    let meetTime: Date
    let createdAt: Date
    let creatorLocation: GeoPoint // 작성자 위치
    var participantIds: [String]
    var status: PostStatus
    var reportCount: Int

    enum Category: String, Codable, CaseIterable {
        case run = "run"
        case meal = "meal"

        var displayName: String {
            switch self {
            case .run: return "런벙"
            case .meal: return "밥벙"
            }
        }

        var icon: String {
            switch self {
            case .run: return "figure.run"
            case .meal: return "fork.knife"
            }
        }
    }

    enum PostStatus: String, Codable {
        case active = "active"
        case chatOpen = "chatOpen"
        case expired = "expired"
    }
    
    // 계산 프로퍼티
    var participantCount: Int {
        participantIds.count
    }
    
    var timeUntilMeet: TimeInterval {
        meetTime.timeIntervalSinceNow
    }

    /// 카테고리별 채팅방 열림 시간
    var chatOpenBeforeTime: TimeInterval {
        switch category {
        case .run: return TimeConstants.runChatOpenBeforeMeetTime
        case .meal: return TimeConstants.mealChatOpenBeforeMeetTime
        }
    }

    /// 카테고리별 채팅방 종료 시간
    var chatCloseAfterTime: TimeInterval {
        switch category {
        case .run: return TimeConstants.runChatCloseAfterMeetTime
        case .meal: return TimeConstants.mealChatCloseAfterMeetTime
        }
    }

    var shouldOpenChat: Bool {
        return timeUntilMeet <= chatOpenBeforeTime &&
               timeUntilMeet >= -chatCloseAfterTime
    }

    var isExpired: Bool {
        timeUntilMeet < -chatCloseAfterTime
    }

    /// 참가 토글이 가능한지 여부 (채팅방 열리기 전까지만 가능)
    var canToggleParticipation: Bool {
        timeUntilMeet > chatOpenBeforeTime
    }
    
    // 거리 계산
    func distance(from userLocation: CLLocation) -> Double {
        let postLocation = CLLocation(
            latitude: creatorLocation.latitude,
            longitude: creatorLocation.longitude
        )
        return userLocation.distance(from: postLocation) / 1000 // km 단위
    }
}
