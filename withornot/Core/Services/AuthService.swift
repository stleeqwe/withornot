import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// 인증 관련 에러 타입
enum AuthError: LocalizedError {
    case signInFailed(Error)
    case userCreationFailed(Error)
    case tokenUpdateFailed(Error)

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "로그인에 실패했습니다. 다시 시도해주세요."
        case .userCreationFailed:
            return "사용자 생성에 실패했습니다."
        case .tokenUpdateFailed:
            return "알림 설정 업데이트에 실패했습니다."
        }
    }
}

@MainActor
class AuthService: ObservableObject, AuthServiceProtocol {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private var pendingFCMToken: String?

    init() {
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    print("🔥 Firebase Auth: User authenticated - \(user.uid)")
                    self?.isAuthenticated = true
                    await self?.fetchOrCreateUser(uid: user.uid)
                } else {
                    print("⚠️ Firebase Auth: No user authenticated")
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                }
            }
        }
    }

    func signInAnonymously() {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        print("🔐 Firebase Auth: Starting anonymous sign in...")

        Task {
            do {
                let result = try await Auth.auth().signInAnonymously()
                print("✅ Firebase Auth: Anonymous sign in successful - \(result.user.uid)")
                await fetchOrCreateUser(uid: result.user.uid)
                isLoading = false
            } catch {
                print("❌ Anonymous sign in error: \(error.localizedDescription)")
                self.error = AuthError.signInFailed(error).localizedDescription
                isLoading = false
            }
        }
    }

    private func fetchOrCreateUser(uid: String) async {
        let userRef = db.collection("users").document(uid)

        do {
            let snapshot = try await userRef.getDocument()

            if snapshot.exists, let user = try? snapshot.data(as: User.self) {
                currentUser = user
                print("✅ User fetched: \(uid)")
            } else {
                // 새 사용자 생성
                let newUser = User(
                    id: uid,
                    fcmToken: nil,
                    createdAt: Date()
                )

                try userRef.setData(from: newUser)
                currentUser = newUser
                print("✅ New user created: \(uid)")
            }

            // 대기 중인 FCM 토큰이 있으면 저장
            if let pendingToken = pendingFCMToken {
                await saveFCMToken(pendingToken, for: uid)
                pendingFCMToken = nil
            }
        } catch {
            print("❌ Error fetching/creating user: \(error.localizedDescription)")
            self.error = AuthError.userCreationFailed(error).localizedDescription
        }
    }

    func updateFCMToken(_ token: String) {
        guard let userId = currentUser?.id else {
            // 사용자가 아직 인증되지 않았으면 토큰을 임시 저장
            pendingFCMToken = token
            print("📲 FCM Token saved pending user authentication")
            return
        }

        Task {
            await saveFCMToken(token, for: userId)
        }
    }

    private func saveFCMToken(_ token: String, for userId: String) async {
        do {
            try await db.collection("users").document(userId).updateData([
                "fcmToken": token
            ])

            // 로컬 currentUser도 업데이트
            if var user = currentUser {
                user.fcmToken = token
                currentUser = user
            }

            print("✅ FCM token saved successfully for user: \(userId)")
        } catch {
            print("❌ Failed to save FCM token: \(error.localizedDescription)")
            self.error = AuthError.tokenUpdateFailed(error).localizedDescription
        }
    }

    /// 에러 상태 초기화
    func clearError() {
        error = nil
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
