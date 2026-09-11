import AppKit

enum ToastPosition: String, CaseIterable, Codable, Sendable, Identifiable {
    case topLeading
    case topCenter
    case topTrailing
    case bottomLeading
    case bottomCenter
    case bottomTrailing

    var id: String { rawValue }
    var label: String { rawValue }

    func frame(for size: NSSize, in visibleFrame: NSRect, inset: CGFloat) -> NSRect {
        let x: CGFloat
        switch self {
        case .topLeading, .bottomLeading:
            x = visibleFrame.minX + inset
        case .topCenter, .bottomCenter:
            x = visibleFrame.midX - size.width / 2
        case .topTrailing, .bottomTrailing:
            x = visibleFrame.maxX - inset - size.width
        }

        let y: CGFloat
        switch self {
        case .topLeading, .topCenter, .topTrailing:
            y = visibleFrame.maxY - inset - size.height
        case .bottomLeading, .bottomCenter, .bottomTrailing:
            y = visibleFrame.minY + inset
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
}
