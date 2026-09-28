// Renders menu bar glyph options: `swift scripts/menubar_concepts.swift <out.png>`
// Each glyph is drawn in an 18×18 pt box (y up), as a template image would be.
import AppKit

typealias Glyph = (CGContext) -> Void

func corners(_ c: CGContext, inset: CGFloat = 1.4, arm: CGFloat = 4.2, width: CGFloat = 1.7) {
    let a = inset, b = 18 - inset
    for (x, y, dx, dy) in [(a, b, 1.0, -1.0), (b, b, -1.0, -1.0), (b, a, -1.0, 1.0), (a, a, 1.0, 1.0)] {
        c.move(to: CGPoint(x: x, y: y + dy * arm)); c.addLine(to: CGPoint(x: x, y: y)); c.addLine(to: CGPoint(x: x + dx * arm, y: y))
    }
    c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round); c.strokePath()
}

func cut(_ c: CGContext, _ draw: () -> Void) {
    c.saveGState(); c.setBlendMode(.clear); draw(); c.restoreGState()
}

let glyphs: [(String, Glyph)] = [
    ("Current", { c in
        let img = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(pointSize: 15, weight: .regular))!
        var r = CGRect(x: 0, y: 0, width: 18, height: 18)
        c.saveGState()
        c.clip(to: CGRect(x: 0.5, y: 1.5, width: 17, height: 15), mask: img.cgImage(forProposedRect: &r, context: nil, hints: nil)!)
        c.fill(CGRect(x: 0, y: 0, width: 18, height: 18))
        c.restoreGState()
    }),
    ("A · Feather", { c in
        // Quill feather sweeping up-right, with shaft and notches cut out.
        let f = CGMutablePath()
        f.move(to: CGPoint(x: 16.6, y: 17.2))
        f.addCurve(to: CGPoint(x: 4.2, y: 4.6), control1: CGPoint(x: 9.5, y: 16.8), control2: CGPoint(x: 4.0, y: 11.5))
        f.addCurve(to: CGPoint(x: 16.6, y: 17.2), control1: CGPoint(x: 10.5, y: 4.4), control2: CGPoint(x: 16.4, y: 9.5))
        c.addPath(f); c.fillPath()
        cut(c) {
            c.setLineCap(.round); c.setLineWidth(1.1)
            c.move(to: CGPoint(x: 5.2, y: 5.6)); c.addLine(to: CGPoint(x: 15.6, y: 16.2)); c.strokePath()
            c.setLineWidth(0.9)
            c.move(to: CGPoint(x: 12.4, y: 12.9)); c.addLine(to: CGPoint(x: 14.9, y: 11.4)); c.strokePath()
            c.move(to: CGPoint(x: 8.6, y: 9.1)); c.addLine(to: CGPoint(x: 6.9, y: 11.8)); c.strokePath()
        }
        c.setLineWidth(1.6); c.setLineCap(.round)
        c.move(to: CGPoint(x: 5.0, y: 5.4)); c.addLine(to: CGPoint(x: 1.6, y: 1.8)); c.strokePath()
    }),
    ("B · Peek eye", { c in
        corners(c)
        let eye = CGMutablePath()
        eye.move(to: CGPoint(x: 4.4, y: 9))
        eye.addQuadCurve(to: CGPoint(x: 13.6, y: 9), control: CGPoint(x: 9, y: 14.2))
        eye.addQuadCurve(to: CGPoint(x: 4.4, y: 9), control: CGPoint(x: 9, y: 3.8))
        c.addPath(eye); c.setLineWidth(1.5); c.setLineJoin(.round); c.strokePath()
        c.fillEllipse(in: CGRect(x: 7.1, y: 7.1, width: 3.8, height: 3.8))
    }),
    ("C · Spark", { c in
        corners(c)
        let s = CGMutablePath(), m = CGPoint(x: 9, y: 9), r: CGFloat = 4.6, k: CGFloat = 0.9
        s.move(to: CGPoint(x: m.x, y: m.y + r))
        s.addQuadCurve(to: CGPoint(x: m.x + r, y: m.y), control: CGPoint(x: m.x + k, y: m.y + k))
        s.addQuadCurve(to: CGPoint(x: m.x, y: m.y - r), control: CGPoint(x: m.x + k, y: m.y - k))
        s.addQuadCurve(to: CGPoint(x: m.x - r, y: m.y), control: CGPoint(x: m.x - k, y: m.y - k))
        s.addQuadCurve(to: CGPoint(x: m.x, y: m.y + r), control: CGPoint(x: m.x - k, y: m.y + k))
        c.addPath(s); c.fillPath()
    }),
    ("D · Pen nib", { c in
        // Fountain-pen nib tilted 45°, writing toward bottom-left.
        c.saveGState()
        c.translateBy(x: 9.6, y: 8.4); c.rotate(by: .pi / 4); c.translateBy(x: -9, y: -9)
        let nib = CGMutablePath()
        nib.move(to: CGPoint(x: 9, y: 0.6))
        nib.addLine(to: CGPoint(x: 4.3, y: 8.2))
        nib.addQuadCurve(to: CGPoint(x: 6.2, y: 15.8), control: CGPoint(x: 4.3, y: 13))
        nib.addLine(to: CGPoint(x: 11.8, y: 15.8))
        nib.addQuadCurve(to: CGPoint(x: 13.7, y: 8.2), control: CGPoint(x: 13.7, y: 13))
        nib.closeSubpath()
        c.addPath(nib); c.fillPath()
        cut(c) {
            c.setLineWidth(0.9); c.setLineCap(.round)
            c.move(to: CGPoint(x: 9, y: 1.2)); c.addLine(to: CGPoint(x: 9, y: 8.4)); c.strokePath()
            c.fillEllipse(in: CGRect(x: 7.7, y: 8.4, width: 2.6, height: 2.6))
            c.fill(CGRect(x: 5.4, y: 13.2, width: 7.2, height: 0.9))
        }
        c.restoreGState()
    }),
    ("E · Marquee", { c in
        let r = CGRect(x: 1.6, y: 5.2, width: 11.2, height: 11.2)
        c.setLineWidth(1.5); c.setLineDash(phase: 0, lengths: [2.4, 1.6])
        c.addPath(CGPath(roundedRect: r, cornerWidth: 2, cornerHeight: 2, transform: nil)); c.strokePath()
        c.setLineDash(phase: 0, lengths: [])
        // cursor arrow
        let a = CGMutablePath()
        a.move(to: CGPoint(x: 9.2, y: 9.6)); a.addLine(to: CGPoint(x: 16.8, y: 5.8)); a.addLine(to: CGPoint(x: 13.2, y: 4.6))
        a.addLine(to: CGPoint(x: 11.6, y: 1.0)); a.closeSubpath()
        cut(c) { c.addPath(a); c.setLineWidth(2.6); c.setLineJoin(.round); c.strokePath() }
        c.addPath(a); c.setLineJoin(.round); c.fillPath()
    }),
    ("F · Quill frame", { c in
        // Crop corners (top-left, bottom-right) + small feather crossing the frame.
        c.setLineWidth(1.7); c.setLineCap(.round); c.setLineJoin(.round)
        c.move(to: CGPoint(x: 1.4, y: 11.6)); c.addLine(to: CGPoint(x: 1.4, y: 16.6)); c.addLine(to: CGPoint(x: 6.4, y: 16.6)); c.strokePath()
        c.move(to: CGPoint(x: 11.6, y: 1.4)); c.addLine(to: CGPoint(x: 16.6, y: 1.4)); c.addLine(to: CGPoint(x: 16.6, y: 6.4)); c.strokePath()
        let f = CGMutablePath()
        f.move(to: CGPoint(x: 15.2, y: 15.6))
        f.addCurve(to: CGPoint(x: 6.0, y: 6.2), control1: CGPoint(x: 9.8, y: 15.2), control2: CGPoint(x: 5.8, y: 11.2))
        f.addCurve(to: CGPoint(x: 15.2, y: 15.6), control1: CGPoint(x: 10.8, y: 6.0), control2: CGPoint(x: 15.0, y: 10.0))
        c.addPath(f); c.fillPath()
        cut(c) {
            c.setLineWidth(0.9)
            c.move(to: CGPoint(x: 6.8, y: 7.0)); c.addLine(to: CGPoint(x: 14.3, y: 14.7)); c.strokePath()
        }
        c.setLineWidth(1.4)
        c.move(to: CGPoint(x: 6.6, y: 6.8)); c.addLine(to: CGPoint(x: 4.0, y: 4.0)); c.strokePath()
    }),
]

// Render one glyph as a tinted image at `px` pixels.
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
let W = glyphs.count * cellW + pad
let H = 420
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let sheet = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(CGColor(gray: 0.12, alpha: 1)); sheet.fill(CGRect(x: 0, y: 0, width: W, height: H))
// Fake menu bars at real size (18pt glyph at 2x = 36px): dark and light.
sheet.setFillColor(CGColor(gray: 0.02, alpha: 1)); sheet.fill(CGRect(x: 0, y: H - 50, width: W, height: 50))
sheet.setFillColor(CGColor(gray: 0.93, alpha: 1)); sheet.fill(CGRect(x: 0, y: H - 100, width: W, height: 50))

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
for (i, (name, g)) in glyphs.enumerated() {
    let x = pad + i * cellW
    let cx = x + (cellW - pad) / 2
    sheet.draw(render(g, px: 36, color: CGColor(gray: 1, alpha: 1)), in: CGRect(x: cx - 18, y: H - 43, width: 36, height: 36))
    sheet.draw(render(g, px: 36, color: CGColor(gray: 0, alpha: 0.85)), in: CGRect(x: cx - 18, y: H - 93, width: 36, height: 36))
    sheet.draw(render(g, px: big, color: CGColor(gray: 1, alpha: 1)), in: CGRect(x: cx - big / 2, y: 80, width: big, height: big))
    let label = NSAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .semibold),
                                                              .foregroundColor: NSColor.white])
    label.draw(at: CGPoint(x: CGFloat(cx) - label.size().width / 2, y: 30))
}
NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "menubar.png"
try! NSBitmapImageRep(cgImage: sheet.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
