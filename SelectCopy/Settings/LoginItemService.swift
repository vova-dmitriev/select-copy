import Combine
import ServiceManagement

enum LoginItemSystemStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

enum LoginItemState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable(String)
}

@MainActor
protocol LoginItemClient: AnyObject {
    var status: LoginItemSystemStatus { get }
    func register() throws
    func unregister() throws
    func openSettings()
}

@MainActor
final class SystemLoginItemClient: LoginItemClient {
    private let service = SMAppService.mainApp

    var status: LoginItemSystemStatus {
        switch service.status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }
    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var state: LoginItemState
    private let client: LoginItemClient

    init(client: LoginItemClient = SystemLoginItemClient()) {
        self.client = client
        state = Self.map(client.status)
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled { try client.register() } else { try client.unregister() }
            state = Self.map(client.status)
        } catch {
            state = .unavailable(error.localizedDescription)
            throw error
        }
    }

    func openSystemSettings() { client.openSettings() }

    private static func map(_ status: LoginItemSystemStatus) -> LoginItemState {
        switch status {
        case .enabled: return .enabled
        case .notRegistered: return .disabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable("Login item is not available")
        }
    }
}
