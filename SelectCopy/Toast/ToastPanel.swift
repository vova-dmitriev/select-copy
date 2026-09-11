import AppKit
import SwiftUI

@MainActor
final class ToastPanel: NSPanel, ToastPaneling {
    private var hostingView: NSHostingView<ToastView>?

    private static let toastContentSize = NSSize(width: 140, height: 38)

    var contentSize: NSSize {
        Self.toastContentSize
    }

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.toastContentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    func show(content: ToastContent, frame: NSRect) {
        let view = NSHostingView(rootView: ToastView(content: content))
        self.hostingView = view
        contentView = view
        setFrame(frame, display: false)
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}

@MainActor
final class SystemToastScreens: ToastScreenProviding {
    func screen(containing point: CGPoint) -> ToastScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }.map(self.makeScreen)
    }

    var mainScreen: ToastScreen? {
        NSScreen.main.map(self.makeScreen)
    }

    private func makeScreen(_ screen: NSScreen) -> ToastScreen {
        ToastScreen(frame: screen.frame, visibleFrame: screen.visibleFrame)
    }
}
