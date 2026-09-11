import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(permission: PermissionCoordinator) {
        if let window {
            window.makeKeyAndOrderFront(nil); return
        }
        let controller = NSHostingController(rootView: OnboardingView(
            requestAccess: { permission.requestAccess() },
            openSettings: { permission.openSystemSettings() }
        ))
        let window = NSWindow(contentViewController: controller)
        window.title = "SelectCopy"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        self.window = nil
    }
}
