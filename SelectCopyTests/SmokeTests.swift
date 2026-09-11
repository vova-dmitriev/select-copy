@testable import SelectCopy
import XCTest

final class SmokeTests: XCTestCase {
    func testProductNameIsStable() {
        XCTAssertEqual(ProductIdentity.name, "SelectCopy")
        XCTAssertEqual(ProductIdentity.bundleIdentifier, "com.selectcopy.app")
    }
}
