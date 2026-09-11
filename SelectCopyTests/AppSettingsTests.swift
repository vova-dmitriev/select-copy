@testable import SelectCopy
import XCTest

final class AppSettingsTests: XCTestCase {
    func testDefaultsMatchSpecification() {
        XCTAssertFalse(AppSettings.default.launchAtLogin)
        XCTAssertTrue(AppSettings.default.toastEnabled)
        XCTAssertEqual(AppSettings.default.toastPosition, .topTrailing)
        XCTAssertEqual(AppSettings.default.toastContentMode, .localizedText)
        XCTAssertEqual(AppSettings.default.customToastText, "")
        XCTAssertEqual(AppSettings.default.language, .system)
    }

    func testCustomTextIsLimitedToSixtyCharacters() {
        var settings = AppSettings.default
        settings.setCustomToastText(String(repeating: "🟢", count: 61))

        XCTAssertEqual(settings.customToastText.count, 60)
    }
}
