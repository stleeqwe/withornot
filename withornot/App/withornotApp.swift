import SwiftUI
import Firebase
import FirebaseMessaging

@main
struct withornotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService()
    @StateObject private var locationService = LocationService()
    @StateObject private var notificationService = NotificationService()
    
    var body: some Scene {
        WindowGroup {
            PostListView()
                .environmentObject(authService)
                .environmentObject(locationService)
                .environmentObject(notificationService)
                .preferredColorScheme(nil) // System 설정 따름
                .onAppear {
                    // 앱 시작 시 익명 로그인
                    if !authService.isAuthenticated {
                        authService.signInAnonymously()
                    }
                }
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Firebase 초기화
        FirebaseApp.configure()
        print("🔥 Firebase: App configured successfully")

        // Firestore 오프라인 지속성 활성화
        let settings = Firestore.firestore().settings
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
        print("💾 Firebase: Offline persistence enabled")
        
        // FCM 설정
        Messaging.messaging().delegate = self
        
        // 알림 권한 요청
        UNUserNotificationCenter.current().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { _, _ in }
        )
        
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

// MARK: - FCM Delegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📲 FCM Token received: \(fcmToken ?? "nil")")
        // FCM 토큰을 Firestore에 저장할 수 있음
        if fcmToken != nil {
            print("✅ FCM Token is valid")
        } else {
            print("⚠️ FCM Token is nil")
        }
    }
}

// MARK: - Notification Center Delegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // 알림 탭 처리
        completionHandler()
    }
}

