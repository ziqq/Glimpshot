import AppKit
import Combine
import SwiftUI
import os

let log = Logger(subsystem: "com.ziqq.snaply", category: "app")

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
        UpdateChecker.shared.checkInBackgroundIfNeeded()
    }

    // MARK: Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        Preferences.shared.$menuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] raw in
                self?.statusItem.button?.image = (MenuBarIcon(rawValue: raw) ?? .eye).image
            }
            .store(in: &cancellables)

        let menu = NSMenu()
        menu.delegate = self
        areaItem = item(L("menu.captureArea"), #selector(captureArea), symbol: "rectangle.dashed")
        fullItem = item(L("menu.captureScreen"), #selector(captureFull), symbol: "macwindow")
        menu.addItem(areaItem)
        menu.addItem(fullItem)
        menu.addItem(.separator())
        menu.addItem(item(L("menu.history"), #selector(showHistory), key: "h", symbol: "clock"))
        menu.addItem(item(L("menu.openFolder"), #selector(openFolder), symbol: "folder"))
        menu.addItem(.separator())
        menu.addItem(item(L("menu.settings"), #selector(showSettings), key: ",", symbol: "gearshape"))
        menu.addItem(item(L("menu.about", AppInfo.name), #selector(showAbout)))
        menu.addItem(item(L("menu.quit", AppInfo.name), #selector(quit), key: "q"))
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
        log.info("capture requested, preflight=\(ScreenCapturer.hasPermission, privacy: .public)")
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
                log.error("capture failed: \(String(describing: error), privacy: .public)")
                askForPermission(error: error)
            }
        }
    }

    private func askForPermission(error: Error) {
        let alert = NSAlert()
        alert.messageText = L("perm.title")
        alert.informativeText = L("perm.body", AppInfo.name, error.localizedDescription)
        alert.addButton(withTitle: L("perm.openSettings"))
        alert.addButton(withTitle: L("perm.relaunch", AppInfo.name))
        alert.addButton(withTitle: L("perm.later"))
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            AppDelegate.relaunch()
        default:
            break
        }
    }

    static func relaunch() {
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
            w.title = L("window.history")
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
            w.title = L("window.settings", AppInfo.name)
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

    @objc private func showAbout() { AppDelegate.showAboutPanel() }

    static func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: L("about.tagline"),
                                         attributes: [.font: NSFont.systemFont(ofSize: 11),
                                                      .foregroundColor: NSColor.secondaryLabelColor]),
        ])
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
