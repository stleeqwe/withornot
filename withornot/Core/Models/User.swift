//
//  User.swift
//  withornot
//
//  Created by pukaworks on 9/13/25.
//

import Foundation

struct User: Identifiable, Codable {
    let id: String // 익명 UID
    var fcmToken: String?
    let createdAt: Date

    // 익명 사용자이므로 프로필 정보 없음
}
