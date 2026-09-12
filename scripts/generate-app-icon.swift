import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "SelectCopy/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon() {
    let tile = rounded(NSRect(x: 64, y: 64, width: 896, height: 896), radius: 196)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(calibratedRed: 0.08, green: 0.28, blue: 0.78, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(
        starting: NSColor(calibratedRed: 0.09, green: 0.32, blue: 0.83, alpha: 1),
        ending: NSColor(calibratedRed: 0.22, green: 0.64, blue: 1, alpha: 1)
    )!.draw(in: tile, angle: 90)
    NSColor.white.withAlphaComponent(0.2).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    let board = rounded(NSRect(x: 286, y: 218, width: 452, height: 594), radius: 54)
    NSGraphicsContext.saveGraphicsState()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor.white.setFill()
    board.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedRed: 0.12, green: 0.42, blue: 0.85, alpha: 1).setFill()
    rounded(NSRect(x: 398, y: 752, width: 228, height: 96), radius: 32).fill()
    NSColor.white.setFill()
    rounded(NSRect(x: 426, y: 776, width: 172, height: 44), radius: 16).fill()

    NSColor(calibratedRed: 0.7, green: 0.8, blue: 0.94, alpha: 1).setFill()
    for (y, width) in [(CGFloat(644), CGFloat(264)), (574, 226), (504, 178)] {
        rounded(NSRect(x: 348, y: y, width: width, height: 22), radius: 11).fill()
    }

    let badge = NSBezierPath(ovalIn: NSRect(x: 566, y: 142, width: 280, height: 280))
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: 551, y: 127, width: 310, height: 310)).fill()
    NSGradient(
        starting: NSColor(calibratedRed: 0.04, green: 0.65, blue: 0.39, alpha: 1),
        ending: NSColor(calibratedRed: 0.19, green: 0.85, blue: 0.52, alpha: 1)
    )!.draw(in: badge, angle: 90)
    let check = NSBezierPath()
    check.move(to: NSPoint(x: 635, y: 286))
    check.line(to: NSPoint(x: 689, y: 235))
    check.line(to: NSPoint(x: 778, y: 330))
    check.lineWidth = 30
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSColor.white.setStroke()
    check.stroke()
}

for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot allocate icon bitmap") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
    try png.write(to: URL(fileURLWithPath: output).appendingPathComponent("icon-\(pixels).png"))
}
