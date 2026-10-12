// https://github.com/ziqq/Glimpshot
// Copyright (C) 2026 Anton Ustinoff
// https://github.com/ziqq/Glimpshot/blob/main/LICENSE

import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    LegacyMigration.run()
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) {
        app.run()
    }
}
