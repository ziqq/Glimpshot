// Renders the 1024×1024 app icon (Liquid Glass style): `swift scripts/make_icon.swift out.png`
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func linear(_ colors: [CGColor], _ locations: [CGFloat]? = nil, from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func radial(_ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// Squircle body on the macOS icon grid.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.32))
ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
ctx.restoreGState()

// Background: deep indigo → violet → pink, with a soft light bloom top-left.
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
linear([rgb(0x4B3BFF), rgb(0x9A3CF4), rgb(0xFF4F8B)], [0, 0.55, 1],
       from: CGPoint(x: 120, y: 940), to: CGPoint(x: 920, y: 90))
radial([rgb(0xFFFFFF, 0.38), rgb(0xFFFFFF, 0)], center: CGPoint(x: 300, y: 830), radius: 560)
radial([rgb(0x2A0D6E, 0.35), rgb(0x2A0D6E, 0)], center: CGPoint(x: 860, y: 140), radius: 520)
// Rim light on the tile edge.
ctx.addPath(bodyPath.copy(strokingWithWidth: 10, lineCap: .round, lineJoin: .round, miterLimit: 10))
ctx.clip()
linear([rgb(0xFFFFFF, 0.55), rgb(0xFFFFFF, 0.0), rgb(0xFFFFFF, 0.18)], [0, 0.5, 1],
       from: CGPoint(x: 100, y: 924), to: CGPoint(x: 924, y: 100))
ctx.restoreGState()

// Glass plate.
let plate = CGRect(x: 238, y: 238, width: 548, height: 548)
let platePath = CGPath(roundedRect: plate, cornerWidth: 140, cornerHeight: 140, transform: nil)

ctx.saveGState() // plate shadow
ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 48, color: rgb(0x22074F, 0.5))
ctx.addPath(platePath); ctx.setFillColor(rgb(0xFFFFFF, 0.16)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState() // frosted body: brighter at the top, a hint of refraction at the bottom
ctx.addPath(platePath); ctx.clip()
linear([rgb(0xFFFFFF, 0.34), rgb(0xFFFFFF, 0.08), rgb(0xFFFFFF, 0.16)], [0, 0.55, 1],
       from: CGPoint(x: 0, y: plate.maxY), to: CGPoint(x: 0, y: plate.minY))
radial([rgb(0xFFFFFF, 0.28), rgb(0xFFFFFF, 0)], center: CGPoint(x: plate.minX + 120, y: plate.maxY - 90), radius: 300)
ctx.restoreGState()

ctx.saveGState() // specular rim: bright top-left, fading, faint bottom-right
ctx.addPath(platePath.copy(strokingWithWidth: 7, lineCap: .round, lineJoin: .round, miterLimit: 10))
ctx.clip()
linear([rgb(0xFFFFFF, 0.95), rgb(0xFFFFFF, 0.15), rgb(0xFFFFFF, 0.5)], [0, 0.55, 1],
       from: CGPoint(x: plate.minX, y: plate.maxY), to: CGPoint(x: plate.maxX, y: plate.minY))
ctx.restoreGState()

// Glyph: viewfinder corners + shutter dot, white with a soft drop and a faint glow.
let f = plate.insetBy(dx: 100, dy: 100)
let arm: CGFloat = 92
let glyph = CGMutablePath()
for (x, y, dx, dy) in [(f.minX, f.maxY, 1.0, -1.0), (f.maxX, f.maxY, -1.0, -1.0),
                       (f.maxX, f.minY, -1.0, 1.0), (f.minX, f.minY, 1.0, 1.0)] {
    glyph.move(to: CGPoint(x: x, y: y + dy * arm))
    glyph.addLine(to: CGPoint(x: x, y: y))
    glyph.addLine(to: CGPoint(x: x + dx * arm, y: y))
}
let glyphShape = CGMutablePath()
glyphShape.addPath(glyph.copy(strokingWithWidth: 46, lineCap: .round, lineJoin: .round, miterLimit: 10))
glyphShape.addEllipse(in: CGRect(x: S / 2 - 52, y: S / 2 - 52, width: 104, height: 104))

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 26, color: rgb(0xFFFFFF, 0.45))
ctx.addPath(glyphShape); ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: rgb(0x2A0A5E, 0.35))
ctx.addPath(glyphShape); ctx.clip()
linear([rgb(0xFFFFFF), rgb(0xF1EBFF)], from: CGPoint(x: 0, y: f.maxY), to: CGPoint(x: 0, y: f.minY))
ctx.restoreGState()

try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: out))
