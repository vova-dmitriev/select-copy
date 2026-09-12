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
        MenuBarExtra(ProductIdentity.name, systemImage: "checkmark.square.fill") {
            PermissionMenuContent(permission: self.appDelegate.container.permission)
            Divider()
            Button("Settings") {
                self.appDelegate.showSettings()
            }
            Button("Show test toast") { self.appDelegate.container.toast.showPreview() }
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

private struct PermissionMenuContent: View {
    @ObservedObject var permission: PermissionCoordinator

    var body: some View {
        Text(permission.isTrusted ? "Active" : "Accessibility permission required")
        if !permission.isTrusted {
            Button("Allow Accessibility access…") {
                permission.requestAccess()
                permission.openSystemSettings()
            }
        }
    }
}
