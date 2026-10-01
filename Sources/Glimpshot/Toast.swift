import AppKit
import SwiftUI

/// Floating preview in the corner after a capture. Click reveals the file, drag drops it into other apps.
@MainActor
enum Toast {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func show(image: NSImage, title: String, url: URL?) {
        dismiss(animated: false)

        let view = ToastView(image: image, title: title, url: url,
                             onHover: { hovering in hovering ? cancelHide() : scheduleHide(after: 2) },
                             onClose: { dismiss(animated: true) })
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        let screen = NSScreen.underMouse ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let frame = CGRect(x: vf.maxX - size.width, y: vf.minY, width: size.width, height: size.height)

        let p = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = host
        p.alphaValue = 0
        p.setFrame(frame.offsetBy(dx: 0, dy: -12), display: false)
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            p.animator().alphaValue = 1
            p.animator().setFrame(frame, display: true)
        }
        panel = p
        scheduleHide(after: 4)
    }

    private static func cancelHide() {
        hideWork?.cancel()
        hideWork = nil
    }

    private static func scheduleHide(after seconds: Double) {
        cancelHide()
        let work = DispatchWorkItem { Task { @MainActor in dismiss(animated: true) } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    static func dismiss(animated: Bool) {
        cancelHide()
        guard let p = panel else { return }
        panel = nil
        guard animated else { p.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            p.animator().alphaValue = 0
        }, completionHandler: { p.orderOut(nil) })
    }
}

private struct ToastView: View {
    let image: NSImage
    let title: String
    let url: URL?
    let onHover: (Bool) -> Void
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 88, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(url?.lastPathComponent ?? "\(Int(image.size.width)) × \(Int(image.size.height)) pt")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if url != nil {
                    Text(L("toast.reveal"))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .overlay(alignment: .topLeading) {
            if hovering {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: -6)
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(18)
        .contentShape(Rectangle())
        .onHover { hovering = $0; onHover($0) }
        .onTapGesture {
            if let url { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            onClose()
        }
        .onDrag {
            if let url, let provider = NSItemProvider(contentsOf: url) { return provider }
            return NSItemProvider(object: image)
        }
    }
}
