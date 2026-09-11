import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()
    let loginItem = LoginItemService()
    let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.shutdown()
    }
}
