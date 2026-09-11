import XCTest
@testable import SelectCopy

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testSettingsRoundTripThroughIsolatedDefaults() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = SettingsStore(userDefaults: defaults)
        var expected = AppSettings.default
        expected.launchAtLogin = true
        expected.toastEnabled = false
        expected.toastPosition = .bottomLeading
        expected.toastContentMode = .customText
        expected.customToastText = "Готово"
        expected.language = .russian

        store.settings = expected
        let reloaded = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(reloaded.settings, expected)
    }

    func testCorruptDataFallsBackToDefaults() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(Data([1, 2, 3]), forKey: SettingsStore.storageKey)

        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.settings, .default)
    }
}
