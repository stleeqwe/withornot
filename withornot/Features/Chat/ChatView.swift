import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var showReportCompleteAlert = false

    let post: Post
    
    init(post: Post) {
        self.post = post
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            post: post,
            authService: AuthService()
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }

                VStack(spacing: 0) {
                    // 채팅 정보 헤더
                    chatHeader
                    
                    // 메시지 목록
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubbleView(
                                        message: message,
                                        isMyMessage: viewModel.isMyMessage(message)
                                    )
                                    .id(message.id)
                                    .contextMenu {
                                        if message.userId != "system" {
                                            Button(role: .destructive) {
                                                viewModel.reportMessage(message)
                                                showReportCompleteAlert = true
                                            } label: {
                                                Label("신고", systemImage: "exclamationmark.triangle")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .onTapGesture {
                                hideKeyboard()
                            }
                        }
                        .onTapGesture {
                            hideKeyboard()
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            withAnimation {
                                proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }
                    
                    // 입력창
                    if !viewModel.isChatExpired {
                        chatInputBar
                    }
                }
                
                // 만료 오버레이
                if viewModel.isChatExpired {
                    expiredOverlay
                }
            }
            .navigationTitle("임시 채팅방")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("나가기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            // 채팅방 신고
                        } label: {
                            Label("채팅방 신고", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .onAppear {
                setupViewModel()
            }
            .errorAlert(error: $viewModel.error)
            .alert("신고 완료", isPresented: $showReportCompleteAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("메시지가 신고되었습니다.")
            }
        }
    }
    
    private var chatHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.blue)
                Text(post.locationText)
                    .font(.googleSans(size: 15, weight: .medium))
                
                Spacer()
                
                Text(post.meetTime.timeString)
                    .font(.googleSans(size: 15))
                    .foregroundColor(.secondaryText)
            }
            
            Text(viewModel.timeRemaining)
                .font(.googleSans(size: 13))
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.cardBackground)
    }
    
    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("메시지 입력...", text: $viewModel.newMessageText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.cardBackground)
                .cornerRadius(20)
                .focused($isInputFocused)
                .onSubmit {
                    viewModel.sendMessage()
                }
            
            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.googleSans(size: 32))
                    .foregroundColor(viewModel.newMessageText.isEmpty ? .gray : .blue)
            }
            .disabled(viewModel.newMessageText.isEmpty)
        }
        .padding()
        .background(Color.background)
    }
    
    private var expiredOverlay: some View {
        Color.black.opacity(0.8)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    Text("채팅방이 사라졌습니다")
                        .font(.googleSans(size: 20, weight: .semibold))
                    Text("10분의 연결이 끝났어요")
                        .font(.googleSans(size: 14))
                        .foregroundColor(.secondaryText)
                    
                    Button("확인") {
                        dismiss()
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(16)
            )
    }
    
    private func setupViewModel() {
        // 실제 EnvironmentObject로 ViewModel 재설정
    }
}
