import CoreGraphics
import XCTest
@testable import SelectCopy

@MainActor
final class SelectionMonitorTests: XCTestCase {
    func testStartIsIdempotent() throws {
        let eventTap = EventTapClientSpy()
        let monitor = SelectionMonitor(eventTap: eventTap)

        try monitor.start { _ in }
        try monitor.start { _ in }

        XCTAssertEqual(eventTap.installCallCount, 1)
        XCTAssertTrue(monitor.isRunning)
    }

    func testStopInvalidatesInstalledTap() throws {
        let eventTap = EventTapClientSpy()
        let monitor = SelectionMonitor(eventTap: eventTap)
        try monitor.start { _ in }

        monitor.stop()

        XCTAssertEqual(eventTap.invalidateCallCount, 1)
        XCTAssertFalse(monitor.isRunning)
    }

    func testNormalizedEventsProduceSelectionGesture() throws {
        let eventTap = EventTapClientSpy()
        let monitor = SelectionMonitor(eventTap: eventTap)
        var gestures: [SelectionGesture] = []
        try monitor.start { gestures.append($0) }

        eventTap.emit(.input(InputEvent(kind: .mouseDown, location: .zero, clickCount: 1)))
        eventTap.emit(.input(InputEvent(kind: .mouseUp, location: CGPoint(x: 5, y: 0), clickCount: 1)))

        XCTAssertEqual(gestures, [SelectionGesture(kind: .drag, screenPoint: CGPoint(x: 5, y: 0))])
    }

    func testDisabledTapIsReenabled() throws {
        let eventTap = EventTapClientSpy()
        let monitor = SelectionMonitor(eventTap: eventTap)
        try monitor.start { _ in }

        eventTap.isEnabled = false
        eventTap.emit(.disabledByTimeout)

        XCTAssertEqual(eventTap.setEnabledValues, [true])
        XCTAssertEqual(eventTap.installCallCount, 1)
        XCTAssertTrue(monitor.isRunning)
    }

    func testFailedReenableReinstallsTap() throws {
        let eventTap = EventTapClientSpy()
        eventTap.installResults = [true, true]
        eventTap.enableSucceeds = false
        let monitor = SelectionMonitor(eventTap: eventTap)
        try monitor.start { _ in }

        eventTap.isEnabled = false
        eventTap.emit(.disabledByUserInput)

        XCTAssertEqual(eventTap.setEnabledValues, [true])
        XCTAssertEqual(eventTap.invalidateCallCount, 1)
        XCTAssertEqual(eventTap.installCallCount, 2)
        XCTAssertTrue(monitor.isRunning)
    }

    func testUnavailableTapThrowsAndDoesNotRun() {
        let eventTap = EventTapClientSpy()
        eventTap.installResults = [false]
        let monitor = SelectionMonitor(eventTap: eventTap)

        XCTAssertThrowsError(try monitor.start { _ in }) { error in
            XCTAssertEqual(error as? SelectionMonitorError, .installationFailed)
        }
        XCTAssertFalse(monitor.isRunning)
    }
}
