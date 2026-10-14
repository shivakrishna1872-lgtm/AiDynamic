import AppKit
import FirebaseCore
import SwiftUI

@main
struct IslandMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MacControlView()
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var islandPanel: NSPanel?
    private let hotkey = GlobalHotkeyMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseApp.configure()
        AuthSession.shared.start()

        hotkey.onPressed = { Task { @MainActor in MacAgentModel.shared.beginHotkey() } }
        hotkey.onReleased = { Task { @MainActor in MacAgentModel.shared.endHotkey() } }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            self.islandPanel?.updatePosition(for: screen)
        }
        if !hotkey.start() {
            MacAgentModel.shared.errorMessage = "Enable Input Monitoring in System Settings to use ⌥ + ⌘."
        }

        makeIslandPanel()
    }

    private func makeIslandPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let initialFrame = NSRect(
            x: 0,
            y: 0,
            width: IslandWindow.windowWidth,
            height: IslandWindow.windowHeight
        )
        let panel = IslandWindow(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        if let screen { panel.updatePosition(for: screen) }
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(
            rootView: IslandView().environmentObject(MacAgentModel.shared)
        )
        panel.orderFrontRegardless()
        islandPanel = panel
    }
}
