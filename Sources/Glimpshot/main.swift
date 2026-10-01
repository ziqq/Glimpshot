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
