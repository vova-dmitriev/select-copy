import AppKit
import XCTest
@testable import SelectCopy

@MainActor
final class PasteboardClientTests: XCTestCase {
    func testWriteTextReplacesPasteboardWithPlainText() {
        let board = NSPasteboard.withUniqueName()
        let client = PasteboardClient(pasteboard: board)

        XCTAssertTrue(client.writeText("hello"))

        XCTAssertEqual(board.string(forType: .string), "hello")
        XCTAssertEqual(board.pasteboardItems?.count, 1)
    }

    func testSnapshotRestorePreservesItemsAndReadableTypes() {
        let board = NSPasteboard.withUniqueName()
        let customType = NSPasteboard.PasteboardType("com.selectcopy.test")
        let first = NSPasteboardItem()
        first.setString("before", forType: .string)
        first.setData(Data([1, 2]), forType: customType)
        let second = NSPasteboardItem()
        second.setString("second", forType: .string)
        board.writeObjects([first, second])
        let client = PasteboardClient(pasteboard: board)
        let snapshot = client.snapshot()
        _ = client.writeText("changed")

        XCTAssertTrue(client.restore(snapshot))

        XCTAssertEqual(board.pasteboardItems?.count, 2)
        XCTAssertEqual(board.pasteboardItems?[0].string(forType: .string), "before")
        XCTAssertEqual(board.pasteboardItems?[0].data(forType: customType), Data([1, 2]))
        XCTAssertEqual(board.pasteboardItems?[1].string(forType: .string), "second")
    }
}
