import XCTest
@testable import SelectCopy

final class SmokeTests: XCTestCase {
    func testProductNameIsStable() {
        XCTAssertEqual(ProductIdentity.name, "SelectCopy")
        XCTAssertEqual(ProductIdentity.bundleIdentifier, "com.selectcopy.app")
    }
}
