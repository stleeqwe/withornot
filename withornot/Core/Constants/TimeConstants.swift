//
//  TimeConstants.swift
//  withornot
//
//  앱 전역 상수 정의
//

import Foundation

// MARK: - Time Constants

enum TimeConstants {
    /// 게시글 만료 버퍼 시간 (5분)
    static let postExpirationBuffer: TimeInterval = 5 * 60

    /// 게시글 유효 기간 (24시간)
    static let postValidityPeriod: TimeInterval = 24 * 60 * 60

    /// 클린업 최소 간격 (1분)
    static let cleanupMinimumInterval: TimeInterval = 60

    /// 네트워크 재시도 딜레이 (3초)
    static let networkRetryDelay: TimeInterval = 3

    // MARK: - 런벙 채팅방 시간 (전후 5분, 총 10분)

    /// 런벙 채팅방 열림 시간 (만남 시간 5분 전)
    static let runChatOpenBeforeMeetTime: TimeInterval = 5 * 60

    /// 런벙 채팅방 종료 시간 (만남 시간 5분 후)
    static let runChatCloseAfterMeetTime: TimeInterval = 5 * 60

    // MARK: - 밥벙 채팅방 시간 (전후 10분, 총 20분)

    /// 밥벙 채팅방 열림 시간 (만남 시간 10분 전)
    static let mealChatOpenBeforeMeetTime: TimeInterval = 10 * 60

    /// 밥벙 채팅방 종료 시간 (만남 시간 10분 후)
    static let mealChatCloseAfterMeetTime: TimeInterval = 10 * 60

    // MARK: - 기본값 (런벙 기준, 하위 호환성)

    /// 채팅방 열림 시간 (만남 시간 5분 전) - 기본값
    static let chatOpenBeforeMeetTime: TimeInterval = 5 * 60

    /// 채팅방 종료 시간 (만남 시간 5분 후) - 기본값
    static let chatCloseAfterMeetTime: TimeInterval = 5 * 60

    /// 알림 예약 시간 (만남 시간 5분 전)
    static let notificationBeforeMeetTime: TimeInterval = 5 * 60
}

// MARK: - Firebase Constants

enum FirebaseConstants {
    /// Cloud Functions 지역
    static let functionsRegion = "asia-northeast3"
}

// MARK: - Validation Constants

enum ValidationConstants {
    /// 메시지 최대 길이
    static let maxMessageLength = 1000

    /// 장소명 최대 길이
    static let maxLocationLength = 100

    /// 게시글 메시지 최대 길이
    static let maxPostMessageLength = 500

    /// 신고 삭제 임계값
    static let reportThreshold = 3
}
