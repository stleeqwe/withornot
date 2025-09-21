import Foundation

extension Date {
    // 시간 포맷팅
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    // 상대 시간 텍스트
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
    
    // 채팅 타이머용
    func chatTimerText(from startTime: Date) -> String {
        let endTime = startTime.addingTimeInterval(10 * 60)
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            return "채팅방이 종료되었습니다"
        }
        
        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        
        return "⏱ 채팅방이 \(minutes)분 \(seconds)초 후 사라집니다"
    }
}
