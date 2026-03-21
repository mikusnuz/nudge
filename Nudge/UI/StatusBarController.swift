import Cocoa
import Carbon
import ServiceManagement

final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var preferencesWindow: PreferencesWindow?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "Nudge")
                ?? makeGridImage()
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let categories = ["Halves", "Quarters", "Thirds", "Two Thirds", "Other", "Display"]
        for category in categories {
            let actions = SnapAction.allCases.filter { $0.category == category }
            if actions.isEmpty { continue }
            if menu.items.count > 0 { menu.addItem(.separator()) }
            for action in actions {
                let item = NSMenuItem(title: action.displayName, action: #selector(menuActionClicked(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = action
                let hotkey = UserPreferences.shared.hotkey(for: action)
                item.toolTip = shortcutDescription(modifiers: hotkey.modifiers, keyCode: hotkey.keyCode)
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = UserPreferences.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Nudge", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func menuActionClicked(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? SnapAction else { return }
        WindowManager.shared.performAction(action)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let newState = !UserPreferences.shared.launchAtLogin
        UserPreferences.shared.launchAtLogin = newState
        sender.state = newState ? .on : .off
        if #available(macOS 13.0, *) {
            try? newState ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeGridImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.controlTextColor.set()
        NSBezierPath(rect: NSRect(x: 1, y: 1, width: 7, height: 7)).fill()
        NSBezierPath(rect: NSRect(x: 10, y: 1, width: 7, height: 7)).fill()
        NSBezierPath(rect: NSRect(x: 1, y: 10, width: 7, height: 7)).fill()
        NSBezierPath(rect: NSRect(x: 10, y: 10, width: 7, height: 7)).fill()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func shortcutDescription(modifiers: UInt32, keyCode: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Return: return "↩"
        case kVK_Delete: return "⌫"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_C: return "C"
        default: return "?"
        }
    }
}
