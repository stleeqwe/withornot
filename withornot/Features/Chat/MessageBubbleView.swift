import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isMyMessage: Bool
    
    var body: some View {
        HStack {
            if isMyMessage {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 4) {
                // 시스템 메시지
                if message.userId == "system" {
                    Text(message.text)
                        .font(.googleSans(size: 13))
                        .foregroundColor(.secondaryText)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                } else {
                    // 일반 메시지
                    VStack(alignment: isMyMessage ? .trailing : .leading, spacing: 4) {
                        Text(isMyMessage ? "나" : "익명 (\(message.displayUserId))")
                            .font(.googleSans(size: 11))
                            .foregroundColor(.secondaryText)
                        
                        Text(message.text)
                            .font(.googleSans(size: 15))
                            .foregroundColor(isMyMessage ? .white : .primaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                isMyMessage ?
                                    AnyView(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    ) :
                                    AnyView(Color.cardBackground)
                            )
                            .cornerRadius(18)
                    }
                }
            }
            
            if !isMyMessage {
                Spacer(minLength: 60)
            }
        }
    }
}
