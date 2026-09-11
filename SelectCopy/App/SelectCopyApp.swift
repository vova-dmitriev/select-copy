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
            Text(appDelegate.container.permission.isTrusted ? "Active" : "Accessibility permission required")
            Divider()
            Button("Settings") {
                appDelegate.settingsWindow.show(
                    store: appDelegate.container.settings,
                    localizer: appDelegate.container.localizer,
                    loginItem: appDelegate.loginItem,
                    preview: { appDelegate.container.toast.showPreview() }
                )
            }
            Button("Show test toast") { appDelegate.container.toast.showPreview() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
