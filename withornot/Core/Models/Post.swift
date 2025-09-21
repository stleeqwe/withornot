import Foundation
import FirebaseFirestore
import CoreLocation

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    let creatorId: String
    let message: String
    let locationText: String // 텍스트로만 저장
    let meetTime: Date
    let createdAt: Date
    let creatorLocation: GeoPoint // 작성자 위치
    var participantIds: [String]
    var status: PostStatus
    var reportCount: Int
    
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
    
    var shouldOpenChat: Bool {
        let fiveMinutes: TimeInterval = 5 * 60
        return timeUntilMeet <= fiveMinutes && timeUntilMeet >= -fiveMinutes
    }
    
    var isExpired: Bool {
        timeUntilMeet < -5 * 60
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
