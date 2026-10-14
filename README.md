# AiDynamic — Island Agent (native macOS + iOS)

Dynamic Island-inspired AI companion with a native macOS agent and an iOS approval app. The app's character artwork and agent logic are original; `Mac/IslandWindow.swift` adapts DynamicIsle’s MIT-licensed floating-panel positioning pattern (see `ATTRIBUTION.md`).

## Generate and run in Xcode

Requirements: a Mac with Xcode (targets macOS 14 and iOS 17) and XcodeGen. Install XcodeGen with Homebrew if needed (`brew install xcodegen`). From the repository root:

```sh
xcodegen generate
open IslandAgent.xcodeproj
```

XcodeGen generates the `IslandMac` and `IslandIOS` schemes from `project.yml`. Xcode resolves Firebase through Swift Package Manager. Choose `IslandMac` + **My Mac**, or `IslandIOS` + an iPhone simulator/device. To install on a physical iPhone, set your Team under Signing & Capabilities. The sample bundle IDs are `com.myname.IslandMac` and `com.myname.IslandIOS`; change them if needed and use the same IDs when registering apps in Firebase.

## Firebase setup

1. Create a Firebase project, register separate macOS and iOS apps using the bundle IDs above, and enable **Authentication → Email/Password** and **Cloud Firestore**.
2. Put each downloaded config plist at `Firebase/GoogleService-Info-Mac.plist` and `Firebase/GoogleService-Info-iOS.plist`. Project generation tolerates missing config files, but the apps require their matching plist at runtime.
3. Deploy rules with `firebase deploy --only firestore:rules`. Sign in with the same Firebase account on Mac and iPhone.

`.gitignore` excludes local Firebase plist files, APNs `.p8` keys, service-account credentials, generated Xcode products, and local preview-server files. Never commit APNs keys or service-account credentials.

## Test the Mac island and local agent

- Install Ollama and fetch the model: `ollama pull llama3.1`. The app calls `http://localhost:11434`.
- Build and run `IslandMac`; sign in and grant Microphone and Speech Recognition access.
- Grant **Input Monitoring** in System Settings → Privacy & Security → Input Monitoring; relaunch if macOS requests it.
- Hold **⌥ + ⌘**, speak, and release. Speech recognition is requested on-device. The island panel sits top-center on the main display; notch alignment/external displays need device testing.
- The agent only offers note create/delete tools, stores notes in its app-private Application Support folder, and waits for explicit iPhone approval before changing a note.

## Test iPhone approvals and background alerts

Run `IslandIOS` in Simulator or on iPhone to test sign-in and live Firestore approvals. The UI draws a simulated island and buddy: iOS apps cannot overlay or change the system Dynamic Island.

`FirebaseAppDelegateProxyEnabled` is false and `FirebaseMessagingInstallationIdEnabled` is true in the generated iOS Info.plist. For background push alerts, use a real iPhone, enable the **Push Notifications** capability with Apple Developer signing, upload an APNs authentication key to Firebase Cloud Messaging, and deploy the Cloud Function:

```sh
cd functions && npm install
cd ..
firebase deploy --only functions:notifyOnPendingApproval
```

Deploy Firestore rules with `firebase deploy --only firestore:rules`. Cloud Functions deployment requires Firebase Blaze billing; review pricing first. Push delivery is best-effort; Firestore remains the source of truth for pending approvals.

## Previews and attribution

- `preview/island-mockup.svg` — static Mac/iPhone concept layout.
- `preview/mascot-animation.svg` — animated SVG mascot sequence.
- `preview/render_mascot.py` — Python/Pillow generator for a looping GIF and sampled PNG frames.
- `Mac/IslandWindow.swift` adapts DynamicIsle under MIT; preserve `ATTRIBUTION.md` when redistributing. No Fazm source is copied.

## Verification notes

The authoring workspace is Linux and has no Xcode, Swift compiler, or XcodeGen, so native targets cannot be built or exercised here. Generate/build and test the project in Xcode on macOS; the GIF/PNG artifacts are generated concept previews, not native app captures.
