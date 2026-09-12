import AppKit
@testable import SelectCopy
import XCTest

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testOpeningSettingsUnhidesTheMenuBarApplication() async {
        NSApplication.shared.hide(nil)
        let controller = SettingsWindowController()
        controller.show(
            store: SettingsStore(),
            localizer: Localizer(language: .english),
            loginItem: LoginItemService(),
            preview: {}
        )
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertFalse(NSApplication.shared.isHidden)
        XCTAssertTrue(NSApplication.shared.isActive)
        NSApplication.shared.windows.filter { $0.title == "SelectCopy" }.forEach { $0.close() }
    }
}
