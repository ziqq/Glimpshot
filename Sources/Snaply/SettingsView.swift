import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Горячие клавиши") {
                LabeledContent("Снимок области") { ShortcutRecorder(shortcut: $prefs.areaShortcut) }
                LabeledContent("Снимок всего экрана") { ShortcutRecorder(shortcut: $prefs.fullShortcut) }
            }

            Section("Сохранение") {
                LabeledContent("Папка") {
                    HStack(spacing: 8) {
                        Text(prefs.saveFolder.abbreviatedPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Выбрать…", action: chooseFolder)
                    }
                }
                Picker("Формат", selection: $prefs.format) {
                    ForEach(ImageFormat.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Копировать в буфер при сохранении", isOn: $prefs.copyOnSave)
            }

            Section("Поведение") {
                Toggle("Звук затвора", isOn: $prefs.playSound)
                Toggle("Лупа при выделении", isOn: $prefs.showLoupe)
                Toggle("Превью в углу после снимка", isOn: $prefs.showPreview)
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Клавиши в редакторе") {
                VStack(alignment: .leading, spacing: 6) {
                    hint("↩  ⌘C", "копировать и закрыть")
                    hint("⌘S  ⇧⌘S", "сохранить в папку / как…")
                    hint("⌘P", "закрепить поверх окон")
                    hint("⌘Z  ⇧⌘Z", "отменить / повторить")
                    hint("V P L A R O M T B N", "инструменты")
                    hint("1…9", "цвет")
                    hint("⇧ + рисование", "ровные линии, квадрат, круг")
                    hint("← ↑ → ↓", "сдвиг рамки (⇧ ×10, ⌥ — размер)")
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
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
        panel.prompt = "Выбрать"
        if panel.runModal() == .OK, let url = panel.url {
            prefs.saveFolder = url
        }
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(recording ? "Нажмите сочетание…" : shortcut?.displayString ?? "Не задано")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(minWidth: 130)
                    .foregroundStyle(recording ? Color.accentColor : .primary)
            }
            if shortcut != nil && !recording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Отключить")
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
