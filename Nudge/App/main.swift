import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.finishLaunching()

// Setup directly since applicationDidFinishLaunching may not fire
delegate.setup()

app.run()
