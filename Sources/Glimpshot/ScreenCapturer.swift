import AppKit
import ScreenCaptureKit

struct ScreenSnapshot {
    let screen: NSScreen
    let image: CGImage
    /// Pixels per point.
    var scale: CGFloat { CGFloat(image.width) / screen.frame.width }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static var underMouse: NSScreen? {
        let p = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(p, $0.frame, false) } ?? main
    }
}

@MainActor
enum ScreenCapturer {
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    /// Freezes every display at native resolution.
    static func captureAll(only screens: [NSScreen] = NSScreen.screens) async throws -> [ScreenSnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        var result: [ScreenSnapshot] = []
        for screen in screens {
            guard let id = screen.displayID,
                  let display = content.displays.first(where: { $0.displayID == id }) else { continue }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            let scale = CGFloat(filter.pointPixelScale)
            config.width = Int((filter.contentRect.width * scale).rounded())
            config.height = Int((filter.contentRect.height * scale).rounded())
            config.showsCursor = false
            config.captureResolution = .best
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            result.append(ScreenSnapshot(screen: screen, image: image))
        }
        return result
    }

    /// Frames of normal app windows, front to back, in CG global coordinates (top-left origin).
    static func windowFrames() -> [CGRect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        let pid = ProcessInfo.processInfo.processIdentifier
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? pid_t) != pid,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.01,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict),
                  rect.width >= 40, rect.height >= 40 else { return nil }
            return rect
        }
    }

    /// Converts CG global rects into a screen-local, top-left-origin coordinate space.
    static func localRects(_ rects: [CGRect], on screen: NSScreen) -> [CGRect] {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let sf = screen.frame
        let bounds = CGRect(origin: .zero, size: sf.size)
        return rects.compactMap { r in
            let local = CGRect(x: r.minX - sf.minX, y: r.minY + sf.maxY - primaryHeight,
                               width: r.width, height: r.height)
            let clipped = local.intersection(bounds)
            return clipped.isNull || clipped.width < 20 || clipped.height < 20 ? nil : clipped
        }
    }
}
