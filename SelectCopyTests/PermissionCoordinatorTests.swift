@testable import SelectCopy
import XCTest

@MainActor
final class PermissionCoordinatorTests: XCTestCase {
    func testRefreshPublishesCurrentTrustState() {
        let trust = AccessibilityTrustClientSpy(values: [true, false])
        let coordinator = PermissionCoordinator(trustClient: trust)

        XCTAssertTrue(coordinator.isTrusted)
        coordinator.refresh()

        XCTAssertFalse(coordinator.isTrusted)
        XCTAssertEqual(trust.promptValues, [false, false])
    }

    func testRequestUsesSystemPromptAndPublishesResult() {
        let trust = AccessibilityTrustClientSpy(values: [false, true])
        let coordinator = PermissionCoordinator(trustClient: trust)

        coordinator.requestAccess()

        XCTAssertTrue(coordinator.isTrusted)
        XCTAssertEqual(trust.promptValues, [false, true])
    }

    func testOpenSystemSettingsDelegatesToTrustClient() {
        let trust = AccessibilityTrustClientSpy(values: [false])
        let coordinator = PermissionCoordinator(trustClient: trust)

        coordinator.openSystemSettings()

        XCTAssertEqual(trust.openPrivacySettingsCallCount, 1)
    }
}
