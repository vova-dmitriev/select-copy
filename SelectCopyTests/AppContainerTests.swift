import CoreGraphics
@testable import SelectCopy
import XCTest

@MainActor
final class AppContainerTests: XCTestCase {
    func testDeniedLaunchRequestsPermissionAndGrantStartsMonitoringWithoutRestart() {
        let trust = AccessibilityTrustClientSpy(values: [false, false, true])
        let permission = PermissionCoordinator(trustClient: trust)
        let tap = EventTapClientSpy()
        let monitor = SelectionMonitor(eventTap: tap)
        let container = AppContainer(permission: permission, monitor: monitor)

        container.start()
        XCTAssertEqual(trust.promptValues, [false, true])
        XCTAssertFalse(monitor.isRunning)
        container.refreshPermission()
        XCTAssertTrue(monitor.isRunning)
        container.shutdown()
    }

    func testPermissionRevocationStopsMonitorAndRegrantRestartsIt() {
        let trust = AccessibilityTrustClientSpy(values: [true, false, true])
        let tap = EventTapClientSpy()
        tap.installResults = [true, true]
        let monitor = SelectionMonitor(eventTap: tap)
        let container = AppContainer(permission: PermissionCoordinator(trustClient: trust), monitor: monitor)
        container.start()
        XCTAssertTrue(monitor.isRunning)
        container.refreshPermission()
        XCTAssertFalse(monitor.isRunning)
        container.refreshPermission()
        XCTAssertTrue(monitor.isRunning)
        container.shutdown()
    }
}
