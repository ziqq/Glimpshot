import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum HotKey: UInt32 { case area = 1, full = 2 }

    private var statusItem: NSStatusItem!
    private var areaItem: NSMenuItem!
    private var fullItem: NSMenuItem!
    private var session: CaptureSession?
    private var isCapturing = false
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?
    private let history = HistoryModel()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

        let prefs = Preferences.shared
        Publishers.CombineLatest3(prefs.$areaShortcut, prefs.$fullShortcut, prefs.$isRecordingShortcut)
            .receive(on: RunLoop.main)
            .sink { [weak self] area, full, recording in
                self?.registerHotKeys(area: area, full: full, paused: recording)
            }
            .store(in: &cancellables)

        if !UserDefaults.standard.bool(forKey: "didOnboard") {
            UserDefaults.standard.set(true, forKey: "didOnboard")
            if !ScreenCapturer.hasPermission { CGRequestScreenCaptureAccess() }
        }
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Snaply")
        image?.isTemplate = true
        statusItem.button?.image = image

        let menu = NSMenu()
        menu.delegate = self
        areaItem = item("Снимок области", #selector(captureArea), symbol: "rectangle.dashed")
        fullItem = item("Снимок всего экрана", #selector(captureFull), symbol: "macwindow")
        menu.addItem(areaItem)
        menu.addItem(fullItem)
        menu.addItem(.separator())
        menu.addItem(item("История…", #selector(showHistory), key: "h", symbol: "clock"))
        menu.addItem(item("Открыть папку со снимками", #selector(openFolder), symbol: "folder"))
        menu.addItem(.separator())
        menu.addItem(item("Настройки…", #selector(showSettings), key: ",", symbol: "gearshape"))
        menu.addItem(item("О Snaply", #selector(showAbout)))
        menu.addItem(item("Выйти", #selector(quit), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return item
    }

    private func apply(_ shortcut: Shortcut?, to item: NSMenuItem) {
        item.keyEquivalent = shortcut?.menuKeyEquivalent ?? ""
        item.keyEquivalentModifierMask = shortcut?.flags ?? []
    }

    // MARK: Hotkeys

    private func registerHotKeys(area: Shortcut?, full: Shortcut?, paused: Bool) {
        apply(area, to: areaItem)
        apply(full, to: fullItem)
        let center = HotKeyCenter.shared
        guard !paused else {
            center.unregisterAll()
            return
        }
        let okArea = center.register(id: HotKey.area.rawValue, shortcut: area) { [weak self] in self?.startCapture(fullScreen: false) }
        let okFull = center.register(id: HotKey.full.rawValue, shortcut: full) { [weak self] in self?.startCapture(fullScreen: true) }
        if !okArea || !okFull {
            let taken = [okArea ? nil : area?.displayString, okFull ? nil : full?.displayString].compactMap { $0 }
            NSLog("Snaply: hotkey already in use: \(taken)")
        }
    }

    // MARK: Capture

    @objc private func captureArea() { startAfterMenuCloses(fullScreen: false) }
    @objc private func captureFull() { startAfterMenuCloses(fullScreen: true) }

    private func startAfterMenuCloses(fullScreen: Bool) {
        // Give the menu time to fade out so it doesn't end up in the frozen frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startCapture(fullScreen: fullScreen)
        }
    }

    private func startCapture(fullScreen: Bool) {
        guard session == nil, !isCapturing else { return }
        guard ScreenCapturer.hasPermission else {
            askForPermission()
            return
        }
        isCapturing = true
        Toast.dismiss(animated: false)
        let frames = ScreenCapturer.windowFrames()
        let screens = fullScreen ? [NSScreen.underMouse].compactMap { $0 } : NSScreen.screens

        Task { @MainActor in
            defer { isCapturing = false }
            do {
                let snapshots = try await ScreenCapturer.captureAll(only: screens)
                guard !snapshots.isEmpty else { return }
                if fullScreen, let snap = snapshots.first {
                    Exporter.saveToFolder(snap.image, scale: snap.scale)
                    return
                }
                let session = CaptureSession(snapshots: snapshots, windowFrames: frames) { [weak self] in
                    self?.session = nil
                }
                self.session = session
                session.begin()
            } catch {
                if !ScreenCapturer.hasPermission { askForPermission() } else { Exporter.showError(error) }
            }
        }
    }

    private func askForPermission() {
        let alert = NSAlert()
        alert.messageText = "Нужен доступ к записи экрана"
        alert.informativeText = """
        Откройте «Системные настройки» → «Конфиденциальность и безопасность» → «Запись экрана и системного звука», \
        включите Snaply и перезапустите приложение.
        """
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "Перезапустить Snaply")
        alert.addButton(withTitle: "Позже")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            CGRequestScreenCaptureAccess()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            relaunch()
        default:
            break
        }
    }

    private func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; /usr/bin/open \"\(Bundle.main.bundlePath)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: Windows

    @objc private func showHistory() {
        if historyWindow == nil {
            let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 820, height: 560),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = "История снимков"
            w.contentViewController = NSHostingController(rootView: HistoryView(model: history))
            w.setContentSize(CGSize(width: 820, height: 560))
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("SnaplyHistory")
            w.center()
            historyWindow = w
        }
        history.reload()
        present(historyWindow)
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Настройки Snaply"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        present(settingsWindow)
    }

    private func present(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openFolder() {
        let folder = Preferences.shared.saveFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "Быстрые скриншоты с аннотациями.\nВсё хранится локально.",
                                         attributes: [.font: NSFont.systemFont(ofSize: 11),
                                                      .foregroundColor: NSColor.secondaryLabelColor]),
        ])
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
