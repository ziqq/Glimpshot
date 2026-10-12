// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

import AppKit
import Carbon.HIToolbox

// MARK: - Tools

enum Tool: String, CaseIterable, Identifiable {
    case select, pen, line, arrow, rect, ellipse, marker, text, pixelate, counter

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .select: "cursorarrow"
        case .pen: "scribble"
        case .line: "line.diagonal"
        case .arrow: "arrow.up.right"
        case .rect: "rectangle"
        case .ellipse: "circle"
        case .marker: "highlighter"
        case .text: "textformat"
        case .pixelate: "square.grid.3x3.fill"
        case .counter: "1.circle"
        }
    }

    var title: String {
        switch self {
        case .select: L("tool.select")
        case .pen: L("tool.pen")
        case .line: L("tool.line")
        case .arrow: L("tool.arrow")
        case .rect: L("tool.rect")
        case .ellipse: L("tool.ellipse")
        case .marker: L("tool.marker")
        case .text: L("tool.text")
        case .pixelate: L("tool.pixelate")
        case .counter: L("tool.counter")
        }
    }

    var keyCode: Int {
        switch self {
        case .select: kVK_ANSI_V
        case .pen: kVK_ANSI_P
        case .line: kVK_ANSI_L
        case .arrow: kVK_ANSI_A
        case .rect: kVK_ANSI_R
        case .ellipse: kVK_ANSI_O
        case .marker: kVK_ANSI_M
        case .text: kVK_ANSI_T
        case .pixelate: kVK_ANSI_B
        case .counter: kVK_ANSI_N
        }
    }

    var keyLabel: String {
        switch self {
        case .select: "V"
        case .pen: "P"
        case .line: "L"
        case .arrow: "A"
        case .rect: "R"
        case .ellipse: "O"
        case .marker: "M"
        case .text: "T"
        case .pixelate: "B"
        case .counter: "N"
        }
    }

    var hasStyle: Bool { self != .select && self != .pixelate }
}

enum Palette {
    static let colors: [NSColor] = [
        NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1), // red
        NSColor(srgbRed: 1.00, green: 0.58, blue: 0.00, alpha: 1), // orange
        NSColor(srgbRed: 1.00, green: 0.80, blue: 0.00, alpha: 1), // yellow
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1), // green
        NSColor(srgbRed: 0.04, green: 0.52, blue: 1.00, alpha: 1), // blue
        NSColor(srgbRed: 0.75, green: 0.35, blue: 0.95, alpha: 1), // purple
        NSColor(srgbRed: 1.00, green: 0.18, blue: 0.47, alpha: 1), // pink
        NSColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1), // white
        NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1), // black
    ]

    /// Stroke widths for thin / medium / thick.
    static let widths: [CGFloat] = [2.5, 4, 7]
    static let fontSizes: [CGFloat] = [18, 24, 34]
    static let counterRadii: [CGFloat] = [11, 14, 18]
}

// MARK: - Annotation

enum Shape {
    case pen([CGPoint])
    case marker([CGPoint])
    case line(CGPoint, CGPoint)
    case arrow(CGPoint, CGPoint)
    case rect(CGPoint, CGPoint)
    case ellipse(CGPoint, CGPoint)
    case pixelate(CGPoint, CGPoint)
    case text(String, CGPoint, CGFloat)
    case counter(Int, CGPoint, CGFloat)
}

struct RenderEnv {
    /// Full canvas (the whole screen) in points.
    let canvas: CGRect
    /// Lazily produced pixelated copy of the whole screen.
    let pixelated: () -> CGImage?
}

struct Annotation {
    var shape: Shape
    var color: NSColor
    var width: CGFloat

    static func begin(tool: Tool, at p: CGPoint, color: NSColor, width: CGFloat) -> Annotation? {
        let shape: Shape
        switch tool {
        case .pen: shape = .pen([p])
        case .marker: shape = .marker([p])
        case .line: shape = .line(p, p)
        case .arrow: shape = .arrow(p, p)
        case .rect: shape = .rect(p, p)
        case .ellipse: shape = .ellipse(p, p)
        case .pixelate: shape = .pixelate(p, p)
        default: return nil
        }
        return Annotation(shape: shape, color: color, width: width)
    }

    mutating func update(to p: CGPoint, constrained: Bool) {
        switch shape {
        case .pen(var pts):
            if let last = pts.last, hypot(last.x - p.x, last.y - p.y) < 0.8 { return }
            pts.append(p); shape = .pen(pts)
        case .marker(var pts):
            if constrained, let first = pts.first {
                shape = .marker([first, Geometry.snapAxis(from: first, to: p)])
            } else {
                pts.append(p); shape = .marker(pts)
            }
        case let .line(s, _): shape = .line(s, constrained ? Geometry.snap45(from: s, to: p) : p)
        case let .arrow(s, _): shape = .arrow(s, constrained ? Geometry.snap45(from: s, to: p) : p)
        case let .rect(s, _): shape = .rect(s, constrained ? Geometry.square(from: s, to: p) : p)
        case let .ellipse(s, _): shape = .ellipse(s, constrained ? Geometry.square(from: s, to: p) : p)
        case let .pixelate(s, _): shape = .pixelate(s, p)
        case .text, .counter: break
        }
    }

    var isMeaningful: Bool {
        switch shape {
        case let .pen(pts), let .marker(pts): return pts.count > 1
        case let .line(a, b), let .arrow(a, b): return hypot(a.x - b.x, a.y - b.y) > 3
        case let .rect(a, b), let .ellipse(a, b), let .pixelate(a, b):
            return abs(a.x - b.x) > 3 && abs(a.y - b.y) > 3
        case let .text(s, _, _): return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .counter: return true
        }
    }

    // MARK: Drawing (context is flipped: y grows downwards)

    func draw(in ctx: CGContext, env: RenderEnv) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(width)
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)

        let shadow = { ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 4,
                                     color: NSColor.black.withAlphaComponent(0.35).cgColor) }

        switch shape {
        case let .pen(pts):
            shadow()
            ctx.addPath(Geometry.smoothPath(pts))
            ctx.strokePath()

        case let .marker(pts):
            ctx.setLineCap(.square)
            ctx.setLineWidth(width * 4.5)
            ctx.setStrokeColor(color.withAlphaComponent(0.42).cgColor)
            ctx.addPath(Geometry.smoothPath(pts))
            ctx.strokePath()

        case let .line(a, b):
            shadow()
            ctx.move(to: a); ctx.addLine(to: b)
            ctx.strokePath()

        case let .arrow(a, b):
            shadow()
            ctx.addPath(Geometry.arrowPath(from: a, to: b, width: width))
            ctx.fillPath()

        case let .rect(a, b):
            shadow()
            let r = Geometry.rect(a, b)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: min(3, r.width / 2), cornerHeight: min(3, r.height / 2), transform: nil))
            ctx.strokePath()

        case let .ellipse(a, b):
            shadow()
            ctx.strokeEllipse(in: Geometry.rect(a, b))

        case let .pixelate(a, b):
            guard let img = env.pixelated() else { return }
            ctx.clip(to: Geometry.rect(a, b))
            ctx.interpolationQuality = .none
            Geometry.drawImage(img, in: env.canvas, ctx: ctx)

        case let .text(string, origin, size):
            shadow()
            NSAttributedString(string: string, attributes: Annotation.textAttributes(color: color, size: size))
                .draw(at: origin)

        case let .counter(n, center, radius):
            shadow()
            let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            ctx.fillEllipse(in: circle)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(max(1.5, radius / 8))
            ctx.strokeEllipse(in: circle.insetBy(dx: 0.5, dy: 0.5))
            let fg: NSColor = color.luminance > 0.7 ? .black : .white
            let label = NSAttributedString(string: "\(n)", attributes: [
                .font: NSFont.systemFont(ofSize: radius * 1.05, weight: .bold),
                .foregroundColor: fg,
            ])
            let size = label.size()
            label.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
        }
    }

    static func textAttributes(color: NSColor, size: CGFloat) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: color]
    }
}

extension NSColor {
    var luminance: CGFloat {
        guard let c = usingColorSpace(.sRGB) else { return 0 }
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
    }
}

// MARK: - Geometry helpers

enum Geometry {
    static func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    static func snap45(from s: CGPoint, to p: CGPoint) -> CGPoint {
        let dx = p.x - s.x, dy = p.y - s.y
        let len = hypot(dx, dy)
        let angle = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        return CGPoint(x: s.x + cos(angle) * len, y: s.y + sin(angle) * len)
    }

    static func snapAxis(from s: CGPoint, to p: CGPoint) -> CGPoint {
        abs(p.x - s.x) > abs(p.y - s.y) ? CGPoint(x: p.x, y: s.y) : CGPoint(x: s.x, y: p.y)
    }

    static func square(from s: CGPoint, to p: CGPoint) -> CGPoint {
        let side = max(abs(p.x - s.x), abs(p.y - s.y))
        return CGPoint(x: s.x + (p.x >= s.x ? side : -side), y: s.y + (p.y >= s.y ? side : -side))
    }

    static func smoothPath(_ pts: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = pts.first else { return path }
        path.move(to: first)
        if pts.count < 3 {
            path.addLine(to: pts.last!)
            return path
        }
        for i in 1..<(pts.count - 1) {
            let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            path.addQuadCurve(to: mid, control: pts[i])
        }
        path.addLine(to: pts.last!)
        return path
    }

    /// A single filled outline: tapered shaft + notched head.
    static func arrowPath(from a: CGPoint, to b: CGPoint, width: CGFloat) -> CGPath {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.001)
        let ux = dx / len, uy = dy / len       // direction
        let px = -uy, py = ux                  // perpendicular
        let head = min(max(width * 4.2, 14), len * 0.7)
        let halfHead = head * 0.5
        let notch = head * 0.72
        let tail = width * 0.25
        let neck = width * 0.55

        func pt(_ along: CGFloat, _ side: CGFloat) -> CGPoint {
            CGPoint(x: a.x + ux * along + px * side, y: a.y + uy * along + py * side)
        }
        let path = CGMutablePath()
        path.move(to: pt(0, tail))
        path.addLine(to: pt(len - notch, neck))
        path.addLine(to: pt(len - head, halfHead))
        path.addLine(to: b)
        path.addLine(to: pt(len - head, -halfHead))
        path.addLine(to: pt(len - notch, -neck))
        path.addLine(to: pt(0, -tail))
        path.closeSubpath()
        return path
    }

    /// Draws a CGImage right side up inside a flipped context.
    static func drawImage(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
        ctx.restoreGState()
    }
}
