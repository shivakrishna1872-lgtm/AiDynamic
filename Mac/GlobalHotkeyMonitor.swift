import ApplicationServices
import CoreGraphics
import Foundation

final class GlobalHotkeyMonitor {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var active = false

    func start() -> Bool {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        guard CGPreflightListenEventAccess() else { return false }

        let mask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let createdTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.eventCallback,
            userInfo: info
        ) else { return false }

        guard let createdSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0) else {
            return false
        }
        tap = createdTap
        source = createdSource
        CFRunLoopAddSource(CFRunLoopGetMain(), createdSource, .commonModes)
        CGEvent.tapEnable(tap: createdTap, enable: true)
        return true
    }

    private func process(_ type: CGEventType, _ event: CGEvent) {
        guard type == .flagsChanged else { return }
        let flags = event.flags
        let bothDown = flags.contains(.maskAlternate) && flags.contains(.maskCommand)
        guard bothDown != active else { return }
        active = bothDown
        if bothDown { onPressed?() } else { onReleased?() }
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Re-enable a temporarily disabled listen-only tap.
            let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        Unmanaged<GlobalHotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue().process(type, event)
        return Unmanaged.passUnretained(event)
    }
}
