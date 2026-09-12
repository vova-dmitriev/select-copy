import AppKit

enum ToastContent: Equatable {
    case text(String)
    case iconOnly
}

struct ToastScreen: Equatable {
    let frame: NSRect
    let visibleFrame: NSRect
}

@MainActor
protocol ToastScreenProviding: AnyObject {
    func screen(containing point: CGPoint) -> ToastScreen?
    var mainScreen: ToastScreen? { get }
}

@MainActor
protocol ToastPaneling: AnyObject {
    var contentSize: NSSize { get }
    func size(for content: ToastContent) -> NSSize
    func show(content: ToastContent, frame: NSRect)
    func hide()
}

extension ToastPaneling {
    func size(for _: ToastContent) -> NSSize {
        contentSize
    }
}

@MainActor
final class ToastCoordinator: CopyConfirmationPresenting {
    private let settings: SettingsStore
    private let localizer: Localizer
    private let panel: ToastPaneling
    private let screens: ToastScreenProviding
    private let scheduler: DelayScheduling
    private var dismissalTask: Task<Void, Never>?

    init(
        settings: SettingsStore,
        localizer: Localizer,
        panel: ToastPaneling,
        screens: ToastScreenProviding,
        scheduler: DelayScheduling = SystemDelayScheduler()
    ) {
        self.settings = settings
        self.localizer = localizer
        self.panel = panel
        self.screens = screens
        self.scheduler = scheduler
    }

    func showCopyConfirmation(at screenPoint: CGPoint?) {
        guard self.settings.settings.toastEnabled else {
            return
        }
        self.show(content: self.contentForCurrentSettings(), at: screenPoint)
    }

    func showPreview() {
        self.show(content: self.contentForCurrentSettings(), at: nil)
    }

    private func contentForCurrentSettings() -> ToastContent {
        switch self.settings.settings.toastContentMode {
        case .localizedText:
            return .text(self.localizer.text("toast.copied"))
        case .customText:
            let text = self.settings.settings.customToastText
            return text.isEmpty ? .iconOnly : .text(text)
        case .iconOnly:
            return .iconOnly
        }
    }

    private func show(content: ToastContent, at point: CGPoint?) {
        guard let screen = point.flatMap(screens.screen(containing:)) ?? screens.mainScreen else {
            return
        }

        let frame = self.settings.settings.toastPosition.frame(
            for: self.panel.size(for: content),
            in: screen.visibleFrame,
            inset: 20
        )
        self.dismissalTask?.cancel()
        self.panel.show(content: content, frame: frame)
        self.dismissalTask = Task { [weak self] in
            do {
                try await self?.scheduler.sleep(milliseconds: 1200)
            } catch {
                return
            }
            self?.panel.hide()
        }
    }
}
