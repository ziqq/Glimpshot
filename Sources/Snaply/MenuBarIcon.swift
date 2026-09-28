import AppKit

/// Menu bar glyphs, drawn as 18×18 pt template images (y up).
enum MenuBarIcon: String, CaseIterable, Identifiable {
    case quill, feather, eye, spark, nib, marquee, viewfinder

    var id: String { rawValue }

    var image: NSImage {
        if self == .viewfinder {
            let img = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: AppInfo.name)!
            img.isTemplate = true
            return img
        }
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.setFillColor(NSColor.black.cgColor)
            c.setStrokeColor(NSColor.black.cgColor)
            self.draw(in: c)
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = AppInfo.name
        return img
    }

    private func draw(in c: CGContext) {
        switch self {
        case .quill: Self.quill(c)
        case .feather: Self.feather(c)
        case .eye: Self.eye(c)
        case .spark: Self.spark(c)
        case .nib: Self.nib(c)
        case .marquee: Self.marquee(c)
        case .viewfinder: break
        }
    }

    // MARK: Glyphs

    private static func cut(_ c: CGContext, _ body: () -> Void) {
        c.saveGState(); c.setBlendMode(.clear); body(); c.restoreGState()
    }

    private static func corners(_ c: CGContext, inset: CGFloat = 1.4, arm: CGFloat = 4.2, width: CGFloat = 1.7) {
        let a = inset, b = 18 - inset
        for (x, y, dx, dy) in [(a, b, 1.0, -1.0), (b, b, -1.0, -1.0), (b, a, -1.0, 1.0), (a, a, 1.0, 1.0)] {
            c.move(to: CGPoint(x: x, y: y + dy * arm)); c.addLine(to: CGPoint(x: x, y: y)); c.addLine(to: CGPoint(x: x + dx * arm, y: y))
        }
        c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round); c.strokePath()
    }

    /// Crop corners with a feather crossing the frame.
    private static func quill(_ c: CGContext) {
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
    }

    private static func feather(_ c: CGContext) {
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
    }

    private static func eye(_ c: CGContext) {
        corners(c)
        let eye = CGMutablePath()
        eye.move(to: CGPoint(x: 4.4, y: 9))
        eye.addQuadCurve(to: CGPoint(x: 13.6, y: 9), control: CGPoint(x: 9, y: 14.2))
        eye.addQuadCurve(to: CGPoint(x: 4.4, y: 9), control: CGPoint(x: 9, y: 3.8))
        c.addPath(eye); c.setLineWidth(1.5); c.setLineJoin(.round); c.strokePath()
        c.fillEllipse(in: CGRect(x: 7.1, y: 7.1, width: 3.8, height: 3.8))
    }

    private static func spark(_ c: CGContext) {
        corners(c)
        let s = CGMutablePath(), m = CGPoint(x: 9, y: 9), r: CGFloat = 4.6, k: CGFloat = 0.9
        s.move(to: CGPoint(x: m.x, y: m.y + r))
        s.addQuadCurve(to: CGPoint(x: m.x + r, y: m.y), control: CGPoint(x: m.x + k, y: m.y + k))
        s.addQuadCurve(to: CGPoint(x: m.x, y: m.y - r), control: CGPoint(x: m.x + k, y: m.y - k))
        s.addQuadCurve(to: CGPoint(x: m.x - r, y: m.y), control: CGPoint(x: m.x - k, y: m.y - k))
        s.addQuadCurve(to: CGPoint(x: m.x, y: m.y + r), control: CGPoint(x: m.x - k, y: m.y + k))
        c.addPath(s); c.fillPath()
    }

    private static func nib(_ c: CGContext) {
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
    }

    private static func marquee(_ c: CGContext) {
        let r = CGRect(x: 1.6, y: 5.2, width: 11.2, height: 11.2)
        c.setLineWidth(1.5); c.setLineDash(phase: 0, lengths: [2.4, 1.6])
        c.addPath(CGPath(roundedRect: r, cornerWidth: 2, cornerHeight: 2, transform: nil)); c.strokePath()
        c.setLineDash(phase: 0, lengths: [])
        let a = CGMutablePath()
        a.move(to: CGPoint(x: 9.2, y: 9.6)); a.addLine(to: CGPoint(x: 16.8, y: 5.8)); a.addLine(to: CGPoint(x: 13.2, y: 4.6))
        a.addLine(to: CGPoint(x: 11.6, y: 1.0)); a.closeSubpath()
        cut(c) { c.addPath(a); c.setLineWidth(2.6); c.setLineJoin(.round); c.strokePath() }
        c.addPath(a); c.setLineJoin(.round); c.fillPath()
    }
}
