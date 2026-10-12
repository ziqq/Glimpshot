// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

import AppKit
import Carbon.HIToolbox

/// A screenshot pinned above all windows. Drag to move, scroll to zoom, double-click or ⎋ to close.
final class PinPanel: NSPanel {
    private static var open: Set<PinPanel> = []

    let image: CGImage
    let scale: CGFloat
    private let baseSize: CGSize
    private var zoom: CGFloat = 1

    @MainActor
    static func show(image: CGImage, scale: CGFloat, frame: CGRect?) {
        let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        let rect: CGRect
        if let frame {
            rect = frame
        } else {
            let vf = (NSScreen.underMouse ?? NSScreen.screens[0]).visibleFrame
            let fit = min(1, (vf.width * 0.6) / size.width, (vf.height * 0.6) / size.height)
            let s = CGSize(width: size.width * fit, height: size.height * fit)
            rect = CGRect(x: vf.midX - s.width / 2, y: vf.midY - s.height / 2, width: s.width, height: s.height)
        }
        let panel = PinPanel(image: image, scale: scale, frame: rect, baseSize: size)
        open.insert(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
    }

    private init(image: CGImage, scale: CGFloat, frame: CGRect, baseSize: CGSize) {
        self.image = image
        self.scale = scale
        self.baseSize = baseSize
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        zoom = frame.width / baseSize.width
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = PinView(panel: self)
    }

    override var canBecomeKey: Bool { true }

    func closePin() {
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.12; animator().alphaValue = 0 },
                                            completionHandler: { [self] in
            orderOut(nil)
            PinPanel.open.remove(self)
        })
    }

    func zoom(by factor: CGFloat) {
        let newZoom = min(max(zoom * factor, 0.15), 6)
        guard newZoom != zoom else { return }
        zoom = newZoom
        let size = CGSize(width: baseSize.width * zoom, height: baseSize.height * zoom)
        let c = CGPoint(x: frame.midX, y: frame.midY)
        setFrame(CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height),
                 display: true)
    }

    func resetZoom() {
        zoom(by: 1 / zoom)
    }
}

private final class PinView: NSView {
    unowned let panel: PinPanel

    init(panel: PinPanel) {
        self.panel = panel
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contents = panel.image
        layer?.contentsGravity = .resize
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        layer?.minificationFilter = .trilinear
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            panel.closePin()
        } else {
            window?.performDrag(with: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 200 : event.scrollingDeltaY / 20
        panel.zoom(by: 1 + delta)
    }

    override func magnify(with event: NSEvent) {
        panel.zoom(by: 1 + event.magnification)
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        switch Int(event.keyCode) {
        case kVK_Escape: panel.closePin()
        case kVK_ANSI_C where cmd: MainActor.assumeIsolated { Exporter.copy(panel.image, scale: panel.scale) }
        case kVK_ANSI_S where cmd: MainActor.assumeIsolated { Exporter.saveToFolder(panel.image, scale: panel.scale) }
        case kVK_ANSI_0 where cmd: panel.resetZoom()
        default: super.keyDown(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: L("action.copy"), action: #selector(copyImage), keyEquivalent: "c").target = self
        menu.addItem(withTitle: L("action.save"), action: #selector(save), keyEquivalent: "s").target = self
        menu.addItem(withTitle: L("action.saveAs"), action: #selector(saveAs), keyEquivalent: "").target = self
        menu.addItem(withTitle: L("pin.actualSize"), action: #selector(resetZoom), keyEquivalent: "0").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("action.close"), action: #selector(closePin), keyEquivalent: "").target = self
        return menu
    }

    @objc private func copyImage() {
        MainActor.assumeIsolated {
            Exporter.copy(panel.image, scale: panel.scale)
            Exporter.feedback(panel.image, scale: panel.scale, title: L("toast.copied"), url: nil)
        }
    }

    @objc private func save() { MainActor.assumeIsolated { Exporter.saveToFolder(panel.image, scale: panel.scale) } }
    @objc private func saveAs() { MainActor.assumeIsolated { Exporter.saveAs(panel.image, scale: panel.scale) } }
    @objc private func resetZoom() { panel.resetZoom() }
    @objc private func closePin() { panel.closePin() }
}
