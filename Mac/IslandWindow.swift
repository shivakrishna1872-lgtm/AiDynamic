import AppKit

// Adapted from DynamicIsle/Core/Window/IslandWindow.swift
// Copyright (c) 2024 Sarthak Pant. MIT terms are retained in ATTRIBUTION.md.
final class IslandWindow: NSPanel {
    static let windowWidth: CGFloat = 430
    static let windowHeight: CGFloat = 200

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: backingStoreType,
            defer: flag
        )
        configureIslandWindow()
    }

    private func configureIslandWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func updatePosition(for screen: NSScreen) {
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.height - visibleFrame.height - (visibleFrame.minY - screenFrame.minY)
        let frame = NSRect(
            x: screenFrame.midX - Self.windowWidth / 2,
            y: screenFrame.maxY - menuBarHeight - Self.windowHeight - 8,
            width: Self.windowWidth,
            height: Self.windowHeight
        )
        setFrame(frame, display: true, animate: false)
    }
}
