import SwiftUI

extension View {
    // 키보드 숨기기
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // 조건부 modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    // 로딩 오버레이
    func loadingOverlay(_ isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        )
                }
            }
        )
    }
    
    // 에러 알림
    func errorAlert(error: Binding<String?>) -> some View {
        self.alert("오류", isPresented: .constant(error.wrappedValue != nil)) {
            Button("확인") {
                error.wrappedValue = nil
            }
        } message: {
            Text(error.wrappedValue ?? "")
        }
    }
}

