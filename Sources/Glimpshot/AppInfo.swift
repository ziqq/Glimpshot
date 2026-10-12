// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

import AppKit
import SwiftUI

enum AppInfo {
    /// Display name — change here (and in Info.plist) to rebrand.
    static let name = "Glimpshot"
    static let repo = "ziqq/Glimpshot"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }
}

/// Localized string from Localizable.strings (falls back to the key).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Localized format string.
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, arguments: args)
}

// MARK: - Languages

struct AppLanguage: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let all: [AppLanguage] = [
        .init(code: "en", name: "English"),
        .init(code: "ru", name: "Русский"),
        .init(code: "uk", name: "Українська"),
        .init(code: "de", name: "Deutsch"),
        .init(code: "fr", name: "Français"),
        .init(code: "es", name: "Español"),
        .init(code: "it", name: "Italiano"),
        .init(code: "pt-BR", name: "Português (Brasil)"),
        .init(code: "ja", name: "日本語"),
        .init(code: "ko", name: "한국어"),
        .init(code: "zh-Hans", name: "简体中文"),
    ]
}

// MARK: - Accent

enum Theme {
    static let accents: [NSColor] = [
        NSColor(srgbRed: 0.04, green: 0.52, blue: 1.00, alpha: 1), // blue
        NSColor(srgbRed: 0.45, green: 0.36, blue: 1.00, alpha: 1), // indigo
        NSColor(srgbRed: 0.75, green: 0.35, blue: 0.95, alpha: 1), // purple
        NSColor(srgbRed: 1.00, green: 0.18, blue: 0.47, alpha: 1), // pink
        NSColor(srgbRed: 1.00, green: 0.23, blue: 0.19, alpha: 1), // red
        NSColor(srgbRed: 1.00, green: 0.58, blue: 0.00, alpha: 1), // orange
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1), // green
        NSColor(srgbRed: 0.56, green: 0.56, blue: 0.58, alpha: 1), // graphite
    ]

    /// -1 means "follow the system accent color".
    @MainActor static var accent: NSColor {
        let i = Preferences.shared.accentIndex
        return accents.indices.contains(i) ? accents[i] : .controlAccentColor
    }

    @MainActor static var accentColor: Color { Color(nsColor: accent) }
}
