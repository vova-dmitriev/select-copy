import CoreGraphics

struct SelectionGestureClassifier {
    private static let navigationKeyCodes: Set<CGKeyCode> = [
        115, 116, 119, 121, 123, 124, 125, 126,
    ]

    private let dragThreshold: CGFloat
    private var mouseDownLocation: CGPoint?

    init(dragThreshold: CGFloat = 3) {
        self.dragThreshold = dragThreshold
    }

    mutating func consume(_ event: InputEvent) -> SelectionGesture? {
        guard event.sourceUserData != InputEvent.syntheticSourceMarker else {
            return nil
        }

        switch event.kind {
        case .mouseDown:
            mouseDownLocation = event.location
            return nil
        case .mouseUp:
            return consumeMouseUp(event)
        case .keyUp:
            return consumeKeyUp(event)
        }
    }

    private mutating func consumeMouseUp(_ event: InputEvent) -> SelectionGesture? {
        defer { mouseDownLocation = nil }

        if event.clickCount == 2 || event.clickCount == 3 {
            return SelectionGesture(kind: .multiClick, screenPoint: event.location)
        }

        guard let mouseDownLocation else {
            return nil
        }

        let distance = hypot(event.location.x - mouseDownLocation.x, event.location.y - mouseDownLocation.y)
        guard distance >= dragThreshold else {
            return nil
        }

        return SelectionGesture(kind: .drag, screenPoint: event.location)
    }

    private func consumeKeyUp(_ event: InputEvent) -> SelectionGesture? {
        if event.keyCode == 0, event.flags.contains(.maskCommand) {
            return SelectionGesture(kind: .selectAll, screenPoint: nil)
        }

        guard event.flags.contains(.maskShift), Self.navigationKeyCodes.contains(event.keyCode) else {
            return nil
        }

        return SelectionGesture(kind: .keyboard, screenPoint: nil)
    }
}
