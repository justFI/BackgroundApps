import AppKit

let side = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("bitmap failed\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: side, height: side).fill()

let iconRect = NSRect(x: 64, y: 64, width: 896, height: 896)
let plate = NSBezierPath(roundedRect: iconRect, xRadius: 200, yRadius: 200)
plate.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.36, green: 0.62, blue: 0.98, alpha: 1),
    NSColor(srgbRed: 0.18, green: 0.36, blue: 0.86, alpha: 1),
])!
gradient.draw(in: iconRect, angle: 90)

func card(_ rect: NSRect, alpha: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(alpha).setFill()
    path.fill()
    NSColor(srgbRed: 0.22, green: 0.45, blue: 0.92, alpha: 0.95).setFill()
    NSBezierPath(roundedRect: NSRect(x: rect.minX + 28, y: rect.midY - 10, width: 92, height: 20), xRadius: 8, yRadius: 8).fill()
    NSColor(srgbRed: 0.75, green: 0.82, blue: 0.92, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: rect.minX + 140, y: rect.midY - 8, width: rect.width - 190, height: 16), xRadius: 8, yRadius: 8).fill()
}

card(NSRect(x: 250, y: 250, width: 620, height: 150), alpha: 0.78)
card(NSRect(x: 210, y: 430, width: 660, height: 156), alpha: 0.9)
card(NSRect(x: 170, y: 616, width: 700, height: 162), alpha: 1)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("png failed\n", stderr)
    exit(1)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: url)
