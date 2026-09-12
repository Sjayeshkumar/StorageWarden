import AppKit

// Original vector artwork. Render each size directly for a crisp native macOS icon.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/StorageWarden.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let green = NSColor(srgbRed: 0.07, green: 0.23, blue: 0.18, alpha: 1)
let mint = NSColor(srgbRed: 0.70, green: 0.82, blue: 0.62, alpha: 1)
let gold = NSColor(srgbRed: 0.91, green: 0.65, blue: 0.25, alpha: 1)
func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let transform = NSAffineTransform()
    transform.scale(by: CGFloat(pixels) / 1024)
    transform.concat()
    let tile = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 195, yRadius: 195)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.set()
    green.setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.38, blue: 0.28, alpha: 1), ending: green)!.draw(in: tile, angle: -65)
    for (start, end, color) in [(12.0, 109.0, mint), (121.0, 240.0, NSColor.white.withAlphaComponent(0.90)), (252.0, 360.0, gold)] {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 305, startAngle: start, endAngle: end)
        arc.lineWidth = 61; arc.lineCapStyle = .butt; color.setStroke(); arc.stroke()
    }
    let shield = NSBezierPath()
    shield.move(to: NSPoint(x: 512, y: 732))
    shield.line(to: NSPoint(x: 690, y: 663))
    shield.line(to: NSPoint(x: 684, y: 490))
    shield.curve(to: NSPoint(x: 512, y: 300), controlPoint1: NSPoint(x: 680, y: 401), controlPoint2: NSPoint(x: 590, y: 330))
    shield.curve(to: NSPoint(x: 340, y: 490), controlPoint1: NSPoint(x: 434, y: 330), controlPoint2: NSPoint(x: 344, y: 401))
    shield.line(to: NSPoint(x: 334, y: 663)); shield.close()
    NSColor(srgbRed: 0.96, green: 0.95, blue: 0.86, alpha: 1).setFill(); shield.fill()
    NSGraphicsContext.saveGraphicsState(); shield.addClip()
    mint.setFill(); NSRect(x: 512, y: 290, width: 200, height: 450).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try render(points * scale).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
try render(1024).write(to: root.appendingPathComponent("docs/images/storagewarden-icon.png"))
