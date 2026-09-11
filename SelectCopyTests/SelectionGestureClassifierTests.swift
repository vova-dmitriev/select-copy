import CoreGraphics
@testable import SelectCopy
import XCTest

final class SelectionGestureClassifierTests: XCTestCase {
    func testSingleClickBelowDragThresholdDoesNotProduceGesture() {
        var classifier = SelectionGestureClassifier(dragThreshold: 3)

        _ = classifier.consume(self.mouseDown(at: .zero))
        let gesture = classifier.consume(self.mouseUp(at: CGPoint(x: 2, y: 0)))

        XCTAssertNil(gesture)
    }

    func testMovementAtDragThresholdProducesDragAtReleasePoint() {
        var classifier = SelectionGestureClassifier(dragThreshold: 3)
        let releasePoint = CGPoint(x: 3, y: 0)

        _ = classifier.consume(self.mouseDown(at: .zero))
        let gesture = classifier.consume(self.mouseUp(at: releasePoint))

        XCTAssertEqual(gesture, SelectionGesture(kind: .drag, screenPoint: releasePoint))
    }

    func testDoubleAndTripleClickProduceMultiClickGesture() {
        for clickCount: Int64 in [2, 3] {
            var classifier = SelectionGestureClassifier()
            let point = CGPoint(x: 40, y: 50)

            _ = classifier.consume(self.mouseDown(at: point, clickCount: clickCount))
            let gesture = classifier.consume(self.mouseUp(at: point, clickCount: clickCount))

            XCTAssertEqual(gesture, SelectionGesture(kind: .multiClick, screenPoint: point))
        }
    }

    func testShiftNavigationKeysProduceKeyboardSelection() {
        let supportedKeyCodes: [CGKeyCode] = [123, 124, 125, 126, 115, 119, 116, 121]

        for keyCode in supportedKeyCodes {
            var classifier = SelectionGestureClassifier()
            let gesture = classifier.consume(self.keyUp(keyCode: keyCode, flags: [.maskShift, .maskAlternate]))

            XCTAssertEqual(gesture, SelectionGesture(kind: .keyboard, screenPoint: nil))
        }
    }

    func testCommandAProducesSelectAllGesture() {
        var classifier = SelectionGestureClassifier()

        let gesture = classifier.consume(self.keyUp(keyCode: 0, flags: [.maskCommand]))

        XCTAssertEqual(gesture, SelectionGesture(kind: .selectAll, screenPoint: nil))
    }

    func testKeysWithoutSelectionIntentDoNotProduceGesture() {
        let events = [
            keyUp(keyCode: 0, flags: []),
            keyUp(keyCode: 51, flags: [.maskShift]),
            keyUp(keyCode: 123, flags: []),
        ]

        for event in events {
            var classifier = SelectionGestureClassifier()
            XCTAssertNil(classifier.consume(event))
        }
    }

    func testSyntheticEventsAreIgnoredWithoutChangingMouseState() {
        var classifier = SelectionGestureClassifier(dragThreshold: 3)
        let syntheticDown = InputEvent(
            kind: .mouseDown,
            location: .zero,
            sourceUserData: InputEvent.syntheticSourceMarker
        )

        XCTAssertNil(classifier.consume(syntheticDown))
        XCTAssertNil(classifier.consume(self.mouseUp(at: CGPoint(x: 20, y: 0))))
    }

    private func mouseDown(at point: CGPoint, clickCount: Int64 = 1) -> InputEvent {
        InputEvent(kind: .mouseDown, location: point, clickCount: clickCount)
    }

    private func mouseUp(at point: CGPoint, clickCount: Int64 = 1) -> InputEvent {
        InputEvent(kind: .mouseUp, location: point, clickCount: clickCount)
    }

    private func keyUp(keyCode: CGKeyCode, flags: CGEventFlags) -> InputEvent {
        InputEvent(kind: .keyUp, keyCode: keyCode, flags: flags)
    }
}
