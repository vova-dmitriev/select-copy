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
        switch self.service.status {
        case .enabled: return .enabled
        case .notRegistered: return .notRegistered
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .notFound
        }
    }

    func register() throws {
        try self.service.register()
    }

    func unregister() throws {
        try self.service.unregister()
    }

    func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var state: LoginItemState
    private let client: LoginItemClient

    init(client: LoginItemClient = SystemLoginItemClient()) {
        self.client = client
        self.state = Self.map(client.status)
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                try self.client.register()
            } else {
                try self.client.unregister()
            }
            self.state = Self.map(self.client.status)
        } catch {
            self.state = .unavailable(error.localizedDescription)
            throw error
        }
    }

    func openSystemSettings() {
        self.client.openSettings()
    }

    private static func map(_ status: LoginItemSystemStatus) -> LoginItemState {
        switch status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable("Login item is not available")
        }
    }
}
