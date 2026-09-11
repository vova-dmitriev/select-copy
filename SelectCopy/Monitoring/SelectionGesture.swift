import CoreGraphics

struct SelectionGesture: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case drag
        case multiClick
        case keyboard
        case selectAll
    }

    let kind: Kind
    let screenPoint: CGPoint?
}
