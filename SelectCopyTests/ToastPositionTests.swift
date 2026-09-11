import AppKit
@testable import SelectCopy
import XCTest

final class ToastPositionTests: XCTestCase {
    func testAllPositionsUseVisibleFrameInsets() {
        let frame = NSRect(x: 100, y: 200, width: 1000, height: 800)
        let size = NSSize(width: 200, height: 40)
        let expected: [ToastPosition: CGPoint] = [
            .topLeading: CGPoint(x: 120, y: 940),
            .topCenter: CGPoint(x: 500, y: 940),
            .topTrailing: CGPoint(x: 880, y: 940),
            .bottomLeading: CGPoint(x: 120, y: 220),
            .bottomCenter: CGPoint(x: 500, y: 220),
            .bottomTrailing: CGPoint(x: 880, y: 220),
        ]

        for position in ToastPosition.allCases {
            XCTAssertEqual(position.frame(for: size, in: frame, inset: 20).origin, expected[position])
        }
    }
}
