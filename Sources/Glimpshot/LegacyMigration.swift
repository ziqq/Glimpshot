import Foundation

/// One-time import from the app's previous identity (Snaply, com.ziqq.snaply):
/// settings and shortcuts, plus the default screenshots folder.
enum LegacyMigration {
    private static let oldDomain = "com.ziqq.snaply" as CFString
    private static let doneKey = "migratedFromSnaply"
    private static let keys = [
        "saveFolder", "format", "copyOnSave", "playSound", "showLoupe", "showPreview",
        "areaShortcut", "fullShortcut", "colorIndex", "strokeSize", "accentIndex",
        "autoCheckUpdates", "language", "AppleLanguages", "menuBarIcon", "didOnboard",
    ]

    static func run() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: doneKey) else { return }
        d.set(true, forKey: doneKey)

        for key in keys {
            guard d.object(forKey: key) == nil,
                  let value = CFPreferencesCopyAppValue(key as CFString, oldDomain) else { continue }
            d.set(value, forKey: key)
        }

        // Move the old default folder to the new default location.
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        let oldFolder = pictures.appendingPathComponent("Snaply", isDirectory: true)
        let newFolder = pictures.appendingPathComponent(AppInfo.name, isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: oldFolder.path), !fm.fileExists(atPath: newFolder.path) {
            try? fm.moveItem(at: oldFolder, to: newFolder)
        }
        if let stored = d.string(forKey: "saveFolder"),
           URL(fileURLWithPath: stored).standardizedFileURL == oldFolder.standardizedFileURL {
            d.set(newFolder.path, forKey: "saveFolder")
        }
    }
}
