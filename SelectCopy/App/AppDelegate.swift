import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()
    let loginItem = LoginItemService()
    let settingsWindow = SettingsWindowController()
    let onboardingWindow = OnboardingWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.container.start()
        if !self.container.permission.isTrusted {
            self.onboardingWindow.show(permission: self.container.permission)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.container.shutdown()
    }
}
