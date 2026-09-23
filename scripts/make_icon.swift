// Renders the 1024×1024 app icon: usage `swift scripts/make_icon.swift out.png`
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Squircle body on the macOS icon grid.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill()
bodyPath.fill()
ctx.restoreGState()

ctx.saveGState()
bodyPath.addClip()
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.36, green: 0.30, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.62, green: 0.28, blue: 0.98, alpha: 1),
    NSColor(srgbRed: 1.00, green: 0.33, blue: 0.56, alpha: 1),
])!
gradient.draw(in: body, angle: -50)

// Soft highlight at the top.
let glow = NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
glow.draw(in: CGRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
ctx.restoreGState()

// Viewfinder corners.
let frame = body.insetBy(dx: 200, dy: 200)
let arm: CGFloat = 130
let corners = NSBezierPath()
corners.lineWidth = 58
corners.lineCapStyle = .round
corners.lineJoinStyle = .round
for (x, y, dx, dy) in [(frame.minX, frame.minY, 1.0, 1.0), (frame.maxX, frame.minY, -1.0, 1.0),
                       (frame.minX, frame.maxY, 1.0, -1.0), (frame.maxX, frame.maxY, -1.0, -1.0)] {
    corners.move(to: CGPoint(x: x, y: y + dy * arm))
    corners.line(to: CGPoint(x: x, y: y))
    corners.line(to: CGPoint(x: x + dx * arm, y: y))
}
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor.white.setStroke()
corners.stroke()

// Shutter dot.
let dot = CGRect(x: body.midX - 70, y: body.midY - 70, width: 140, height: 140)
NSColor.white.setFill()
NSBezierPath(ovalIn: dot).fill()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
