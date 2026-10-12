// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

// Renders the DMG window background (660×400 pt @2x): `swift scripts/make_dmg_background.swift out.png`
import AppKit

let scale: CGFloat = 2
let size = CGSize(width: 660, height: 400)
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "bg.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = size // 144 dpi
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bounds = CGRect(origin: .zero, size: size)

// Soft light gradient echoing the icon colors.
NSGradient(colors: [
    NSColor(srgbRed: 0.97, green: 0.96, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 1.00, green: 0.95, blue: 0.97, alpha: 1),
])!.draw(in: bounds, angle: -30)

// Glows behind the two icon slots (Finder positions: app at x=165, Applications at x=495, y=190 from top).
for (x, color) in [(165.0, NSColor(srgbRed: 0.45, green: 0.36, blue: 1.0, alpha: 0.16)),
                   (495.0, NSColor(srgbRed: 1.0, green: 0.33, blue: 0.56, alpha: 0.12))] {
    let center = CGPoint(x: x, y: size.height - 190)
    NSGradient(colors: [color, color.withAlphaComponent(0)])!
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: 120, options: [])
}

// Arrow between the slots.
let arrow = NSBezierPath()
let y = size.height - 185
arrow.move(to: CGPoint(x: 268, y: y))
arrow.curve(to: CGPoint(x: 392, y: y), controlPoint1: CGPoint(x: 305, y: y + 26), controlPoint2: CGPoint(x: 355, y: y + 26))
arrow.lineWidth = 5
arrow.lineCapStyle = .round
NSColor(srgbRed: 0.55, green: 0.45, blue: 0.95, alpha: 0.55).setStroke()
arrow.stroke()
let head = NSBezierPath()
head.move(to: CGPoint(x: 378, y: y + 14))
head.line(to: CGPoint(x: 394, y: y - 1))
head.line(to: CGPoint(x: 374, y: y - 6))
head.lineWidth = 5
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
