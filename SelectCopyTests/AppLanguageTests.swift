import XCTest
@testable import SelectCopy

final class AppLanguageTests: XCTestCase {
    func testExplicitLanguagesResolveToStableIdentifiers() {
        XCTAssertEqual(AppLanguage.russian.localeIdentifier(system: "de-DE"), "ru")
        XCTAssertEqual(AppLanguage.english.localeIdentifier(system: "de-DE"), "en")
        XCTAssertEqual(AppLanguage.system.localeIdentifier(system: "de-DE"), "de-DE")
    }

    @MainActor
    func testRussianAndEnglishToastStringsResolveImmediately() {
        let localizer = Localizer(language: .russian, systemLocaleIdentifier: "en-US")
        XCTAssertEqual(localizer.text("toast.copied"), "Скопировано")

        localizer.language = .english
        XCTAssertEqual(localizer.text("toast.copied"), "Copied")
    }

    @MainActor
    func testUnsupportedSystemLanguageFallsBackToEnglish() {
        let localizer = Localizer(language: .system, systemLocaleIdentifier: "de-DE")

        XCTAssertEqual(localizer.text("toast.copied"), "Copied")
    }
}
