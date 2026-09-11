import XCTest

final class SmokeUITests: XCTestCase {
    @MainActor
    func testMenuBarAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-permission-state", "trusted"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        app.terminate()
    }
}
