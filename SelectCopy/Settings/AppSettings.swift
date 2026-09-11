import Foundation

enum ToastContentMode: String, CaseIterable, Codable, Sendable {
    case localizedText
    case customText
    case iconOnly
}

struct AppSettings: Equatable, Codable, Sendable {
    var launchAtLogin: Bool
    var toastEnabled: Bool
    var toastPosition: ToastPosition
    var toastContentMode: ToastContentMode
    var customToastText: String
    var language: AppLanguage

    static let `default` = AppSettings(
        launchAtLogin: false,
        toastEnabled: true,
        toastPosition: .topTrailing,
        toastContentMode: .localizedText,
        customToastText: "",
        language: .system
    )

    mutating func setCustomToastText(_ text: String) {
        self.customToastText = String(text.prefix(60))
    }
}
