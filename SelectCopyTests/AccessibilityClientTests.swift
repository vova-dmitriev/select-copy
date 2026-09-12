import ApplicationServices
@testable import SelectCopy
import XCTest

@MainActor
final class AccessibilityClientTests: XCTestCase {
    func testMouseSelectionInScrollAreaAllowsFallback() {
        for selectedText in [AXStringValue.error(.attributeUnsupported), .error(.noValue), .value("")] {
            let reader = self.makeReader(role: "AXScrollArea", selectedText: selectedText)
            XCTAssertEqual(reader.readSelection(at: CGPoint(x: 10, y: 20)), .unsupported(fallbackAllowed: true))
        }
    }

    func testMouseSelectionInGroupAllowsFallback() {
        let reader = self.makeReader(role: "AXGroup", selectedText: .error(.attributeUnsupported))
        XCTAssertEqual(reader.readSelection(at: CGPoint(x: 10, y: 20)), .unsupported(fallbackAllowed: true))
    }
    func testMouseSelectionReadsHitElementInsteadOfFocusedComposer() {
        let query = PointerSelectionQuery()
        let reader = AccessibilitySelectionReader(query: query)
        XCTAssertEqual(reader.readSelection(at: CGPoint(x: 10, y: 20)), .text("message selection"))
    }

    func testMouseTextSelectionWithMissingAXTextAllowsCommandCFallback() {
        let query = PointerSelectionQuery(pointerText: .error(.noValue))
        let reader = AccessibilitySelectionReader(query: query)
        XCTAssertEqual(reader.readSelection(at: CGPoint(x: 10, y: 20)), .unsupported(fallbackAllowed: true))
    }
    func testReturnsSelectedTextWithoutNormalizingWhitespace() {
        let reader = self.makeReader(role: "AXTextArea", selectedText: .value("  hello\n"))

        XCTAssertEqual(reader.readSelection(), .text("  hello\n"))
    }

    func testEmptySelectedTextIsNotCopied() {
        let reader = self.makeReader(role: "AXTextArea", selectedText: .value(""))

        XCTAssertEqual(reader.readSelection(), .empty)
    }

    func testSecureFieldIsRejectedBeforeReadingItsText() {
        let query = AccessibilityQuerySpy(
            result: .value(.init(role: "AXTextField", subrole: "AXSecureTextField", selectedText: .value("secret")))
        )
        let reader = AccessibilitySelectionReader(query: query)

        XCTAssertEqual(reader.readSelection(), .secure)
    }

    func testUnsupportedTextRolesAllowFallback() {
        for role in ["AXTextField", "AXTextArea", "AXStaticText", "AXWebArea", "AXDocument"] {
            let reader = self.makeReader(role: role, selectedText: .error(.attributeUnsupported))
            XCTAssertEqual(reader.readSelection(), .unsupported(fallbackAllowed: true))
        }
    }

    func testUnsupportedNonTextRoleRejectsFallback() {
        let reader = self.makeReader(role: "AXButton", selectedText: .error(.attributeUnsupported))

        XCTAssertEqual(reader.readSelection(), .unsupported(fallbackAllowed: false))
    }

    func testNoValueMeansNoSelection() {
        let reader = self.makeReader(role: "AXTextArea", selectedText: .error(.noValue))

        XCTAssertEqual(reader.readSelection(), .empty)
    }

    func testNotImplementedUsesRoleBasedFallbackDecision() {
        let textReader = self.makeReader(role: "AXWebArea", selectedText: .error(.notImplemented))
        let buttonReader = self.makeReader(role: "AXButton", selectedText: .error(.notImplemented))

        XCTAssertEqual(textReader.readSelection(), .unsupported(fallbackAllowed: true))
        XCTAssertEqual(buttonReader.readSelection(), .unsupported(fallbackAllowed: false))
    }

    func testFocusedElementFailureIsReturned() {
        let reader = AccessibilitySelectionReader(query: AccessibilityQuerySpy(result: .error(.cannotComplete)))

        XCTAssertEqual(reader.readSelection(), .failure(.cannotComplete))
    }

    private func makeReader(role: String, selectedText: AXStringValue) -> AccessibilitySelectionReader {
        AccessibilitySelectionReader(
            query: AccessibilityQuerySpy(
                result: .value(.init(role: role, subrole: nil, selectedText: selectedText))
            )
        )
    }
}

private struct PointerSelectionQuery: AccessibilityQuerying {
    var pointerText: AXStringValue = .value("message selection")

    func focusedElementSnapshot() -> AccessibilitySnapshotResult {
        .value(.init(role: "AXTextArea", subrole: nil, selectedText: .value("")))
    }

    func selectionElementSnapshot(at point: CGPoint) -> AccessibilitySnapshotResult {
        .value(.init(role: "AXStaticText", subrole: nil, selectedText: pointerText))
    }
}

private final class AccessibilityQuerySpy: AccessibilityQuerying {
    let result: AccessibilitySnapshotResult

    init(result: AccessibilitySnapshotResult) {
        self.result = result
    }

    func focusedElementSnapshot() -> AccessibilitySnapshotResult {
        self.result
    }
}
