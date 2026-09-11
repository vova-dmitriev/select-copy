import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let storageKey = "settings.v1"

    @Published var settings: AppSettings {
        didSet { save() }
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.storageKey),
           let decoded = try? decoder.decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = .default
        }
    }

    private func save() {
        guard let data = try? encoder.encode(settings) else {
            return
        }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
