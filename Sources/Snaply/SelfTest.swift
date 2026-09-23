import AppKit
import SwiftUI
import Carbon.HIToolbox

/// `Snaply --selftest <dir>`: drives the editor with synthetic input on a fake desktop
/// and writes the overlay UI and the exported image as PNGs. No screen permission needed.
@MainActor
enum SelfTest {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--selftest"), i + 1 < args.count else { return false }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        DispatchQueue.main.async { run(into: dir) }
        return true
    }

    private static func run(into dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let screen = NSScreen.main!
        let scale = screen.backingScaleFactor
        let image = fakeDesktop(size: screen.frame.size, scale: scale)
        let snapshot = ScreenSnapshot(screen: screen, image: image)
        let windowRect = CGRect(x: 180, y: 140, width: 640, height: 420)

        let session = CaptureSession(snapshots: [], windowFrames: [], onEnd: {})
        let editor = EditorState()
        let window = OverlayWindow(snapshot: snapshot, windowRects: [windowRect], editor: editor, session: session)
        let view = window.overlay
        window.orderFrontRegardless()

        func ev(_ type: NSEvent.EventType, _ p: CGPoint, shift: Bool = false, clicks: Int = 1) -> NSEvent {
            // View is flipped; window coordinates are not.
            let wp = CGPoint(x: p.x, y: view.bounds.height - p.y)
            return NSEvent.mouseEvent(with: type, location: wp, modifierFlags: shift ? .shift : [],
                                      timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                      eventNumber: 0, clickCount: clicks, pressure: 1)!
        }
        func drag(_ a: CGPoint, _ b: CGPoint, shift: Bool = false) {
            view.mouseDown(with: ev(.leftMouseDown, a))
            for t in stride(from: 0.1, through: 1.0, by: 0.1) {
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t + sin(t * .pi) * 12)
                view.mouseDragged(with: ev(.leftMouseDragged, p, shift: shift))
            }
            view.mouseUp(with: ev(.leftMouseUp, b))
        }
        func key(_ code: Int, _ chars: String = "", cmd: Bool = false) {
            let e = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: cmd ? .command : [],
                                     timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                     characters: chars, charactersIgnoringModifiers: chars,
                                     isARepeat: false, keyCode: UInt16(code))!
            view.handleKey(e)
        }

        // 1. Hover state (window highlight + loupe)
        view.mouseMoved(with: ev(.mouseMoved, CGPoint(x: 420, y: 300)))
        save(view, dir.appendingPathComponent("1-hover.png"))

        // 2. Drag a selection, then annotate
        drag(CGPoint(x: 200, y: 160), CGPoint(x: 800, y: 540))
        key(kVK_ANSI_A)                                   // arrow
        drag(CGPoint(x: 260, y: 480), CGPoint(x: 470, y: 330))
        key(kVK_ANSI_R)                                   // rect
        drag(CGPoint(x: 480, y: 250), CGPoint(x: 700, y: 330))
        key(kVK_ANSI_O)                                   // ellipse
        drag(CGPoint(x: 560, y: 380), CGPoint(x: 760, y: 500))
        key(kVK_ANSI_M)                                   // marker
        drag(CGPoint(x: 240, y: 205), CGPoint(x: 460, y: 205), shift: true)
        key(kVK_ANSI_B)                                   // pixelate
        drag(CGPoint(x: 230, y: 250), CGPoint(x: 420, y: 300))
        key(kVK_ANSI_N)                                   // counters
        for p in [CGPoint(x: 250, y: 380), CGPoint(x: 330, y: 400)] {
            view.mouseDown(with: ev(.leftMouseDown, p)); view.mouseUp(with: ev(.leftMouseUp, p))
        }
        key(kVK_ANSI_P)                                   // pen
        drag(CGPoint(x: 600, y: 200), CGPoint(x: 760, y: 230))
        key(kVK_ANSI_T)                                   // text
        view.mouseDown(with: ev(.leftMouseDown, CGPoint(x: 500, y: 460)))
        view.mouseUp(with: ev(.leftMouseUp, CGPoint(x: 500, y: 460)))
        (window.firstResponder as? NSTextView)?.insertText("Привет, Snaply!", replacementRange: NSRange(location: NSNotFound, length: 0))
        view.mouseMoved(with: ev(.mouseMoved, CGPoint(x: 900, y: 600)))

        // Hover the arrow tool button (4th control in the main bar).
        editor.hint = ToolbarHint(title: Tool.arrow.title, shortcut: Tool.arrow.keyLabel,
                                  anchor: CGRect(x: 15 + 32 * 3, y: 15, width: 30, height: 30))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            save(view, dir.appendingPathComponent("2-editor.png"))
            view.commitText()
            if let out = view.renderImage() {
                let url = dir.appendingPathComponent("3-export.png")
                _ = try? Exporter.write(out, scale: scale, to: url)
                print("export \(out.width)x\(out.height) -> \(url.path)")
            }
            let settings = NSHostingView(rootView: SettingsView())
            settings.frame = CGRect(x: 0, y: 0, width: 500, height: 1100)
            let sw = NSWindow(contentRect: settings.frame, styleMask: [.titled], backing: .buffered, defer: false)
            sw.contentView = settings
            settings.layoutSubtreeIfNeeded()
            if let rep = settings.bitmapImageRepForCachingDisplay(in: settings.bounds) {
                settings.cacheDisplay(in: settings.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("4-settings.png"))
            }
            print("selftest done")
            withExtendedLifetime(session) {}
            exit(0)
        }
    }

    private static func save(_ view: NSView, _ url: URL) {
        let root = view.window!.contentView!
        guard let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds) else { return }
        root.cacheDisplay(in: root.bounds, to: rep)
        // cacheDisplay doesn't render layer contents, so composite the frozen screen underneath.
        let size = root.bounds.size
        let final = NSImage(size: size)
        final.lockFocus()
        if let bg = root.layer?.contents { NSImage(cgImage: bg as! CGImage, size: size).draw(in: root.bounds) }
        rep.draw(in: root.bounds)
        final.unlockFocus()
        if let tiff = final.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
            print("wrote \(url.path)")
        }
    }

    private static func fakeDesktop(size: CGSize, scale: CGFloat) -> CGImage {
        let w = Int(size.width * scale), h = Int(size.height * scale)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        ctx.scaleBy(x: scale, y: scale)
        // Top-left origin for easier layout.
        ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGradient(colors: [NSColor(srgbRed: 0.15, green: 0.35, blue: 0.55, alpha: 1),
                            NSColor(srgbRed: 0.55, green: 0.3, blue: 0.5, alpha: 1)])!
            .draw(in: CGRect(origin: .zero, size: size), angle: 60)
        let win = CGRect(x: 180, y: 140, width: 640, height: 420)
        NSColor.white.setFill()
        NSBezierPath(roundedRect: win, xRadius: 12, yRadius: 12).fill()
        NSColor(white: 0.93, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(x: win.minX, y: win.minY + 12, width: win.width, height: 28)).fill()
        for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            c.setFill()
            NSBezierPath(ovalIn: CGRect(x: win.minX + 14 + CGFloat(i) * 20, y: win.minY + 12, width: 12, height: 12)).fill()
        }
        let para = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Секретный токен: sk-1234-5678-ABCD. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
        NSAttributedString(string: para, attributes: [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.darkGray])
            .draw(in: win.insetBy(dx: 40, dy: 70))
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()!
    }
}
