import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()
    let loginItem = LoginItemService()
    let settingsWindow = SettingsWindowController()
    let onboardingWindow = OnboardingWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        self.container.start()
        if !self.container.permission.isTrusted {
            self.onboardingWindow.show(permission: self.container.permission)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        self.container.shutdown()
    }

    func showSettings() {
        self.settingsWindow.show(
            store: self.container.settings,
            localizer: self.container.localizer,
            loginItem: self.loginItem,
            preview: { self.container.toast.showPreview() }
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        self.showSettings()
        return true
    }
}
