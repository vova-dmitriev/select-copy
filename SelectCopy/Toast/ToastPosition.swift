import AppKit

enum ToastPosition: String, CaseIterable, Codable, Sendable, Identifiable {
    case topLeading
    case topCenter
    case topTrailing
    case bottomLeading
    case bottomCenter
    case bottomTrailing

    var id: String {
        rawValue
    }

    var label: String {
        rawValue
    }

    func frame(for size: NSSize, in visibleFrame: NSRect, inset: CGFloat) -> NSRect {
        let x: CGFloat = switch self {
        case .topLeading, .bottomLeading:
            visibleFrame.minX + inset
        case .topCenter, .bottomCenter:
            visibleFrame.midX - size.width / 2
        case .topTrailing, .bottomTrailing:
            visibleFrame.maxX - inset - size.width
        }

        let y: CGFloat = switch self {
        case .topLeading, .topCenter, .topTrailing:
            visibleFrame.maxY - inset - size.height
        case .bottomLeading, .bottomCenter, .bottomTrailing:
            visibleFrame.minY + inset
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
}
