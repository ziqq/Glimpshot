// Renders icon concepts side by side: `swift scripts/icon_concepts.swift <out-dir>`
import AppKit
import CoreImage

let S: CGFloat = 1024
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".", isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let gBlue = rgb(0x4285F4), gRed = rgb(0xEA4335), gYellow = rgb(0xFBBC04), gGreen = rgb(0x34A853)

func newContext() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

func dropShadow(_ ctx: CGContext) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x000000, 0.35))
    ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x000000)); ctx.fillPath()
    ctx.restoreGState()
}

func linear(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func radial(_ ctx: CGContext, _ colors: [CGColor], center: CGPoint, radius: CGFloat) {
    let g = CGGradient(colorsSpace: srgb, colors: colors as CFArray, locations: nil)!
    ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

/// Four L-shaped viewfinder corners.
func corners(inset: CGFloat, arm: CGFloat) -> [CGPath] {
    let f = body.insetBy(dx: inset, dy: inset)
    return [(f.minX, f.maxY, 1.0, -1.0), (f.maxX, f.maxY, -1.0, -1.0),
            (f.maxX, f.minY, -1.0, 1.0), (f.minX, f.minY, 1.0, 1.0)].map { x, y, dx, dy in
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y + dy * arm))
        p.addLine(to: CGPoint(x: x, y: y))
        p.addLine(to: CGPoint(x: x + dx * arm, y: y))
        return p
    }
}

func stroked(_ paths: [CGPath], width: CGFloat) -> CGPath {
    let all = CGMutablePath()
    for p in paths { all.addPath(p.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)) }
    return all
}

/// Google-2025-style blended four-color field: a conic sweep, heavily blurred.
func googleField(blur: CGFloat) -> CGImage {
    let c = newContext()
    c.setFillColor(gBlue); c.fill(CGRect(x: 0, y: 0, width: S, height: S))
    // Blue top-left, red top-right, yellow bottom-right, green bottom-left.
    for (color, x, y) in [(gBlue, 250.0, 780.0), (gRed, 790.0, 780.0), (gYellow, 780.0, 240.0), (gGreen, 240.0, 250.0)] {
        c.setFillColor(color)
        c.fillEllipse(in: CGRect(x: x - 330, y: y - 330, width: 660, height: 660))
    }
    let ci = CIImage(cgImage: c.makeImage()!).clampedToExtent()
        .applyingGaussianBlur(sigma: blur).cropped(to: CGRect(x: 0, y: 0, width: S, height: S))
    return CIContext().createCGImage(ci, from: ci.extent)!
}

func save(_ ctx: CGContext, _ name: String) -> CGImage {
    let img = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(name).png"))
    return img
}

var concepts: [(String, CGImage)] = []

// 1. Google gradient — white tile, viewfinder filled with the blended 4-color field.
do {
    let ctx = newContext()
    dropShadow(ctx)
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    linear(ctx, [rgb(0xFFFFFF), rgb(0xF1F3F4)], from: CGPoint(x: 0, y: S), to: CGPoint(x: 0, y: 0))
    ctx.restoreGState()
    let glyph = stroked(corners(inset: 190, arm: 150), width: 84)
    let dot = CGPath(ellipseIn: CGRect(x: S / 2 - 78, y: S / 2 - 78, width: 156, height: 156), transform: nil)
    ctx.saveGState()
    ctx.addPath(glyph); ctx.addPath(dot); ctx.clip()
    ctx.draw(googleField(blur: 60), in: CGRect(x: 0, y: 0, width: S, height: S))
    ctx.restoreGState()
    concepts.append(("1 · Google gradient", save(ctx, "concept-1-google-gradient")))
}

// 2. Google corners — each corner a brand color, soft gradient inside each stroke.
do {
    let ctx = newContext()
    dropShadow(ctx)
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    linear(ctx, [rgb(0xFFFFFF), rgb(0xF3F4F6)], from: CGPoint(x: 0, y: S), to: CGPoint(x: 0, y: 0))
    ctx.restoreGState()
    let pairs: [(CGColor, CGColor)] = [(gBlue, rgb(0x6EA8FF)), (gRed, rgb(0xFF7A6B)),
                                       (gYellow, rgb(0xFFD54F)), (gGreen, rgb(0x5BC77A))]
    for (i, p) in corners(inset: 190, arm: 160).enumerated() {
        ctx.saveGState()
        ctx.addPath(stroked([p], width: 92)); ctx.clip()
        let b = p.boundingBox.insetBy(dx: -50, dy: -50)
        linear(ctx, [pairs[i].1, pairs[i].0], from: CGPoint(x: b.minX, y: b.maxY), to: CGPoint(x: b.maxX, y: b.minY))
        ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: S / 2 - 70, y: S / 2 - 70, width: 140, height: 140)); ctx.clip()
    ctx.draw(googleField(blur: 30), in: CGRect(x: 0, y: 0, width: S, height: S))
    ctx.restoreGState()
    concepts.append(("2 · Google corners", save(ctx, "concept-2-google-corners")))
}

// 3. Liquid Glass (macOS 26) — deep gradient, frosted glass plate, white glyph.
do {
    let ctx = newContext()
    dropShadow(ctx)
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    linear(ctx, [rgb(0x5B4BFF), rgb(0xA13BF5), rgb(0xFF4F8B)], from: CGPoint(x: 100, y: 924), to: CGPoint(x: 924, y: 100))
    radial(ctx, [rgb(0xFFFFFF, 0.35), rgb(0xFFFFFF, 0)], center: CGPoint(x: 330, y: 800), radius: 520)
    // glass plate
    let plate = CGRect(x: 250, y: 250, width: 524, height: 524)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 130, cornerHeight: 130, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x2A0A5E, 0.45))
    ctx.addPath(platePath); ctx.setFillColor(rgb(0xFFFFFF, 0.22)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(platePath); ctx.clip()
    linear(ctx, [rgb(0xFFFFFF, 0.35), rgb(0xFFFFFF, 0.02)], from: CGPoint(x: 0, y: plate.maxY), to: CGPoint(x: 0, y: plate.midY))
    ctx.restoreGState()
    ctx.addPath(platePath.copy(strokingWithWidth: 6, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.setFillColor(rgb(0xFFFFFF, 0.55)); ctx.fillPath()
    // glyph
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 10, color: rgb(0x2A0A5E, 0.3))
    let f = plate.insetBy(dx: 95, dy: 95)
    let g = CGMutablePath()
    for (x, y, dx, dy) in [(f.minX, f.maxY, 1.0, -1.0), (f.maxX, f.maxY, -1.0, -1.0), (f.maxX, f.minY, -1.0, 1.0), (f.minX, f.minY, 1.0, 1.0)] {
        g.move(to: CGPoint(x: x, y: y + dy * 85)); g.addLine(to: CGPoint(x: x, y: y)); g.addLine(to: CGPoint(x: x + dx * 85, y: y))
    }
    ctx.addPath(g.copy(strokingWithWidth: 44, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.addEllipse(in: CGRect(x: S / 2 - 48, y: S / 2 - 48, width: 96, height: 96))
    ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
    concepts.append(("3 · Liquid Glass", save(ctx, "concept-3-liquid-glass")))
}

// 4. Editor mono — dark tile, selection frame with handles like the app's UI.
do {
    let ctx = newContext()
    dropShadow(ctx)
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    linear(ctx, [rgb(0x2B2D33), rgb(0x121316)], from: CGPoint(x: 0, y: S), to: CGPoint(x: 0, y: 0))
    radial(ctx, [rgb(0x7C6CFF, 0.35), rgb(0x7C6CFF, 0)], center: CGPoint(x: 700, y: 330), radius: 420)
    let r = CGRect(x: 265, y: 300, width: 494, height: 424)
    ctx.setLineDash(phase: 0, lengths: [34, 22])
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.9)); ctx.setLineWidth(14)
    ctx.stroke(r)
    ctx.setLineDash(phase: 0, lengths: [])
    for p in [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.maxX, y: r.maxY)] {
        let h = CGRect(x: p.x - 34, y: p.y - 34, width: 68, height: 68)
        ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillEllipse(in: h)
        ctx.setStrokeColor(rgb(0x7C6CFF)); ctx.setLineWidth(12); ctx.strokeEllipse(in: h.insetBy(dx: 6, dy: 6))
    }
    // arrow annotation
    let a = CGMutablePath()
    a.move(to: CGPoint(x: 380, y: 420)); a.addLine(to: CGPoint(x: 590, y: 600))
    ctx.addPath(a.copy(strokingWithWidth: 30, lineCap: .round, lineJoin: .round, miterLimit: 10))
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 640, y: 645)); head.addLine(to: CGPoint(x: 520, y: 615)); head.addLine(to: CGPoint(x: 605, y: 530)); head.closeSubpath()
    ctx.addPath(head)
    ctx.setFillColor(rgb(0xFF4F5E)); ctx.fillPath()
    ctx.restoreGState()
    concepts.append(("4 · Editor mono", save(ctx, "concept-4-editor-mono")))
}

// 5. Sunset scribble — warm gradient, white viewfinder, marker swoosh.
do {
    let ctx = newContext()
    dropShadow(ctx)
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    linear(ctx, [rgb(0xFFB547), rgb(0xFF5E62), rgb(0xD63AF9)], from: CGPoint(x: 150, y: 950), to: CGPoint(x: 900, y: 80))
    radial(ctx, [rgb(0xFFFFFF, 0.3), rgb(0xFFFFFF, 0)], center: CGPoint(x: 320, y: 820), radius: 460)
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: rgb(0x7A1030, 0.3))
    ctx.addPath(stroked(corners(inset: 200, arm: 130), width: 58)); ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
    let s = CGMutablePath()
    s.move(to: CGPoint(x: 350, y: 470))
    s.addCurve(to: CGPoint(x: 680, y: 560), control1: CGPoint(x: 450, y: 620), control2: CGPoint(x: 560, y: 380))
    ctx.addPath(s.copy(strokingWithWidth: 62, lineCap: .round, lineJoin: .round, miterLimit: 10))
    ctx.setFillColor(rgb(0xFFF36B, 0.95)); ctx.fillPath()
    ctx.restoreGState()
    concepts.append(("5 · Sunset scribble", save(ctx, "concept-5-sunset-scribble")))
}

// 0. Current icon for reference.
if let cur = NSImage(contentsOfFile: "Resources/current-icon.png")?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    concepts.insert(("0 · Current", cur), at: 0)
}

// Contact sheet on light and dark backgrounds.
let cell: CGFloat = 300, pad: CGFloat = 36, label: CGFloat = 44
let cols = concepts.count
let sheetW = CGFloat(cols) * (cell + pad) + pad
let sheetH = 2 * (cell + label + pad) + pad
let sheet = CGContext(data: nil, width: Int(sheetW), height: Int(sheetH), bitsPerComponent: 8, bytesPerRow: 0,
                      space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
for (row, bg) in [(0, rgb(0x1E1E20)), (1, rgb(0xF5F5F7))] {
    let y0 = CGFloat(row) * (cell + label + pad)
    sheet.setFillColor(bg); sheet.fill(CGRect(x: 0, y: y0, width: sheetW, height: cell + label + pad * 1.5))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: sheet, flipped: false)
    for (i, (name, img)) in concepts.enumerated() {
        let x = pad + CGFloat(i) * (cell + pad)
        sheet.interpolationQuality = .high
        sheet.draw(img, in: CGRect(x: x, y: y0 + pad + label, width: cell, height: cell))
        let attr = NSAttributedString(string: name, attributes: [
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: row == 0 ? NSColor.white : NSColor.black,
        ])
        attr.draw(at: CGPoint(x: x + (cell - attr.size().width) / 2, y: y0 + pad * 0.6))
    }
    NSGraphicsContext.restoreGraphicsState()
}
let rep = NSBitmapImageRep(cgImage: sheet.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("icon-concepts.png"))
print("wrote \(concepts.count) concepts")
