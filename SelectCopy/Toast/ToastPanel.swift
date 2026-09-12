import AppKit
import SwiftUI

@MainActor
final class ToastPanel: NSPanel, ToastPaneling {
    private var hostingView: NSHostingView<ToastView>?

    private static let toastContentSize = NSSize(width: 140, height: 38)

    var contentSize: NSSize {
        Self.toastContentSize
    }

    func size(for content: ToastContent) -> NSSize {
        guard case let .text(text) = content else {
            return NSSize(width: 36, height: 36)
        }
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
        return NSSize(width: min(360, ceil(textWidth) + 48), height: 36)
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
        view.wantsLayer = true
        view.layer?.cornerRadius = 11
        view.layer?.masksToBounds = true
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
