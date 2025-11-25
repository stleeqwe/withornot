//
//  TimeConstants.swift
//  withornot
//
//  시간 관련 상수 정의
//

import Foundation

enum TimeConstants {
    /// 게시글 만료 버퍼 시간 (5분)
    static let postExpirationBuffer: TimeInterval = 5 * 60

    /// 게시글 유효 기간 (24시간)
    static let postValidityPeriod: TimeInterval = 24 * 60 * 60

    /// 클린업 최소 간격 (1분)
    static let cleanupMinimumInterval: TimeInterval = 60

    /// 네트워크 재시도 딜레이 (3초)
    static let networkRetryDelay: TimeInterval = 3

    /// 채팅방 열림 시간 (만남 시간 5분 전)
    static let chatOpenBeforeMeetTime: TimeInterval = 5 * 60

    /// 채팅방 종료 시간 (만남 시간 5분 후)
    static let chatCloseAfterMeetTime: TimeInterval = 5 * 60

    /// 알림 예약 시간 (만남 시간 5분 전)
    static let notificationBeforeMeetTime: TimeInterval = 5 * 60
}
