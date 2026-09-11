import Combine
import Foundation

@MainActor
final class Localizer: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            localeIdentifier = language.localeIdentifier(system: systemLocaleIdentifier)
        }
    }
    @Published private(set) var localeIdentifier: String

    private let systemLocaleIdentifier: String

    private static let translations: [String: [String: String]] = [
        "toast.copied": ["en": "Copied", "ru": "Скопировано"],
        "menu.status.active": ["en": "Active", "ru": "Работает"],
        "menu.settings": ["en": "Settings", "ru": "Настройки"],
        "menu.testToast": ["en": "Show test toast", "ru": "Показать тестовое уведомление"],
        "menu.quit": ["en": "Quit", "ru": "Выйти"],
        "permission.missing": ["en": "Accessibility permission is required", "ru": "Нужно разрешение Accessibility"],
        "permission.openSettings": ["en": "Open System Settings", "ru": "Открыть Системные настройки"],
    ]

    init(language: AppLanguage, systemLocaleIdentifier: String = Locale.current.identifier) {
        self.language = language
        self.systemLocaleIdentifier = systemLocaleIdentifier
        localeIdentifier = language.localeIdentifier(system: systemLocaleIdentifier)
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    func text(_ key: String) -> String {
        let languageCode = localeIdentifier.lowercased().hasPrefix("ru") ? "ru" : "en"
        return Self.translations[key]?[languageCode] ?? key
    }
}
