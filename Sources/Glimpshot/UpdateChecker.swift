// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

import AppKit

/// Checks GitHub Releases for a newer version. No backend of our own — just the public GitHub API.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    @Published private(set) var state: State = .idle

    private let lastCheckKey = "lastUpdateCheck"

    /// Called on launch: checks at most once a day and only speaks up when there's something new.
    func checkInBackgroundIfNeeded() {
        guard Preferences.shared.autoCheckUpdates else { return }
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - last > 24 * 3600 else { return }
        Task {
            await check()
            if case let .available(version, url) = state { promptToDownload(version: version, url: url) }
        }
    }

    func check() async {
        state = .checking
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        guard let api = URL(string: "https://api.github.com/repos/\(AppInfo.repo)/releases/latest") else { return }
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = (json["html_url"] as? String).flatMap(URL.init(string:))
            else { state = .failed; return }
            let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            state = Self.isNewer(latest, than: AppInfo.version) ? .available(version: latest, url: page) : .upToDate
        } catch {
            state = .failed
        }
    }

    func promptToDownload(version: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = L("updates.available", version)
        alert.informativeText = L("updates.current", AppInfo.version)
        alert.addButton(withTitle: L("updates.download"))
        alert.addButton(withTitle: L("perm.later"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
