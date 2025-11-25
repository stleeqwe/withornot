import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    private var pendingFCMToken: String? // 사용자 인증 전 받은 FCM 토큰 임시 저장

    init() {
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                print("🔥 Firebase Auth: User authenticated - \(user.uid)")
                self?.isAuthenticated = true
                self?.fetchOrCreateUser(uid: user.uid)
            } else {
                print("⚠️ Firebase Auth: No user authenticated")
                self?.isAuthenticated = false
                self?.currentUser = nil
            }
        }
    }
    
    func signInAnonymously() {
        print("🔐 Firebase Auth: Starting anonymous sign in...")
        Auth.auth().signInAnonymously { [weak self] result, error in
            if let error = error {
                print("❌ Anonymous sign in error: \(error.localizedDescription)")
                return
            }

            if let user = result?.user {
                print("✅ Firebase Auth: Anonymous sign in successful - \(user.uid)")
                self?.fetchOrCreateUser(uid: user.uid)
            }
        }
    }
    
    private func fetchOrCreateUser(uid: String) {
        let userRef = db.collection("users").document(uid)

        userRef.getDocument { [weak self] snapshot, error in
            if let error = error {
                print("Error fetching user: \(error.localizedDescription)")
                return
            }

            if let snapshot = snapshot, snapshot.exists,
               let user = try? snapshot.data(as: User.self) {
                self?.currentUser = user
            } else {
                // 새 사용자 생성
                let newUser = User(
                    id: uid,
                    fcmToken: nil,
                    createdAt: Date()
                )

                do {
                    try userRef.setData(from: newUser)
                    self?.currentUser = newUser
                } catch {
                    print("Error creating user: \(error.localizedDescription)")
                }
            }

            // 대기 중인 FCM 토큰이 있으면 저장
            if let pendingToken = self?.pendingFCMToken {
                self?.saveFCMToken(pendingToken, for: uid)
                self?.pendingFCMToken = nil
            }
        }
    }
    
    func updateFCMToken(_ token: String) {
        guard let userId = currentUser?.id else {
            // 사용자가 아직 인증되지 않았으면 토큰을 임시 저장
            pendingFCMToken = token
            print("📲 FCM Token saved pending user authentication")
            return
        }

        saveFCMToken(token, for: userId)
    }

    private func saveFCMToken(_ token: String, for userId: String) {
        db.collection("users").document(userId).updateData([
            "fcmToken": token
        ]) { error in
            if let error = error {
                print("❌ Failed to save FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token saved successfully for user: \(userId)")
            }
        }

        // 로컬 currentUser도 업데이트
        if var user = currentUser {
            user.fcmToken = token
            currentUser = user
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
