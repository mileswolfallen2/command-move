import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Activate as a background agent (no dock icon)
app.setActivationPolicy(.accessory)

app.run()
