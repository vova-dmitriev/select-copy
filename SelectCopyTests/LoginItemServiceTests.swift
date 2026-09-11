@testable import SelectCopy
import XCTest

@MainActor
final class LoginItemServiceTests: XCTestCase {
    func testEnableAndDisableRefreshActualState() throws {
        let client = LoginItemClientSpy(status: .notRegistered)
        let service = LoginItemService(client: client)

        try service.setEnabled(true)
        XCTAssertEqual(service.state, .enabled)
        XCTAssertEqual(client.registerCallCount, 1)

        try service.setEnabled(false)
        XCTAssertEqual(service.state, .disabled)
        XCTAssertEqual(client.unregisterCallCount, 1)
    }

    func testRequiresApprovalStateIsExposed() {
        let client = LoginItemClientSpy(status: .requiresApproval)
        let service = LoginItemService(client: client)

        XCTAssertEqual(service.state, .requiresApproval)
    }

    func testRegistrationFailureBecomesUnavailable() {
        let client = LoginItemClientSpy(status: .notRegistered, registerError: TestError.failed)
        let service = LoginItemService(client: client)

        XCTAssertThrowsError(try service.setEnabled(true))
        XCTAssertEqual(service.state, .unavailable(TestError.failed.localizedDescription))
    }
}

private enum TestError: LocalizedError {
    case failed
    var errorDescription: String? {
        "failed"
    }
}

@MainActor
private final class LoginItemClientSpy: LoginItemClient {
    var status: LoginItemSystemStatus
    let registerError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: LoginItemSystemStatus, registerError: Error? = nil) {
        self.status = status
        self.registerError = registerError
    }

    func register() throws {
        self.registerCallCount += 1
        if let registerError {
            throw registerError
        }
        self.status = .enabled
    }

    func unregister() throws {
        self.unregisterCallCount += 1
        self.status = .notRegistered
    }

    func openSettings() {}
}
