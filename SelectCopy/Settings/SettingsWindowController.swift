import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    private var window: NSWindow?

    func show(store: SettingsStore, localizer: Localizer, loginItem: LoginItemService, preview: @escaping () -> Void) {
        if let window {
            bringForward(window)
            return
        }
        let view = SettingsView(
            store: store,
            localizer: localizer,
            loginItem: loginItem,
            showPreview: preview
        )
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "SelectCopy"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 360))
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        window.center()
        bringForward(window)
    }

    private func bringForward(_ window: NSWindow) {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}
