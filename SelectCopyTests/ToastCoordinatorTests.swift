import AppKit
@testable import SelectCopy
import XCTest

@MainActor
final class ToastCoordinatorTests: XCTestCase {
    func testUsesScreenContainingSelectionPointAndConfiguredPosition() throws {
        let settings = try SettingsStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        settings.settings.toastPosition = .bottomCenter
        let panel = ToastPanelSpy(contentSize: NSSize(width: 200, height: 40))
        let screen = ToastScreen(
            frame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            visibleFrame: NSRect(x: 0, y: 20, width: 1000, height: 760)
        )
        let coordinator = ToastCoordinator(
            settings: settings,
            localizer: Localizer(language: .english),
            panel: panel,
            screens: ToastScreensSpy(screens: [screen]),
            scheduler: NeverFinishingDelayScheduler()
        )

        coordinator.showCopyConfirmation(at: CGPoint(x: 500, y: 400))

        XCTAssertEqual(panel.lastFrame, NSRect(x: 400, y: 40, width: 200, height: 40))
    }

    func testDisabledToastDoesNotShowPanel() throws {
        let settings = try SettingsStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        settings.settings.toastEnabled = false
        let panel = ToastPanelSpy(contentSize: NSSize(width: 200, height: 40))
        let coordinator = ToastCoordinator(
            settings: settings,
            localizer: Localizer(language: .english),
            panel: panel,
            screens: ToastScreensSpy(screens: []),
            scheduler: NeverFinishingDelayScheduler()
        )

        coordinator.showCopyConfirmation(at: nil)

        XCTAssertEqual(panel.showCount, 0)
    }

    func testEmptyCustomTextUsesIconOnlyContent() throws {
        let settings = try SettingsStore(userDefaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString)))
        settings.settings.toastContentMode = .customText
        settings.settings.customToastText = ""
        let panel = ToastPanelSpy(contentSize: NSSize(width: 40, height: 40))
        let screen = ToastScreen(
            frame: NSRect(x: 0, y: 0, width: 500, height: 500),
            visibleFrame: NSRect(x: 0, y: 0, width: 500, height: 500)
        )
        let coordinator = ToastCoordinator(
            settings: settings,
            localizer: Localizer(language: .english),
            panel: panel,
            screens: ToastScreensSpy(screens: [screen]),
            scheduler: NeverFinishingDelayScheduler()
        )

        coordinator.showCopyConfirmation(at: nil)

        XCTAssertEqual(panel.contents, [.iconOnly])
    }
}

@MainActor
private final class ToastPanelSpy: ToastPaneling {
    let contentSize: NSSize
    private(set) var lastFrame: NSRect?
    private(set) var contents: [ToastContent] = []
    private(set) var showCount = 0

    init(contentSize: NSSize) {
        self.contentSize = contentSize
    }

    func show(content: ToastContent, frame: NSRect) {
        self.contents.append(content)
        self.lastFrame = frame
        self.showCount += 1
    }

    func hide() {}
}

@MainActor
private final class ToastScreensSpy: ToastScreenProviding {
    let screens: [ToastScreen]
    init(screens: [ToastScreen]) {
        self.screens = screens
    }

    func screen(containing point: CGPoint) -> ToastScreen? {
        self.screens.first { $0.frame.contains(point) }
    }

    var mainScreen: ToastScreen? {
        self.screens.first
    }
}

@MainActor
private final class NeverFinishingDelayScheduler: DelayScheduling {
    func sleep(milliseconds _: UInt64) async throws {
        try await Task.sleep(nanoseconds: 10_000_000_000)
    }
}
