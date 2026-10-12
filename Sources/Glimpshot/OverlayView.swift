// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

import AppKit
import Carbon.HIToolbox
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: - Window

final class OverlayWindow: NSWindow {
    let overlay: OverlayView

    init(snapshot: ScreenSnapshot, windowRects: [CGRect], editor: EditorState, session: CaptureSession) {
        let frame = snapshot.screen.frame
        let bounds = CGRect(origin: .zero, size: frame.size)
        overlay = OverlayView(frame: bounds, snapshot: snapshot, windowRects: windowRects, editor: editor)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let background = FrozenScreenView(frame: bounds, image: snapshot.image)
        overlay.autoresizingMask = [.width, .height]
        background.addSubview(overlay)
        contentView = background
        overlay.session = session
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shows the frozen screenshot through a layer so it isn't redrawn on every mouse move.
private final class FrozenScreenView: NSView {
    init(frame: CGRect, image: CGImage) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resize
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Overlay view

final class OverlayView: NSView, NSTextViewDelegate {
    private enum Handle: CaseIterable { case tl, t, tr, r, br, b, bl, l }

    private enum Drag {
        case none
        case creating(start: CGPoint, moved: Bool)
        case moving(start: CGPoint, original: CGRect)
        case resizing(Handle, original: CGRect)
        case drawing
    }

    let snapshot: ScreenSnapshot
    weak var session: CaptureSession?
    private let editor: EditorState
    private let windowRects: [CGRect]

    private(set) var selection: CGRect?
    private var hoverRect: CGRect?
    private var mouse: CGPoint?
    private var drag: Drag = .none

    private var annotations: [Annotation] = [] { didSet { syncUndoState() } }
    private var redoStack: [Annotation] = [] { didSet { syncUndoState() } }
    private var current: Annotation?

    private var textView: AnnotationTextView?
    private var toolbar: ToolbarHost!
    private var cancellables: Set<AnyCancellable> = []
    private lazy var pixelatedImage: CGImage? = makePixelated()
    private var pixelCache: (x: Int, y: Int, hex: String)?

    private let dimColor = NSColor(white: 0, alpha: 0.45)

    init(frame: CGRect, snapshot: ScreenSnapshot, windowRects: [CGRect], editor: EditorState) {
        self.snapshot = snapshot
        self.windowRects = windowRects
        self.editor = editor
        super.init(frame: frame)
        wantsLayer = true

        toolbar = ToolbarHost(rootView: EditorToolbar(state: editor) { [weak self] action in
            self?.perform(action)
        })
        toolbar.onSizeChange = { [weak self] in self?.layoutToolbar() }
        toolbar.isHidden = true
        addSubview(toolbar)

        editor.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.editorChanged() }
            .store(in: &cancellables)

        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var isActive: Bool { session?.activeView === self }

    // MARK: State

    func resetSelection() {
        commitText()
        selection = nil
        annotations.removeAll()
        redoStack.removeAll()
        current = nil
        drag = .none
        layoutToolbar()
        needsDisplay = true
    }

    private func syncUndoState() {
        guard isActive else { return }
        if editor.canUndo != !annotations.isEmpty { editor.canUndo = !annotations.isEmpty }
        if editor.canRedo != !redoStack.isEmpty { editor.canRedo = !redoStack.isEmpty }
    }

    private func editorChanged() {
        if editor.tool != .text { commitText() }
        if let tv = textView {
            tv.textColor = editor.color
            tv.insertionPointColor = editor.color
            tv.font = NSFont.systemFont(ofSize: editor.fontSize, weight: .semibold)
            tv.sizeToFit()
        }
        layoutToolbar()
        updateCursor()
        needsDisplay = true
    }

    // MARK: Mouse

    private func point(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CGPoint(x: min(max(p.x, 0), bounds.width), y: min(max(p.y, 0), bounds.height))
    }

    override func mouseMoved(with event: NSEvent) {
        let p = point(event)
        mouse = p
        if selection == nil {
            hoverRect = windowRects.first { $0.contains(p) }
        }
        updateCursor()
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        mouse = nil
        if selection == nil { hoverRect = nil }
        needsDisplay = true
    }

    override func cursorUpdate(with event: NSEvent) { updateCursor() }

    override func mouseDown(with event: NSEvent) {
        let p = point(event)
        session?.activate(self)
        window?.makeFirstResponder(self)
        commitText()

        guard let sel = selection else {
            drag = .creating(start: p, moved: false)
            return
        }

        if event.clickCount == 2, sel.contains(p), editor.tool == .select {
            session?.finish(.copy, from: self)
            return
        }
        if let h = handle(at: p, in: sel) {
            drag = .resizing(h, original: sel)
            return
        }
        if sel.contains(p) {
            switch editor.tool {
            case .select:
                drag = .moving(start: p, original: sel)
                NSCursor.closedHand.set()
            case .text:
                beginText(at: p)
            case .counter:
                let n = annotations.filter { if case .counter = $0.shape { true } else { false } }.count + 1
                annotations.append(Annotation(shape: .counter(n, p, editor.counterRadius),
                                              color: editor.color, width: editor.width))
                redoStack.removeAll()
            default:
                current = Annotation.begin(tool: editor.tool, at: p, color: editor.color, width: editor.width)
                drag = .drawing
            }
            needsDisplay = true
            return
        }
        // Outside of the selection.
        switch editor.tool {
        case .select:
            // Start a new selection, unless there is work to lose.
            guard annotations.isEmpty else { return }
            selection = nil
            drag = .creating(start: p, moved: false)
            layoutToolbar()
            needsDisplay = true
        case .text, .counter:
            break
        default:
            // Strokes may start outside (e.g. an arrow pointing in); they're clipped to the selection.
            current = Annotation.begin(tool: editor.tool, at: p, color: editor.color, width: editor.width)
            drag = .drawing
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = point(event)
        mouse = p
        switch drag {
        case .none:
            return
        case let .creating(start, _):
            if hypot(p.x - start.x, p.y - start.y) < 3 { return }
            selection = Geometry.rect(start, p)
            hoverRect = nil
            drag = .creating(start: start, moved: true)
        case let .moving(start, original):
            var r = original.offsetBy(dx: p.x - start.x, dy: p.y - start.y)
            r.origin.x = min(max(r.minX, 0), bounds.width - r.width)
            r.origin.y = min(max(r.minY, 0), bounds.height - r.height)
            selection = r
        case let .resizing(h, original):
            selection = resized(original, h, to: p)
        case .drawing:
            current?.update(to: p, constrained: event.modifierFlags.contains(.shift))
        }
        layoutToolbar()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        switch drag {
        case let .creating(_, moved):
            if !moved || (selection.map { $0.width < 4 || $0.height < 4 } ?? true) {
                selection = hoverRect ?? bounds
            }
            hoverRect = nil
        case .drawing:
            if let c = current, c.isMeaningful {
                annotations.append(c)
                redoStack.removeAll()
            }
            current = nil
        case .resizing:
            if let s = selection, s.width < 4 || s.height < 4 {
                selection = CGRect(x: s.minX, y: s.minY, width: max(s.width, 4), height: max(s.height, 4))
            }
        default:
            break
        }
        drag = .none
        layoutToolbar()
        updateCursor()
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        // Right click cancels only before anything is selected — an accidental
        // secondary click on a trackpad shouldn't throw away a selection.
        if selection == nil { session?.finish(.cancel, from: self) }
    }

    // MARK: Handles

    private func handlePoints(_ r: CGRect) -> [(Handle, CGPoint)] {
        [(.tl, CGPoint(x: r.minX, y: r.minY)), (.t, CGPoint(x: r.midX, y: r.minY)),
         (.tr, CGPoint(x: r.maxX, y: r.minY)), (.r, CGPoint(x: r.maxX, y: r.midY)),
         (.br, CGPoint(x: r.maxX, y: r.maxY)), (.b, CGPoint(x: r.midX, y: r.maxY)),
         (.bl, CGPoint(x: r.minX, y: r.maxY)), (.l, CGPoint(x: r.minX, y: r.midY))]
    }

    private func handle(at p: CGPoint, in r: CGRect) -> Handle? {
        for (h, c) in handlePoints(r) where hypot(p.x - c.x, p.y - c.y) <= 9 { return h }
        guard editor.tool == .select else { return nil }
        let e: CGFloat = 5
        let inX = p.x > r.minX && p.x < r.maxX, inY = p.y > r.minY && p.y < r.maxY
        if inX && abs(p.y - r.minY) < e { return .t }
        if inX && abs(p.y - r.maxY) < e { return .b }
        if inY && abs(p.x - r.minX) < e { return .l }
        if inY && abs(p.x - r.maxX) < e { return .r }
        return nil
    }

    private func resized(_ o: CGRect, _ h: Handle, to p: CGPoint) -> CGRect {
        var minX = o.minX, maxX = o.maxX, minY = o.minY, maxY = o.maxY
        switch h {
        case .tl: minX = p.x; minY = p.y
        case .t: minY = p.y
        case .tr: maxX = p.x; minY = p.y
        case .r: maxX = p.x
        case .br: maxX = p.x; maxY = p.y
        case .b: maxY = p.y
        case .bl: minX = p.x; maxY = p.y
        case .l: minX = p.x
        }
        return Geometry.rect(CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: maxY))
    }

    private func updateCursor() {
        guard let p = mouse else { return }
        guard let sel = selection else { NSCursor.crosshair.set(); return }
        if case .moving = drag { NSCursor.closedHand.set(); return }
        if let h = handle(at: p, in: sel) {
            cursor(for: h).set()
        } else if sel.contains(p) {
            switch editor.tool {
            case .select: NSCursor.openHand.set()
            case .text: NSCursor.iBeam.set()
            default: NSCursor.crosshair.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }

    private func cursor(for h: Handle) -> NSCursor {
        if #available(macOS 15.0, *) {
            let pos: NSCursor.FrameResizePosition = switch h {
            case .tl: .topLeft
            case .t: .top
            case .tr: .topRight
            case .r: .right
            case .br: .bottomRight
            case .b: .bottom
            case .bl: .bottomLeft
            case .l: .left
            }
            return NSCursor.frameResize(position: pos, directions: .all)
        }
        switch h {
        case .t, .b: return .resizeUpDown
        case .l, .r: return .resizeLeftRight
        default: return .crosshair
        }
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if let active = session?.activeView, active !== self {
            active.handleKey(event)
        } else {
            handleKey(event)
        }
    }

    func handleKey(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command), shift = flags.contains(.shift)
        let code = Int(event.keyCode)

        switch code {
        case kVK_Escape:
            session?.finish(.cancel, from: self); return
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if selection != nil { session?.finish(.copy, from: self) }
            return
        case kVK_Delete, kVK_ForwardDelete:
            undo(); return
        case kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow:
            nudge(code: code, step: shift ? 10 : 1, resize: flags.contains(.option)); return
        default: break
        }

        if cmd {
            switch code {
            case kVK_ANSI_C: if selection != nil { session?.finish(.copy, from: self) }
            case kVK_ANSI_S: if selection != nil { session?.finish(shift ? .saveAs : .save, from: self) }
            case kVK_ANSI_P: if selection != nil { session?.finish(.pin, from: self) }
            case kVK_ANSI_Z: shift ? redo() : undo()
            case kVK_ANSI_A: selection = bounds; layoutToolbar(); needsDisplay = true
            default: break
            }
            return
        }

        if let tool = Tool.allCases.first(where: { $0.keyCode == code }) {
            editor.tool = tool
        } else if let digit = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                               kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9].firstIndex(of: code) {
            editor.colorIndex = digit
        }
    }

    private func nudge(code: Int, step: CGFloat, resize: Bool) {
        guard var r = selection else { return }
        let dx: CGFloat = code == kVK_LeftArrow ? -step : code == kVK_RightArrow ? step : 0
        let dy: CGFloat = code == kVK_UpArrow ? -step : code == kVK_DownArrow ? step : 0
        if resize {
            r.size.width = max(4, r.width + dx)
            r.size.height = max(4, r.height + dy)
        } else {
            r = r.offsetBy(dx: dx, dy: dy)
            r.origin.x = min(max(r.minX, 0), bounds.width - r.width)
            r.origin.y = min(max(r.minY, 0), bounds.height - r.height)
        }
        selection = r.intersection(bounds)
        layoutToolbar()
        needsDisplay = true
    }

    // MARK: Actions

    private func perform(_ action: EditorAction) {
        session?.activate(self)
        switch action {
        case .undo: undo()
        case .redo: redo()
        case .pin: session?.finish(.pin, from: self)
        case .saveAs: session?.finish(.saveAs, from: self)
        case .save: session?.finish(.save, from: self)
        case .copy: session?.finish(.copy, from: self)
        case .close: session?.finish(.cancel, from: self)
        }
        window?.makeFirstResponder(self)
    }

    private func undo() {
        commitText()
        guard let last = annotations.popLast() else { return }
        redoStack.append(last)
        needsDisplay = true
    }

    private func redo() {
        guard let a = redoStack.popLast() else { return }
        annotations.append(a)
        needsDisplay = true
    }

    // MARK: Text

    private func beginText(at p: CGPoint) {
        let font = NSFont.systemFont(ofSize: editor.fontSize, weight: .semibold)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let tv = AnnotationTextView(frame: CGRect(x: p.x, y: p.y - lineHeight / 2, width: 8, height: lineHeight))
        tv.font = font
        tv.textColor = editor.color
        tv.insertionPointColor = editor.color
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.isHorizontallyResizable = true
        tv.isVerticallyResizable = true
        tv.textContainer?.widthTracksTextView = false
        tv.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.minSize = CGSize(width: 8, height: lineHeight)
        tv.delegate = self
        tv.onCommit = { [weak self] in self?.commitText() }
        addSubview(tv, positioned: .below, relativeTo: toolbar)
        textView = tv
        window?.makeFirstResponder(tv)
    }

    func commitText() {
        guard let tv = textView else { return }
        textView = nil
        let text = tv.string
        let annotation = Annotation(shape: .text(text, tv.frame.origin, tv.font?.pointSize ?? editor.fontSize),
                                    color: tv.textColor ?? editor.color, width: editor.width)
        tv.removeFromSuperview()
        if annotation.isMeaningful {
            annotations.append(annotation)
            redoStack.removeAll()
        }
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    func textDidChange(_ notification: Notification) {
        textView?.sizeToFit()
    }

    // MARK: Toolbar placement

    private func layoutToolbar() {
        let creating: Bool = if case .creating = drag { true } else { false }
        guard let sel = selection, !creating else {
            toolbar.isHidden = true
            return
        }
        let size = toolbar.fittingSize
        let inset: CGFloat = 10 // the hosting view's shadow padding
        var x = sel.maxX - size.width + inset
        var y = sel.maxY - inset + 6
        if y + size.height > bounds.maxY {
            y = sel.minY - size.height + inset - 6
            if y < 0 { y = sel.maxY - size.height - 4 + inset }
        }
        x = min(max(x, 0), bounds.width - size.width)
        y = min(max(y, 0), bounds.height - size.height)
        toolbar.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
        toolbar.isHidden = false
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let creating: Bool = if case .creating = drag { true } else { false }

        // Dim everything except the focused region.
        let focus = selection ?? hoverRect
        ctx.setFillColor(dimColor.cgColor)
        if let focus {
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addRect(focus)
            ctx.addPath(path)
            ctx.fillPath(using: .evenOdd)
        } else {
            ctx.fill(bounds)
        }

        // Outline the hovered window — but not a (near) full-screen one, where it would just frame the display.
        if selection == nil, let hover = hoverRect,
           hover.width < bounds.width * 0.92 || hover.height < bounds.height * 0.92 {
            ctx.setStrokeColor(Theme.accent.cgColor)
            ctx.setLineWidth(2)
            ctx.addPath(CGPath(roundedRect: hover.insetBy(dx: 1, dy: 1), cornerWidth: 8, cornerHeight: 8, transform: nil))
            ctx.strokePath()
        }

        if let sel = selection {
            ctx.saveGState()
            ctx.clip(to: sel)
            let env = renderEnv
            for a in annotations { a.draw(in: ctx, env: env) }
            current?.draw(in: ctx, env: env)
            ctx.restoreGState()

            drawSelectionChrome(sel, in: ctx)
            drawSizeLabel(for: sel, in: ctx)
            if let hint = editor.hint, !toolbar.isHidden {
                drawTooltip(hint, in: ctx)
            }
        } else if mouse != nil {
            drawHint(in: ctx)
        }

        if Preferences.shared.showLoupe, let m = mouse, selection == nil || creating {
            drawLoupe(at: m, in: ctx)
        }
    }

    private var renderEnv: RenderEnv {
        RenderEnv(canvas: bounds, pixelated: { [weak self] in self?.pixelatedImage })
    }

    private func drawSelectionChrome(_ sel: CGRect, in ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(sel.insetBy(dx: -0.5, dy: -0.5))
        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        for (_, c) in handlePoints(sel) {
            let r = CGRect(x: c.x - 4.5, y: c.y - 4.5, width: 9, height: 9)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: r)
            ctx.setStrokeColor(Theme.accent.cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: r.insetBy(dx: 0.75, dy: 0.75))
        }
        ctx.restoreGState()
    }

    private func drawPill(_ text: String, at origin: CGPoint, in ctx: CGContext, font: NSFont) -> CGRect {
        let attr = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white])
        let size = attr.size()
        let rect = CGRect(x: origin.x, y: origin.y, width: size.width + 16, height: size.height + 8)
        ctx.saveGState()
        ctx.setFillColor(NSColor(white: 0.1, alpha: 0.85).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
        attr.draw(at: CGPoint(x: rect.minX + 8, y: rect.minY + 4))
        return rect
    }

    private func drawTooltip(_ hint: ToolbarHint, in ctx: CGContext) {
        let title = NSMutableAttributedString(string: hint.title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.white,
        ])
        if !hint.shortcut.isEmpty {
            title.append(NSAttributedString(string: "   " + hint.shortcut, attributes: [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.55),
            ]))
        }
        let size = title.size()
        let anchor = hint.anchor.offsetBy(dx: toolbar.frame.minX, dy: toolbar.frame.minY)
        var rect = CGRect(x: anchor.midX - (size.width + 20) / 2, y: anchor.minY - size.height - 10 - 14,
                          width: size.width + 20, height: size.height + 10)
        if rect.minY < 2 { rect.origin.y = anchor.maxY + 14 }
        rect.origin.x = min(max(rect.minX, 4), bounds.width - rect.width - 4)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 8, color: NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.setFillColor(NSColor(white: 0.08, alpha: 0.95).cgColor)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
        title.draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 5))
    }

    private func drawSizeLabel(for sel: CGRect, in ctx: CGContext) {
        let s = snapshot.scale
        let text = "\(Int((sel.width * s).rounded())) × \(Int((sel.height * s).rounded()))"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let height: CGFloat = 22
        var y = sel.minY - height - 6
        if y < 2 { y = sel.minY + 6 }
        _ = drawPill(text, at: CGPoint(x: max(sel.minX, 2), y: y), in: ctx, font: font)
    }

    private func drawHint(in ctx: CGContext) {
        let text = L("overlay.hint")
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let w = NSAttributedString(string: text, attributes: [.font: font]).size().width + 16
        _ = drawPill(text, at: CGPoint(x: (bounds.width - w) / 2, y: 60), in: ctx, font: font)
    }

    private func drawLoupe(at p: CGPoint, in ctx: CGContext) {
        let s = snapshot.scale
        let cells = 15, zoom: CGFloat = 8
        let side = CGFloat(cells) * zoom
        let px = Int(p.x * s), py = Int(p.y * s)
        let src = CGRect(x: px - cells / 2, y: py - cells / 2, width: cells, height: cells)
        let imageBounds = CGRect(x: 0, y: 0, width: snapshot.image.width, height: snapshot.image.height)
        let visible = src.intersection(imageBounds)

        var origin = CGPoint(x: p.x + 24, y: p.y + 24)
        if origin.x + side > bounds.maxX - 4 { origin.x = p.x - 24 - side }
        if origin.y + side + 30 > bounds.maxY - 4 { origin.y = p.y - 24 - side - 30 }
        let box = CGRect(origin: origin, size: CGSize(width: side, height: side))
        let clip = CGPath(roundedRect: box, cornerWidth: 12, cornerHeight: 12, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 12, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.addPath(clip)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        if !visible.isNull, let crop = snapshot.image.cropping(to: visible) {
            let dest = CGRect(x: box.minX + (visible.minX - src.minX) * zoom,
                              y: box.minY + (visible.minY - src.minY) * zoom,
                              width: visible.width * zoom, height: visible.height * zoom)
            ctx.interpolationQuality = .none
            Geometry.drawImage(crop, in: dest, ctx: ctx)
        }
        // Grid
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        ctx.setLineWidth(1)
        for i in 1..<cells {
            let o = CGFloat(i) * zoom
            ctx.move(to: CGPoint(x: box.minX + o, y: box.minY)); ctx.addLine(to: CGPoint(x: box.minX + o, y: box.maxY))
            ctx.move(to: CGPoint(x: box.minX, y: box.minY + o)); ctx.addLine(to: CGPoint(x: box.maxX, y: box.minY + o))
        }
        ctx.strokePath()
        // Center pixel
        let center = CGRect(x: box.minX + CGFloat(cells / 2) * zoom, y: box.minY + CGFloat(cells / 2) * zoom,
                            width: zoom, height: zoom)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(center.insetBy(dx: -0.75, dy: -0.75))
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(center.insetBy(dx: -2, dy: -2))
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1)
        ctx.addPath(CGPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.strokePath()
        ctx.restoreGState()

        let label = "\(Int(p.x)), \(Int(p.y))   \(hexColor(x: px, y: py))"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        let w = NSAttributedString(string: label, attributes: [.font: font]).size().width + 16
        _ = drawPill(label, at: CGPoint(x: box.midX - w / 2, y: box.maxY + 6), in: ctx, font: font)
    }

    private func hexColor(x: Int, y: Int) -> String {
        if let c = pixelCache, c.x == x, c.y == y { return c.hex }
        var hex = "—"
        if let crop = snapshot.image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) {
            var pixel = [UInt8](repeating: 0, count: 4)
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            pixel.withUnsafeMutableBytes { buf in
                if let c = CGContext(data: buf.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                     space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                    c.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
            }
            hex = String(format: "#%02X%02X%02X", pixel[0], pixel[1], pixel[2])
        }
        pixelCache = (x, y, hex)
        return hex
    }

    private func makePixelated() -> CGImage? {
        let input = CIImage(cgImage: snapshot.image)
        let filter = CIFilter.pixellate()
        filter.inputImage = input.clampedToExtent()
        filter.scale = Float(11 * snapshot.scale)
        filter.center = .zero
        guard let output = filter.outputImage?.cropped(to: input.extent) else { return nil }
        return CIContext().createCGImage(output, from: input.extent)
    }

    // MARK: Export

    /// Selection in points, snapped to whole device pixels.
    var pixelSelection: CGRect? {
        guard let sel = selection else { return nil }
        let s = snapshot.scale
        return CGRect(x: (sel.minX * s).rounded(), y: (sel.minY * s).rounded(),
                      width: (sel.width * s).rounded(), height: (sel.height * s).rounded())
    }

    func renderImage() -> CGImage? {
        guard let px = pixelSelection, px.width >= 1, px.height >= 1,
              let crop = snapshot.image.cropping(to: px) else { return nil }
        if annotations.isEmpty { return crop }

        let s = snapshot.scale
        let width = Int(px.width), height = Int(px.height)
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: snapshot.image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: bitmapInfo)
            ?? CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: bitmapInfo)
        else { return nil }

        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Switch to the flipped, point-based coordinate space the annotations use.
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: s, y: -s)
        ctx.translateBy(x: -px.minX / s, y: -px.minY / s)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
        let env = renderEnv
        for a in annotations { a.draw(in: ctx, env: env) }
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }

    /// Selection rect in global Cocoa coordinates (for pinning in place).
    var globalSelectionFrame: CGRect? {
        guard let sel = selection else { return nil }
        let sf = snapshot.screen.frame
        return CGRect(x: sf.minX + sel.minX, y: sf.maxY - sel.maxY, width: sel.width, height: sel.height)
    }
}

/// Re-positions itself whenever SwiftUI content changes size (e.g. the style bar appears).
final class ToolbarHost: NSHostingView<EditorToolbar> {
    var onSizeChange: (() -> Void)?

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isHidden, self.fittingSize != self.frame.size else { return }
            self.onSizeChange?()
        }
    }
}

// MARK: - Text editing view

final class AnnotationTextView: NSTextView {
    var onCommit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturn = Int(event.keyCode) == kVK_Return || Int(event.keyCode) == kVK_ANSI_KeypadEnter
        if Int(event.keyCode) == kVK_Escape || (isReturn && event.modifierFlags.contains(.command)) {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1
        path.setLineDash([4, 3], count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.7).setStroke()
        path.stroke()
    }

    override var frame: NSRect {
        didSet { superview?.setNeedsDisplay(frame.insetBy(dx: -8, dy: -8)) }
    }
}
