import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    let userId: String
    let text: String
    let timestamp: Date
    var reportCount: Int = 0
    
    // 익명 ID 표시용
    var displayUserId: String {
        String(userId.prefix(4))
    }
}

