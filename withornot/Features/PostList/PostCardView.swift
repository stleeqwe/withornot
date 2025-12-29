import SwiftUI
import CoreLocation
import Combine

struct PostCardView: View {
    let post: Post
    let isParticipating: Bool
    let currentLocation: CLLocation?
    let currentUserId: String?
    let isLocationAvailable: Bool
    let onParticipationToggle: () -> Void
    let onDelete: () -> Void

    @State private var timeRemaining = ""
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 (카테고리 아이콘 + 시간 + 삭제 버튼)
            HStack {
                // 카테고리 아이콘
                Image(systemName: post.category.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(post.category == .run ? .orange : .purple)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(post.category == .run ? Color.orange.opacity(0.15) : Color.purple.opacity(0.15))
                    )

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
                    .accessibilityLabel("약속 삭제")
                    .accessibilityHint("이 약속을 삭제합니다")
                }
            }

            // 장소
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.locationGreen)
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
                statusBadge(text: "채팅방 열림", color: .green)
                    .accessibilityLabel("채팅방이 열려있습니다")
            } else if post.isExpired {
                statusBadge(text: "종료됨", color: .gray)
                    .accessibilityLabel("이 약속은 종료되었습니다")
            } else {
                // 카운트다운
                Text(timeRemaining)
                    .font(.googleSans(size: 12))
                    .foregroundColor(.orange)
                    .accessibilityLabel("남은 시간: \(timeRemaining)")

                // 참가 버튼 (5분 전까지만 표시, 위치 권한 필요)
                if post.canToggleParticipation {
                    Button(action: onParticipationToggle) {
                        Text(isLocationAvailable ? (isParticipating ? "참가 취소" : "참가하기") : "위치 권한 필요")
                            .font(.googleSans(size: 15, weight: .medium))
                            .foregroundColor(isLocationAvailable ? (isParticipating ? .white : Color.mainBlue) : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isLocationAvailable ? (isParticipating ? Color.mainBlue : Color.mainBlue.opacity(0.1)) : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isLocationAvailable ? Color.mainBlue : Color.gray, lineWidth: isParticipating ? 0 : 1)
                            )
                    }
                    .disabled(!isLocationAvailable)
                    .accessibilityLabel(isLocationAvailable ? (isParticipating ? "참가 취소하기" : "약속에 참가하기") : "위치 권한이 필요합니다")
                    .accessibilityHint(isLocationAvailable ? (isParticipating ? "탭하여 참가를 취소합니다" : "탭하여 이 약속에 참가합니다") : "위치 권한을 허용해주세요")
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(14)
        .onAppear {
            startTimer()
            updateTimeRemaining()
        }
        .onDisappear {
            stopTimer()
        }
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

    // MARK: - Timer Management

    private func startTimer() {
        // 이미 만료되었거나 채팅 중이면 타이머 불필요
        guard !post.isExpired && !post.shouldOpenChat else { return }

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                // struct이므로 값 복사됨. onDisappear에서 타이머 정리
                updateTimeRemaining()

                // 상태 변경 시 타이머 중지
                if post.isExpired || post.shouldOpenChat {
                    stopTimer()
                }
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func updateTimeRemaining() {
        let interval = post.timeUntilMeet

        if interval <= 0 {
            timeRemaining = "종료됨"
        } else if interval <= TimeConstants.chatOpenBeforeMeetTime {
            timeRemaining = "채팅방이 곧 열립니다"
        } else {
            // 채팅창이 열리기까지의 시간 (약속시간 - 5분)
            let timeUntilChatOpen = interval - TimeConstants.chatOpenBeforeMeetTime
            let minutes = Int(timeUntilChatOpen / 60)
            let seconds = Int(timeUntilChatOpen.truncatingRemainder(dividingBy: 60))

            timeRemaining = String(format: "약속시간 5분 전에 임시 채팅창이 열려요!(%02d분 %02d초 후)", minutes, seconds)
        }
    }
}
