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
            Text(ProductIdentity.name)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}
