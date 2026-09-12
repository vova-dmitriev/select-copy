import Combine
import Foundation

@MainActor
final class Localizer: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            self.localeIdentifier = self.language.localeIdentifier(system: self.systemLocaleIdentifier)
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
        "settings.toastEnabled": ["en": "Show copy notification", "ru": "Показывать уведомление о копировании"],
        "settings.toastPosition": ["en": "Toast position", "ru": "Положение уведомления"],
        "settings.choosePosition": ["en": "Choose toast position", "ru": "Где показывать уведомление"],
        "toast.position.topLeading": ["en": "Top left", "ru": "Слева сверху"],
        "toast.position.topCenter": ["en": "Top center", "ru": "По центру сверху"],
        "toast.position.topTrailing": ["en": "Top right", "ru": "Справа сверху"],
        "toast.position.bottomLeading": ["en": "Bottom left", "ru": "Слева снизу"],
        "toast.position.bottomCenter": ["en": "Bottom center", "ru": "По центру снизу"],
        "toast.position.bottomTrailing": ["en": "Bottom right", "ru": "Справа снизу"],
        "settings.toastContent": ["en": "Toast content", "ru": "Содержимое уведомления"],
        "settings.localizedText": ["en": "Localized text", "ru": "Переводимый текст"],
        "settings.customText": ["en": "Custom text", "ru": "Свой текст"],
        "settings.iconOnly": ["en": "Icon only", "ru": "Только иконка"],
        "settings.language": ["en": "Language", "ru": "Язык"],
        "settings.launchAtLogin": ["en": "Launch at login", "ru": "Запускать при входе"],
    ]

    init(language: AppLanguage, systemLocaleIdentifier: String = Locale.current.identifier) {
        self.language = language
        self.systemLocaleIdentifier = systemLocaleIdentifier
        self.localeIdentifier = language.localeIdentifier(system: systemLocaleIdentifier)
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
    }

    func text(_ key: String) -> String {
        let languageCode = self.localeIdentifier.lowercased().hasPrefix("ru") ? "ru" : "en"
        return Self.translations[key]?[languageCode] ?? key
    }
}
