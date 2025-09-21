import SwiftUI
import CoreLocation

struct PostCardView: View {
    let post: Post
    let isParticipating: Bool
    let currentLocation: CLLocation?
    let currentUserId: String?
    let onParticipationToggle: () -> Void
    let onDelete: () -> Void
    
    @State private var timeRemaining = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 (시간 + 삭제 버튼)
            HStack {
                Text(post.meetTime.timeString)
                    .font(.googleSans(size: 24, weight: .semibold))
                    .foregroundColor(.primaryText)

                Spacer()

                // 자신의 게시글인 경우에만 삭제 버튼 표시
                if post.creatorId == currentUserId {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.googleSans(size: 16))
                            .foregroundColor(.red)
                    }
                }
            }
            
            // 장소
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(Color(hex: "#9bff1b"))
                Text(post.locationText)
                    .foregroundColor(.primaryText)
            }
            .font(.googleSans(size: 15))
            
            // 메시지
            if !post.message.isEmpty {
                Text(post.message)
                    .font(.googleSans(size: 14))
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }
            
            // 메타 정보
            HStack {
                // 참가자 수
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.googleSans(size: 12))
                    Text("\(post.participantCount)명 참가")
                        .font(.googleSans(size: 14))
                }
                .foregroundColor(.secondaryText)
                
                Spacer()
                
                // 거리
                if let location = currentLocation {
                    Text(String(format: "%.1fkm", post.distance(from: location)))
                        .font(.googleSans(size: 13))
                        .foregroundColor(.secondaryText)
                }
            }
            
            // 상태 표시
            if post.shouldOpenChat {
                statusBadge(text: "💬 채팅방 열림", color: .green)
            } else if post.isExpired {
                statusBadge(text: "종료됨", color: .gray)
            } else {
                // 카운트다운
                Text(timeRemaining)
                    .font(.googleSans(size: 12))
                    .foregroundColor(.orange)
                    .onReceive(timer) { _ in
                        updateTimeRemaining()
                    }
                    .onAppear {
                        updateTimeRemaining()
                    }
                
                // 참가 버튼
                if post.timeUntilMeet > 5 * 60 {
                    Button(action: onParticipationToggle) {
                        Text(isParticipating ? "참가 취소" : "참가하기")
                            .font(.googleSans(size: 15, weight: .medium))
                            .foregroundColor(isParticipating ? .white : Color.mainBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isParticipating ? Color.mainBlue : Color.mainBlue.opacity(0.1)
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.mainBlue, lineWidth: isParticipating ? 0 : 1)
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }
    
    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.googleSans(size: 13, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .cornerRadius(12)
    }
    
    private func updateTimeRemaining() {
        let interval = post.meetTime.timeIntervalSinceNow
        
        if interval <= 0 {
            timeRemaining = "종료됨"
        } else if interval <= 5 * 60 {
            timeRemaining = "채팅방이 곧 열립니다"
        } else {
            let minutes = Int(interval / 60)
            let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
            
            if minutes < 60 {
                timeRemaining = "\(minutes)분 \(seconds)초 후"
            } else {
                let hours = minutes / 60
                timeRemaining = "\(hours)시간 \(minutes % 60)분 후"
            }
        }
    }
}
