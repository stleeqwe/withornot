import SwiftUI

struct CreatePostView: View {
    @StateObject private var viewModel = CreatePostViewModel(
        locationService: LocationService(),
        authService: AuthService(),
        notificationService: NotificationService()
    )
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var notificationService: NotificationService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    enum Field {
        case message, location
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }

                ScrollView {
                    VStack(spacing: 30) {
                        // 메시지 입력
                        VStack(alignment: .leading, spacing: 12) {
                            Label("메시지", systemImage: "text.bubble")
                                .font(.googleSans(size: 13, weight: .medium))
                                .foregroundColor(.secondaryText)

                            TextField("자유롭게 한마디 (선택사항)", text: $viewModel.message, axis: .vertical)
                                .textFieldStyle(CustomTextFieldStyle())
                                .lineLimit(3...5)
                                .focused($focusedField, equals: .message)

                            // 메시지 빠른 선택
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.quickMessages, id: \.self) { quickMessage in
                                        QuickSelectButton(
                                            title: quickMessage,
                                            isSelected: viewModel.message == quickMessage
                                        ) {
                                            viewModel.setQuickMessage(quickMessage)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 장소 입력
                        VStack(alignment: .leading, spacing: 12) {
                            Label("만남 장소", systemImage: "mappin.circle")
                                .font(.googleSans(size: 13, weight: .medium))
                                .foregroundColor(.secondaryText)
                            
                            TextField("예: 한강공원 뚝섬지구", text: $viewModel.locationText)
                                .textFieldStyle(CustomTextFieldStyle())
                                .focused($focusedField, equals: .location)
                            
                            // 빠른 선택
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.quickLocations, id: \.self) { location in
                                        QuickSelectButton(
                                            title: location,
                                            isSelected: viewModel.locationText == location
                                        ) {
                                            viewModel.setQuickLocation(location)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 시간 선택
                        VStack(alignment: .leading, spacing: 12) {
                            Label("만남 시간 (오늘)", systemImage: "clock")
                                .font(.googleSans(size: 13, weight: .medium))
                                .foregroundColor(.secondaryText)

                            DatePicker(
                                "",
                                selection: $viewModel.meetTime,
                                in: viewModel.minimumDate...viewModel.maximumDate,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                            .labelsHidden()
                            .frame(height: 120)
                            .clipped()

                            // 빠른 선택
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.quickTimes, id: \.minutes) { time in
                                        QuickSelectButton(
                                            title: time.label,
                                            isSelected: false
                                        ) {
                                            viewModel.setQuickTime(minutes: time.minutes)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 현재 위치 표시
                        if locationService.isLocationAvailable {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text("현재 위치 기반 거리 표시 활성화")
                                    .font(.googleSans(size: 13))
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // 채팅창 안내 메시지
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color.mainBlue)
                                .font(.googleSans(size: 16))
                            Text("약속시간 5분 전, 채팅창이 열려요!")
                                .font(.googleSans(size: 14, weight: .medium))
                                .foregroundColor(.primaryText)
                            Spacer()
                        }
                        .padding()
                        .background(Color.mainBlue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding()
                    .onTapGesture {
                        hideKeyboard()
                    }
                }
                .onTapGesture {
                    hideKeyboard()
                }
            }
            .navigationTitle("런닝 약속 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        viewModel.createPost()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                setupViewModel()
            }
            .onChange(of: viewModel.isComplete) { isComplete in
                if isComplete {
                    dismiss()
                }
            }
            .errorAlert(error: $viewModel.error)
            .loadingOverlay(viewModel.isLoading)
        }
    }
    
    private func setupViewModel() {
        // 실제 EnvironmentObject로 ViewModel 재설정
    }
}

// MARK: - Custom Components
struct QuickSelectButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.googleSans(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.blue : Color.blue.opacity(0.1)
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}
