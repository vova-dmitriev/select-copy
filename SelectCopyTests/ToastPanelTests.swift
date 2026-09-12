import AppKit
@testable import SelectCopy
import XCTest

@MainActor
final class ToastPanelTests: XCTestCase {
    func testToastWidthFitsTextInsteadOfReservingEmptySpace() {
        let panel = ToastPanel()
        let short = panel.size(for: .text("Copied"))
        let long = panel.size(for: .text("A longer confirmation"))
        XCTAssertLessThan(short.width, 120)
        XCTAssertGreaterThan(long.width, short.width)
        XCTAssertEqual(panel.size(for: .iconOnly), NSSize(width: 36, height: 36))
        XCTAssertLessThanOrEqual(panel.size(for: .text(String(repeating: "W", count: 100))).width, 360)
    }

    func testTextContentAlignsLeadingWhileIconOnlyRemainsCentered() {
        XCTAssertEqual(ToastContent.text("Copied").alignment, .leading)
        XCTAssertEqual(ToastContent.iconOnly.alignment, .center)
    }

    func testMaterialBackingIsClippedToRoundedToastBounds() throws {
        let panel = ToastPanel()
        defer { panel.hide() }
        panel.show(content: .text("Copied"), frame: NSRect(x: 100, y: 100, width: 140, height: 38))

        let view = try XCTUnwrap(panel.contentView)
        let layer = try XCTUnwrap(view.layer)
        XCTAssertTrue(layer.masksToBounds, "Native material backing must not extend into square corners")
        XCTAssertEqual(layer.cornerRadius, 11)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertTrue(panel.hasShadow)
    }
}
