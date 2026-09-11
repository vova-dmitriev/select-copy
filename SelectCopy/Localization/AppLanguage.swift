import Foundation

enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system
    case russian
    case english

    func localeIdentifier(system: String) -> String {
        switch self {
        case .system:
            system
        case .russian:
            "ru"
        case .english:
            "en"
        }
    }
}
