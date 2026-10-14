# AiDynamic — Island Agent (native macOS + iOS)

Dynamic island for AI requests, with a native macOS agent and iOS approval companion.

This repository contains native Swift sources for a macOS menu-bar/notch companion, an iOS approval app, shared Firebase code, Firestore rules, and a Firebase Cloud Function for remote approval alerts. The character artwork and agent logic are original; `Mac/IslandWindow.swift` adapts DynamicIsle’s MIT-licensed floating-panel positioning pattern (see `ATTRIBUTION.md`).

## Generate and run in Xcode

Requirements: a Mac with Xcode (the project targets macOS 14 and iOS 17), and XcodeGen. Install XcodeGen with Homebrew if needed (`brew install xcodegen`). From the repository root:

```sh
xcodegen generate
open IslandAgent.xcodeproj
```

XcodeGen creates `IslandAgent.xcodeproj` from the checked-in `project.yml`, with `IslandMac` and `IslandIOS` schemes. Firebase is resolved through Swift Package Manager the first time Xcode builds. To build, choose `IslandMac` and **My Mac**, or `IslandIOS` and an iPhone simulator/device. For installing to a physical iPhone, set your Team under Signing & Capabilities. The checked-in bundle IDs are examples (`com.myname.IslandMac`, `com.myname.IslandIOS`); change them if they conflict or do not match your Firebase app registrations.

### Firebase setup (needed for sign-in and approvals)

1. Create a Firebase project, register separate Apple apps using the exact macOS and iOS bundle IDs shown in Xcode, and enable **Authentication → Email/Password** and **Cloud Firestore**.
2. Download each app's config. Put the macOS plist at `Firebase/GoogleService-Info-Mac.plist` and the iOS plist at `Firebase/GoogleService-Info-iOS.plist`. `project.yml` includes each as an optional resource so project generation works before config files exist; the apps need their matching config files to run Firebase.
3. Deploy the repository's Firestore rules with Firebase CLI: `firebase deploy --only firestore:rules`. Sign in with the same Firebase account on Mac and iPhone.

The `.gitignore` excludes the local Firebase plist files, APNs `.p8` keys, and service-account credentials by default. Firebase plist files are client configuration rather than server credentials, but keep your project policy in mind; never commit APNs keys or service-account credentials.

### Test the Mac island and local agent

- Install Ollama, start it, and pull the model with `ollama pull llama3.1` (the app calls the local Ollama API at `http://localhost:11434`).
- Build and run `IslandMac` from Xcode, then sign in. Allow Microphone and Speech Recognition when prompted.
- Grant **Input Monitoring** in System Settings → Privacy & Security → Input Monitoring, then relaunch if macOS asks.
- Hold **⌥ + ⌘**, speak a prompt, and release. Speech recognition is requested on-device. The island panel appears at the top center of the main display; notch alignment and external-display positioning need device testing.
- The agent only offers note create/delete tools, stores notes in its app-private Application Support folder, and waits for explicit phone approval before changing a note.

### Test iPhone approval and push alerts

Run `IslandIOS` in the iOS Simulator or on a device to test sign-in and live Firestore approvals. To receive remote push while the app is backgrounded, use a real iPhone, enable the **Push Notifications** capability with Apple Developer signing, upload an APNs authentication key to Firebase Cloud Messaging, and deploy the Cloud Function as described below. The iPhone app displays a SwiftUI illustration/animation beside a simulated island shape; iOS apps cannot overlay or change the actual system Dynamic Island.

`FirebaseAppDelegateProxyEnabled` is set to `false` and `FirebaseMessagingInstallationIdEnabled` to `true` in the generated iOS Info.plist. APNs is not required for foreground Firestore approval testing.

## Add source manually (if not using XcodeGen)

`project.yml` is the source of truth for target membership. Shared files go into both targets; `Shared/PhoneIslandCompanion.swift` is the iOS-only companion stage. macOS files are in `Mac/`, iOS files in `iOS/`. Keep `ATTRIBUTION.md` with redistributed source.

## Remote notifications while away

The iPhone registers with APNs/FCM, stores the FCM Installation ID (FID) in `users/{uid}/devices/{deviceId}`, and the Cloud Function sends an alert when a pending approval task is created. The lock-screen message is generic; task details remain in Firestore.

1. In Xcode, add the iOS **Push Notifications** capability and configure signing with your Apple Developer account. Test remote push on a real iPhone; Simulator behavior is not a substitute for APNs delivery verification.
2. In Apple Developer, create an APNs authentication key. Upload the `.p8`, Key ID, and Team ID in Firebase Console → Project settings → Cloud Messaging. Never include the `.p8` or a service-account file in the app or repository.
3. Enable the Firebase Cloud Messaging API. Cloud Functions deployment requires a Firebase Blaze project/billing account. Review the applicable pricing before deployment.
4. Install the Firebase CLI, run `firebase init functions` if the Firebase project is not configured, set the correct Firebase project, install function dependencies with `cd functions && npm install`, then deploy `firebase deploy --only functions:notifyOnPendingApproval`.
5. Deploy `firestore.rules` using `firebase deploy --only firestore:rules`.
6. Sign in on both devices, allow notifications on iPhone, create a pending approval on Mac, then put the iPhone app in background and confirm an alert arrives. Also confirm the Firestore task appears and Allow/Decline resolves the Mac wait.

FCM/APNs is best-effort delivery; notification settings, Focus modes, connectivity, and Apple delivery policy can prevent an alert. Firestore remains the source of truth; the iOS app shows tasks live when opened.

## Repository reference notes

- [DynamicIsle](https://github.com/sarthakpant772/DynamicIsle) provides a useful floating `NSPanel`, SwiftUI pill, and mode/view-model pattern. Its source separates cloud AI chat from its Ollama voice-note summary path, so this project intentionally keeps all prompts on local Ollama.
- [Fazm](https://github.com/mediar-ai/fazm) demonstrates broader desktop automation, but its source includes external model/provider and data-transfer paths and an approval gate with permissive default mode. This project does not copy those flows: it keeps the tool allowlist narrow and requires an explicit phone approval before note filesystem changes.
- `Mac/IslandWindow.swift` adapts the MIT-licensed DynamicIsle `IslandWindow.swift` floating-panel configuration and top-center/menu-bar position calculation. Required copyright and permission terms are retained in `ATTRIBUTION.md`.
- Fazm source code is not copied; its root `LICENSE` was not present in the repository contents inspected. Its permissive approval default and external service paths were not adopted.

## Testing status

The coding workspace is Linux and has no `swift` or `xcodebuild`; it cannot build the native targets, run speech/hotkey tests, exercise APNs, or show a real macOS/iOS Simulator rendering. The source must be opened in Xcode on macOS and tested with the Firebase/APNs setup above. Run Firebase Functions tests/emulator checks locally after installing dependencies. SVG previews are included at `preview/island-mockup.svg` and `preview/mascot-animation.svg`. A generated looping GIF/storyboard preview is not a running native app.
