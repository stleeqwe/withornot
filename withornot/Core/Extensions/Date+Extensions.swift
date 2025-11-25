import Foundation

// MARK: - Static DateFormatters (Performance Optimization)

extension DateFormatter {
    /// 시간 포맷터 (HH:mm) - 재사용을 위해 static으로 선언
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// 날짜 포맷터 (yyyy-MM-dd)
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// 전체 날짜/시간 포맷터
    static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

// MARK: - Date Extensions

extension Date {
    /// 시간 포맷팅 (HH:mm)
    var timeString: String {
        DateFormatter.timeFormatter.string(from: self)
    }

    /// 상대 시간 텍스트
    var relativeTimeText: String {
        let interval = self.timeIntervalSinceNow

        if interval < 0 {
            return "종료됨"
        }

        let minutes = Int(interval / 60)
        let hours = minutes / 60

        if minutes < 60 {
            return "\(minutes)분 후"
        } else if hours < 24 {
            return "\(hours)시간 \(minutes % 60)분 후"
        } else {
            return "내일"
        }
    }

    /// 채팅 타이머용 (meetTime 기준으로 +5분까지 채팅 가능)
    func chatTimerText(from meetTime: Date) -> String {
        let endTime = meetTime.addingTimeInterval(TimeConstants.chatCloseAfterMeetTime)
        let remaining = endTime.timeIntervalSinceNow

        if remaining <= 0 {
            return "채팅방이 종료되었습니다"
        }

        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))

        return "⏱ 채팅방이 \(minutes)분 \(seconds)초 후 사라집니다"
    }
}
