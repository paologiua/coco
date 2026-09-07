import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// .accessory: no Dock icon, no menu bar takeover. Paired with LSUIElement in Info.plist.
app.setActivationPolicy(.accessory)
app.run()
