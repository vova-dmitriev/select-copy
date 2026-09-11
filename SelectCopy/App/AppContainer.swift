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
        guard !started else { return }
        started = true
        guard permission.isTrusted else { return }
        try? monitor.start { [weak self] gesture in
            self?.copyCoordinator.handle(gesture)
        }
    }

    func shutdown() {
        monitor.stop()
        copyCoordinator.cancelPendingCopy()
        started = false
    }

    func refreshPermission() {
        permission.refresh()
        if permission.isTrusted { start() } else { monitor.stop(); copyCoordinator.cancelPendingCopy() }
    }
}
