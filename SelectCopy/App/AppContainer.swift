import AppKit
import Combine

@MainActor
final class AppContainer: ObservableObject {
    let settings: SettingsStore
    let localizer: Localizer
    let permission: PermissionCoordinator
    let monitor: SelectionMonitoring
    let copyCoordinator: SelectionCopyCoordinator
    let toast: ToastCoordinator

    private var started = false

    init(
        settings: SettingsStore = SettingsStore(),
        localizer: Localizer? = nil,
        permission: PermissionCoordinator = PermissionCoordinator(),
        monitor: SelectionMonitoring? = nil
    ) {
        self.settings = settings
        self.localizer = localizer ?? Localizer(language: settings.settings.language)
        self.permission = permission
        let pasteboard = PasteboardClient()
        let panel = ToastPanel()
        let toast = ToastCoordinator(
            settings: settings,
            localizer: self.localizer,
            panel: panel,
            screens: SystemToastScreens()
        )
        self.toast = toast
        self.monitor = monitor ?? SelectionMonitor()
        self.copyCoordinator = SelectionCopyCoordinator(
            selectionReader: AccessibilitySelectionReader(),
            pasteboard: pasteboard,
            fallback: CopyFallbackService(pasteboard: pasteboard),
            presenter: toast
        )
    }

    func start() {
        guard !self.started else { return }
        self.started = true
        guard self.permission.isTrusted else { return }
        try? self.monitor.start { [weak self] gesture in
            self?.copyCoordinator.handle(gesture)
        }
    }

    func shutdown() {
        self.monitor.stop()
        self.copyCoordinator.cancelPendingCopy()
        self.started = false
    }

    func refreshPermission() {
        self.permission.refresh()
        if self.permission.isTrusted {
            self.start()
        } else {
            self.monitor.stop(); self.copyCoordinator.cancelPendingCopy()
        }
    }
}
