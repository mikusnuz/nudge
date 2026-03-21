import Cocoa
import ApplicationServices

func log(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    let path = "/tmp/nudge-debug.log"
    if let fh = FileHandle(forWritingAtPath: path) {
        fh.seekToEndOfFile()
        fh.write(line.data(using: .utf8)!)
        fh.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

log("=== NUDGE START ===")
log("AXIsProcessTrusted: \(AXIsProcessTrusted())")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

log("calling setup()")
delegate.setup()
log("setup() done, calling run()")

app.run()
