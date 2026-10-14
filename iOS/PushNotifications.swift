import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class PushNotifications: NSObject, ObservableObject {
    static let shared = PushNotifications()

    @Published private(set) var permissionGranted = false
    @Published var errorMessage: String?

    private var configured = false
    private var latestFID: String?
    private var previousUID: String?
    private var authListener: AuthStateDidChangeListenerHandle?

    func configure() {
        guard !configured else { return }
        configured = true
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                let nextUID = user?.uid
                if let oldUID = self.previousUID, oldUID != nextUID {
                    await self.removeDevice(from: oldUID)
                }
                self.previousUID = nextUID
                await self.uploadCurrentInstallationID()
            }
        }
        // Firebase Messaging supplies the current Installation ID through its delegate callback.
        Task { await refreshPermissionStatus() }
    }

    func enableNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            permissionGranted = granted
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setAPNSToken(_ token: Data) {
        Messaging.messaging().apnsToken = token
    }

    private func refreshPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionGranted = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    private func receiveFID(_ fid: String?) {
        latestFID = fid
        Task { await uploadCurrentInstallationID() }
    }

    private var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
    }

    private func uploadCurrentInstallationID() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let fid = latestFID, !fid.isEmpty else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("devices").document(deviceID)
                .setData(["fid": fid, "platform": "ios", "updatedAt": Timestamp(date: Date())], merge: true)
        } catch {
            errorMessage = "Could not register this phone for notifications: \(error.localizedDescription)"
        }
    }

    private func removeDevice(from uid: String) async {
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("devices").document(deviceID).delete()
        } catch {
            errorMessage = "Could not unregister the previous phone account: \(error.localizedDescription)"
        }
    }
}

extension PushNotifications: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistration installationID: String?) {
        Task { @MainActor in self.receiveFID(installationID) }
    }
}

extension PushNotifications: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
