// Eye-in-frame menu bar variants: `swift scripts/eye_concepts.swift <out.png>`
import AppKit

typealias Glyph = (CGContext) -> Void

func corners(_ c: CGContext, inset: CGFloat = 1.4, arm: CGFloat = 4.2, width: CGFloat = 1.7) {
    let a = inset, b = 18 - inset
    for (x, y, dx, dy) in [(a, b, 1.0, -1.0), (b, b, -1.0, -1.0), (b, a, -1.0, 1.0), (a, a, 1.0, 1.0)] {
        c.move(to: CGPoint(x: x, y: y + dy * arm)); c.addLine(to: CGPoint(x: x, y: y)); c.addLine(to: CGPoint(x: x + dx * arm, y: y))
    }
    c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round); c.strokePath()
}
func cut(_ c: CGContext, _ body: () -> Void) { c.saveGState(); c.setBlendMode(.clear); body(); c.restoreGState() }

func almond(_ l: CGFloat, _ r: CGFloat, _ cy: CGFloat, up: CGFloat, down: CGFloat) -> CGPath {
    let p = CGMutablePath(), mx = (l + r) / 2
    p.move(to: CGPoint(x: l, y: cy))
    p.addQuadCurve(to: CGPoint(x: r, y: cy), control: CGPoint(x: mx, y: cy + up))
    p.addQuadCurve(to: CGPoint(x: l, y: cy), control: CGPoint(x: mx, y: cy - down))
    return p
}

let variants: [(String, Glyph)] = [
    ("1 · Outline", { c in
        corners(c)
        c.addPath(almond(4.4, 13.6, 9, up: 5.2, down: 5.2)); c.setLineWidth(1.5); c.setLineJoin(.round); c.strokePath()
        c.fillEllipse(in: CGRect(x: 7.1, y: 7.1, width: 3.8, height: 3.8))
    }),
    ("2 · Solid + glint", { c in
        corners(c)
        c.addPath(almond(3.8, 14.2, 9, up: 5.8, down: 5.8)); c.fillPath()
        cut(c) { c.fillEllipse(in: CGRect(x: 6.6, y: 6.6, width: 4.8, height: 4.8)) }
        c.fillEllipse(in: CGRect(x: 7.8, y: 7.8, width: 2.4, height: 2.4))
        cut(c) { c.fillEllipse(in: CGRect(x: 9.3, y: 9.5, width: 1.1, height: 1.1)) }
    }),
    ("3 · Iris ring", { c in
        corners(c, arm: 3.8)
        c.addPath(almond(3.6, 14.4, 9, up: 6.0, down: 6.0)); c.setLineWidth(1.4); c.setLineJoin(.round); c.strokePath()
        c.setLineWidth(1.3); c.strokeEllipse(in: CGRect(x: 6.3, y: 6.3, width: 5.4, height: 5.4))
        c.fillEllipse(in: CGRect(x: 7.9, y: 7.9, width: 2.2, height: 2.2))
    }),
    ("4 · Peek (half-lid)", { c in
        corners(c)
        // Upper lid as a strong arc, lower lid lighter: a curious, half-open look.
        let lid = CGMutablePath()
        lid.move(to: CGPoint(x: 4.0, y: 9.4)); lid.addQuadCurve(to: CGPoint(x: 14.0, y: 9.4), control: CGPoint(x: 9, y: 14.6))
        c.addPath(lid); c.setLineWidth(1.7); c.setLineCap(.round); c.strokePath()
        let low = CGMutablePath()
        low.move(to: CGPoint(x: 5.6, y: 8.2)); low.addQuadCurve(to: CGPoint(x: 12.4, y: 8.2), control: CGPoint(x: 9, y: 4.6))
        c.addPath(low); c.setLineWidth(1.2); c.strokePath()
        c.fillEllipse(in: CGRect(x: 7.0, y: 6.6, width: 4.0, height: 4.0))
        cut(c) { c.fillEllipse(in: CGRect(x: 9.2, y: 8.7, width: 1.1, height: 1.1)) }
    }),
    ("5 · Wide frame", { c in
        // Eye fills the frame; corners become lashes of the viewfinder.
        corners(c, inset: 1.2, arm: 3.4, width: 1.6)
        c.addPath(almond(2.6, 15.4, 9, up: 7.4, down: 7.4)); c.setLineWidth(1.5); c.setLineJoin(.round); c.strokePath()
        c.fillEllipse(in: CGRect(x: 6.6, y: 6.6, width: 4.8, height: 4.8))
        cut(c) { c.fillEllipse(in: CGRect(x: 9.3, y: 9.4, width: 1.2, height: 1.2)) }
    }),
]

func render(_ g: Glyph, px: Int, color: CGColor) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.scaleBy(x: CGFloat(px) / 18, y: CGFloat(px) / 18)
    c.setFillColor(color); c.setStrokeColor(color)
    g(c)
    return c.makeImage()!
}

let big = 150, cellW = 230, pad = 30
let W = variants.count * cellW + pad, H = 420
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let sheet = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(CGColor(gray: 0.12, alpha: 1)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
sheet.setFillColor(CGColor(gray: 0.02, alpha: 1)); sheet.fill(CGRect(x: 0, y: H - 50, width: W, height: 50))
sheet.setFillColor(CGColor(gray: 0.93, alpha: 1)); sheet.fill(CGRect(x: 0, y: H - 100, width: W, height: 50))
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
for (i, (name, g)) in variants.enumerated() {
    let cx = pad + i * cellW + (cellW - pad) / 2
    sheet.draw(render(g, px: 36, color: CGColor(gray: 1, alpha: 1)), in: CGRect(x: cx - 18, y: H - 43, width: 36, height: 36))
    sheet.draw(render(g, px: 36, color: CGColor(gray: 0, alpha: 0.85)), in: CGRect(x: cx - 18, y: H - 93, width: 36, height: 36))
    sheet.draw(render(g, px: big, color: CGColor(gray: 1, alpha: 1)), in: CGRect(x: cx - big / 2, y: 80, width: big, height: big))
    let label = NSAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .semibold),
                                                              .foregroundColor: NSColor.white])
    label.draw(at: CGPoint(x: CGFloat(cx) - label.size().width / 2, y: 30))
}
NSGraphicsContext.restoreGraphicsState()
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "eyes.png"
try! NSBitmapImageRep(cgImage: sheet.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
