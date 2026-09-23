import AppKit
import Carbon.HIToolbox
import Combine

// MARK: - Shortcut

struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt

    static let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Shortcut.relevant).rawValue
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    var symbols: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }

    var displayString: String { symbols + KeyNames.name(for: keyCode) }

    /// Key equivalent for NSMenuItem (only for printable single-character keys).
    var menuKeyEquivalent: String {
        let name = KeyNames.name(for: keyCode)
        return name.count == 1 ? name.lowercased() : ""
    }

    static let defaultArea = Shortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: [.command, .shift])
    static let defaultFull = Shortcut(keyCode: UInt32(kVK_ANSI_1), modifiers: [.command, .shift])
}

enum KeyNames {
    private static let special: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19",
    ]

    static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        (special[Int(keyCode)] ?? "").hasPrefix("F") && special[Int(keyCode)]!.count > 1
    }

    static func name(for keyCode: UInt32) -> String {
        if let s = special[Int(keyCode)] { return s }
        // Always resolve through an ASCII-capable layout so Cyrillic layouts show Latin keys.
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                  UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                  &deadKeyState, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}

// MARK: - Preferences

enum ImageFormat: String, CaseIterable, Identifiable {
    case png, jpg
    var id: String { rawValue }
    var title: String { self == .png ? "PNG" : "JPEG" }
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    @Published var saveFolder: URL { didSet { defaults.set(saveFolder.path, forKey: "saveFolder") } }
    @Published var format: ImageFormat { didSet { defaults.set(format.rawValue, forKey: "format") } }
    @Published var copyOnSave: Bool { didSet { defaults.set(copyOnSave, forKey: "copyOnSave") } }
    @Published var playSound: Bool { didSet { defaults.set(playSound, forKey: "playSound") } }
    @Published var showLoupe: Bool { didSet { defaults.set(showLoupe, forKey: "showLoupe") } }
    @Published var showPreview: Bool { didSet { defaults.set(showPreview, forKey: "showPreview") } }
    @Published var areaShortcut: Shortcut? { didSet { store(areaShortcut, "areaShortcut") } }
    @Published var fullShortcut: Shortcut? { didSet { store(fullShortcut, "fullShortcut") } }
    @Published var colorIndex: Int { didSet { defaults.set(colorIndex, forKey: "colorIndex") } }
    @Published var strokeSize: Int { didSet { defaults.set(strokeSize, forKey: "strokeSize") } }

    /// True while a shortcut recorder is listening — global hotkeys are paused.
    @Published var isRecordingShortcut = false

    static var defaultFolder: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Snaply", isDirectory: true)
    }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "format": ImageFormat.png.rawValue,
            "copyOnSave": true,
            "playSound": true,
            "showLoupe": true,
            "showPreview": true,
            "colorIndex": 0,
            "strokeSize": 1,
        ])
        saveFolder = d.string(forKey: "saveFolder").map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? Preferences.defaultFolder
        format = ImageFormat(rawValue: d.string(forKey: "format") ?? "") ?? .png
        copyOnSave = d.bool(forKey: "copyOnSave")
        playSound = d.bool(forKey: "playSound")
        showLoupe = d.bool(forKey: "showLoupe")
        showPreview = d.bool(forKey: "showPreview")
        colorIndex = d.integer(forKey: "colorIndex")
        strokeSize = d.integer(forKey: "strokeSize")
        areaShortcut = Preferences.load("areaShortcut") ?? .defaultArea
        fullShortcut = Preferences.load("fullShortcut") ?? .defaultFull
    }

    private func store(_ s: Shortcut?, _ key: String) {
        // An explicit "none" is stored as empty data so it isn't replaced by the default.
        let data = s.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        defaults.set(data, forKey: key)
    }

    private static func load(_ key: String) -> Shortcut?? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        if data.isEmpty { return .some(nil) }
        return .some(try? JSONDecoder().decode(Shortcut.self, from: data))
    }
}

extension URL {
    var abbreviatedPath: String { (path as NSString).abbreviatingWithTildeInPath }
}

extension Notification.Name {
    static let snaplyDidSave = Notification.Name("SnaplyDidSave")
}
