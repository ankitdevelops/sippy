import AppKit

// Entry point — we use NSApplicationMain-style manual setup
// so `swift run` launches a real menu-bar + floating-window app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
