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
    private var monitorStarted = false
    private var permissionObservation: AnyCancellable?
    private var permissionRefreshTask: Task<Void, Never>?

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
        self.permissionObservation = permission.$isTrusted.dropFirst().sink { [weak self] trusted in
            self?.synchronizeMonitor(trusted: trusted)
        }
    }

    func start() {
        guard !self.started else { return }
        self.started = true
        if !self.permission.isTrusted {
            self.permission.requestAccess()
        }
        self.synchronizeMonitor(trusted: self.permission.isTrusted)
        self.permissionRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                guard let self, self.started else { return }
                self.refreshPermission()
            }
        }
    }

    func shutdown() {
        self.monitor.stop()
        self.copyCoordinator.cancelPendingCopy()
        self.permissionRefreshTask?.cancel()
        self.permissionRefreshTask = nil
        self.monitorStarted = false
        self.started = false
    }

    func refreshPermission() {
        self.permission.refresh()
        self.synchronizeMonitor(trusted: self.permission.isTrusted)
    }

    private func synchronizeMonitor(trusted: Bool) {
        guard self.started else { return }
        if trusted {
            guard !self.monitorStarted else { return }
            do {
                try self.monitor.start { [weak self] gesture in
                    self?.copyCoordinator.handle(gesture)
                }
                self.monitorStarted = true
            } catch {
                self.monitorStarted = false
            }
        } else if self.monitorStarted {
            self.monitor.stop()
            self.copyCoordinator.cancelPendingCopy()
            self.monitorStarted = false
        }
    }
}
