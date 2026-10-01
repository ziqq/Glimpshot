import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            aboutHeader

            Section(L("settings.hotkeys")) {
                LabeledContent(L("menu.captureArea")) { ShortcutRecorder(shortcut: $prefs.areaShortcut) }
                LabeledContent(L("menu.captureScreen")) { ShortcutRecorder(shortcut: $prefs.fullShortcut) }
            }

            Section(L("settings.saving")) {
                LabeledContent(L("settings.folder")) {
                    HStack(spacing: 8) {
                        Text(prefs.saveFolder.abbreviatedPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button(L("settings.choose"), action: chooseFolder)
                    }
                }
                Picker(L("settings.format"), selection: $prefs.format) {
                    ForEach(ImageFormat.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle(L("settings.copyOnSave"), isOn: $prefs.copyOnSave)
            }

            Section(L("settings.appearance")) {
                LabeledContent(L("settings.accent")) { AccentPicker(selection: $prefs.accentIndex) }
                LabeledContent(L("settings.menuBarIcon")) { MenuBarIconPicker(selection: $prefs.menuBarIcon) }
                Picker(L("settings.language"), selection: $prefs.language) {
                    Text(L("settings.languageSystem")).tag("")
                    Divider()
                    ForEach(AppLanguage.all) { Text($0.name).tag($0.code) }
                }
                if prefs.language != prefs.launchLanguage {
                    HStack {
                        Text(L("settings.languageRestart")).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("settings.relaunchNow")) { AppDelegate.relaunch() }
                    }
                }
            }

            Section(L("settings.behavior")) {
                Toggle(L("settings.sound"), isOn: $prefs.playSound)
                Toggle(L("settings.loupe"), isOn: $prefs.showLoupe)
                Toggle(L("settings.preview"), isOn: $prefs.showPreview)
                Toggle(L("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section(L("settings.updates")) {
                Toggle(L("updates.auto"), isOn: $prefs.autoCheckUpdates)
                HStack(spacing: 10) {
                    Button(L("updates.checkNow")) { Task { await updates.check() } }
                        .disabled(updates.state == .checking)
                    updateStatus
                    Spacer()
                }
            }

            Section(L("settings.editorKeys")) {
                VStack(alignment: .leading, spacing: 6) {
                    hint("↩  ⌘C", L("hint.copy"))
                    hint("⌘S  ⇧⌘S", L("hint.save"))
                    hint("⌘P", L("hint.pin"))
                    hint("⌘Z  ⇧⌘Z", L("hint.undo"))
                    hint("V P L A R O M T B N", L("hint.tools"))
                    hint("1…9", L("hint.colors"))
                    hint(L("hint.shiftKeys"), L("hint.shift"))
                    hint("← ↑ → ↓", L("hint.arrows"))
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .tint(Theme.accentColor)
        .frame(width: 500)
        .frame(minHeight: 560, idealHeight: 720)
    }

    private var aboutHeader: some View {
        Section {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.name).font(.title2.weight(.semibold))
                    Text(L("about.version", AppInfo.version)).foregroundStyle(.secondary)
                    Text(L("about.tagline")).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Button(L("menu.about", AppInfo.name)) { AppDelegate.showAboutPanel() }
                    Button(L("menu.quit", AppInfo.name), role: .destructive) { NSApp.terminate(nil) }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updates.state {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView().controlSize(.small)
            Text(L("updates.checking")).foregroundStyle(.secondary)
        case .upToDate:
            Label(L("updates.upToDate", AppInfo.version), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
        case let .available(version, url):
            Text(L("updates.available", version)).foregroundStyle(Theme.accentColor)
            Button(L("updates.download")) { NSWorkspace.shared.open(url) }
        case .failed:
            Label(L("updates.failed"), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }

    private func hint(_ keys: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(keys).font(.system(.callout, design: .rounded).weight(.semibold)).frame(width: 150, alignment: .leading)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.saveFolder
        panel.prompt = L("settings.choose")
        if panel.runModal() == .OK, let url = panel.url {
            prefs.saveFolder = url
        }
    }
}

private struct MenuBarIconPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MenuBarIcon.allCases) { icon in
                Button {
                    selection = icon.rawValue
                } label: {
                    Image(nsImage: icon.image)
                        .renderingMode(.template)
                        .frame(width: 30, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == icon.rawValue ? Theme.accentColor.opacity(0.25) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(selection == icon.rawValue ? Theme.accentColor : .clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AccentPicker: View {
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 6) {
            swatch(index: -1, fill: AnyShapeStyle(AngularGradient(
                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center)))
                .help(L("settings.languageSystem"))
            ForEach(Theme.accents.indices, id: \.self) { i in
                swatch(index: i, fill: AnyShapeStyle(Color(nsColor: Theme.accents[i])))
            }
        }
    }

    private func swatch(index: Int, fill: AnyShapeStyle) -> some View {
        Button {
            selection = index
        } label: {
            ZStack {
                Circle().fill(fill).frame(width: 16, height: 16)
                if selection == index {
                    Circle().fill(Color.white).frame(width: 6, height: 6)
                }
            }
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(Color.primary.opacity(selection == index ? 0.35 : 0), lineWidth: 1.5))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(recording ? L("recorder.prompt") : shortcut?.displayString ?? L("recorder.none"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(minWidth: 130)
                    .foregroundStyle(recording ? Theme.accentColor : .primary)
            }
            if shortcut != nil && !recording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(L("recorder.clear"))
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() { recording ? stop() : start() }

    private func start() {
        recording = true
        Preferences.shared.isRecordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let code = UInt32(event.keyCode)
            if code == UInt32(kVK_Escape) {
                stop()
                return nil
            }
            let mods = event.modifierFlags.intersection(Shortcut.relevant)
            let hasModifier = !mods.subtracting(.shift).isEmpty
            guard hasModifier || KeyNames.isFunctionKey(code) else {
                NSSound.beep()
                return nil
            }
            shortcut = Shortcut(keyCode: code, modifiers: mods)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { Preferences.shared.isRecordingShortcut = false }
        recording = false
    }
}
