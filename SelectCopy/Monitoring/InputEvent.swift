import CoreGraphics

struct InputEvent: Equatable, Sendable {
    static let syntheticSourceMarker: Int64 = 0x5343_4F50_59

    enum Kind: Equatable, Sendable {
        case mouseDown
        case mouseUp
        case keyUp
    }

    let kind: Kind
    var location: CGPoint = .zero
    var clickCount: Int64 = 0
    var keyCode: CGKeyCode = 0
    var flags: CGEventFlags = []
    var sourceUserData: Int64 = 0
}
