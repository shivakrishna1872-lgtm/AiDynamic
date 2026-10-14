import FirebaseCore
import FirebaseMessaging
import SwiftUI
import UIKit

@main
struct IslandIOSApp: App {
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup { IOSRootView() }
    }
}

final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        AuthSession.shared.start()
        PushNotifications.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotifications.shared.setAPNSToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotifications.shared.errorMessage = error.localizedDescription
    }
}

struct IOSRootView: View {
    @StateObject private var auth = AuthSession.shared

    var body: some View {
        Group {
            if let uid = auth.uid {
                ApprovalTasksView(ownerUID: uid)
            } else {
                AuthenticationView(session: auth)
            }
        }
        .task { auth.start() }
    }
}
