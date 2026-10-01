import AppKit
import UniformTypeIdentifiers

enum FinishAction { case copy, save, saveAs, pin, cancel }

/// One capture: an overlay per display, shared tool state, and the final action.
@MainActor
final class CaptureSession {
    private var windows: [OverlayWindow] = []
    private let editor = EditorState()
    private let onEnd: () -> Void
    private(set) weak var activeView: OverlayView?

    init(snapshots: [ScreenSnapshot], windowFrames: [CGRect], onEnd: @escaping () -> Void) {
        self.onEnd = onEnd
        for snap in snapshots {
            let rects = ScreenCapturer.localRects(windowFrames, on: snap.screen)
            windows.append(OverlayWindow(snapshot: snap, windowRects: rects, editor: editor, session: self))
        }
    }

    func begin() {
        NSApp.activate(ignoringOtherApps: true)
        let mouse = NSEvent.mouseLocation
        let key = windows.first { NSMouseInRect(mouse, $0.frame, false) } ?? windows.first
        for w in windows {
            w.alphaValue = 0
            w.orderFrontRegardless()
        }
        key?.makeKeyAndOrderFront(nil)
        key?.makeFirstResponder(key?.overlay)
        activeView = key?.overlay
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            for w in windows { w.animator().alphaValue = 1 }
        }
        // Pretend the mouse just moved so hover/loupe show up immediately.
        for w in windows {
            let local = w.convertPoint(fromScreen: mouse)
            if let e = NSEvent.mouseEvent(with: .mouseMoved, location: local, modifierFlags: [], timestamp: 0,
                                          windowNumber: w.windowNumber, context: nil, eventNumber: 0,
                                          clickCount: 0, pressure: 0), w.frame.contains(mouse) {
                w.overlay.mouseMoved(with: e)
            }
        }
    }

    func activate(_ view: OverlayView) {
        guard activeView !== view else { return }
        for w in windows where w.overlay !== view { w.overlay.resetSelection() }
        activeView = view
        view.window?.makeKey()
    }

    func finish(_ action: FinishAction, from view: OverlayView) {
        view.commitText()
        let image = action == .cancel ? nil : view.renderImage()
        let scale = view.snapshot.scale
        let pinFrame = view.globalSelectionFrame
        close()
        guard let image else { return }

        switch action {
        case .copy:
            Exporter.copy(image, scale: scale)
            Exporter.feedback(image, scale: scale, title: L("toast.copied"), url: nil)
        case .save:
            Exporter.saveToFolder(image, scale: scale)
        case .saveAs:
            Exporter.saveAs(image, scale: scale)
        case .pin:
            PinPanel.show(image: image, scale: scale, frame: pinFrame)
        case .cancel:
            break
        }
    }

    private func close() {
        for w in windows {
            w.orderOut(nil)
            w.close()
        }
        windows.removeAll()
        onEnd()
    }
}

// MARK: - Export

@MainActor
enum Exporter {
    static func encode(_ image: CGImage, scale: CGFloat, format: ImageFormat) -> Data? {
        let data = NSMutableData()
        let type = (format == .png ? UTType.png : UTType.jpeg).identifier as CFString
        guard let dest = CGImageDestinationCreateWithData(data, type, 1, nil) else { return nil }
        let props: [CFString: Any] = [
            kCGImagePropertyDPIWidth: 72 * scale,
            kCGImagePropertyDPIHeight: 72 * scale,
            kCGImageDestinationLossyCompressionQuality: 0.92,
        ]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    static func copy(_ image: CGImage, scale: CGFloat) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let item = NSPasteboardItem()
        if let png = encode(image, scale: scale, format: .png) { item.setData(png, forType: .png) }
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        if let tiff = rep.tiffRepresentation { item.setData(tiff, forType: .tiff) }
        pb.writeObjects([item])
    }

    static func nextFileURL(in folder: URL, ext: String) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let base = "\(AppInfo.name) \(f.string(from: Date()))"
        var url = folder.appendingPathComponent("\(base).\(ext)")
        var i = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) (\(i)).\(ext)")
            i += 1
        }
        return url
    }

    @discardableResult
    static func write(_ image: CGImage, scale: CGFloat, to url: URL) throws -> URL {
        let format: ImageFormat = ["jpg", "jpeg"].contains(url.pathExtension.lowercased()) ? .jpg : .png
        guard let data = encode(image, scale: scale, format: format) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        NotificationCenter.default.post(name: .glimpshotDidSave, object: url)
        return url
    }

    static func saveToFolder(_ image: CGImage, scale: CGFloat) {
        let prefs = Preferences.shared
        let url = nextFileURL(in: prefs.saveFolder, ext: prefs.format.rawValue)
        do {
            try write(image, scale: scale, to: url)
            if prefs.copyOnSave { copy(image, scale: scale) }
            feedback(image, scale: scale, title: prefs.copyOnSave ? L("toast.savedCopied") : L("toast.saved"), url: url)
        } catch {
            showError(error)
        }
    }

    static func saveAs(_ image: CGImage, scale: CGFloat) {
        let prefs = Preferences.shared
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.saveFolder
        panel.nameFieldStringValue = nextFileURL(in: prefs.saveFolder, ext: prefs.format.rawValue).lastPathComponent
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try write(image, scale: scale, to: url)
            feedback(image, scale: scale, title: L("toast.saved"), url: url)
        } catch {
            showError(error)
        }
    }

    static func feedback(_ image: CGImage, scale: CGFloat, title: String, url: URL?) {
        let prefs = Preferences.shared
        if prefs.playSound { Sound.shutter() }
        if prefs.showPreview {
            let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
            Toast.show(image: NSImage(cgImage: image, size: size), title: title, url: url)
        }
    }

    static func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

enum Sound {
    private static let systemShutter = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"

    static func shutter() {
        let sound = FileManager.default.fileExists(atPath: systemShutter)
            ? NSSound(contentsOfFile: systemShutter, byReference: true)
            : NSSound(named: "Tink")
        sound?.volume = 0.6
        sound?.play()
    }
}
