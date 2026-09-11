import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    private var window: NSWindow?

    func show(store: SettingsStore, localizer: Localizer, loginItem: LoginItemService, preview: @escaping () -> Void) {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let controller = NSHostingController(rootView: SettingsView(store: store, localizer: localizer, loginItem: loginItem, showPreview: preview))
        let window = NSWindow(contentViewController: controller)
        window.title = "SelectCopy"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 430, height: 360))
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        window.center(); window.makeKeyAndOrderFront(nil)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) { window = nil }
}
