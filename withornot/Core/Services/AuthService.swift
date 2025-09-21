import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
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
        }
    }
    
    func updateFCMToken(_ token: String) {
        guard let userId = currentUser?.id else { return }
        
        db.collection("users").document(userId).updateData([
            "fcmToken": token
        ])
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
