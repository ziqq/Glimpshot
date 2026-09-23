import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    if SelfTest.runIfRequested() {
        app.setActivationPolicy(.accessory)
        app.run()
        return
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) {
        app.run()
    }
}
