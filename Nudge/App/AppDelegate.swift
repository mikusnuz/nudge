import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("Nudge launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}
