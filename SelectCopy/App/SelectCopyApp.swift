import AppKit
import SwiftUI

enum ProductIdentity {
    static let name = "SelectCopy"
    static let bundleIdentifier = "com.selectcopy.app"
}

@main
struct SelectCopyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(ProductIdentity.name, systemImage: "clipboard") {
            Text(self.appDelegate.container.permission.isTrusted ? "Active" : "Accessibility permission required")
            Divider()
            Button("Settings") {
                self.appDelegate.settingsWindow.show(
                    store: self.appDelegate.container.settings,
                    localizer: self.appDelegate.container.localizer,
                    loginItem: self.appDelegate.loginItem,
                    preview: { self.appDelegate.container.toast.showPreview() }
                )
            }
            Button("Show test toast") { self.appDelegate.container.toast.showPreview() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
