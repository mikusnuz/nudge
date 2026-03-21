import Cocoa
import Carbon
import ServiceManagement

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var preferencesWindow: PreferencesWindow?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "Nudge")
                ?? makeGridImage()
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Rebuild menu each time it opens to get current frontmost app
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        buildMenu(menu)
    }

    private func buildMenu(_ menu: NSMenu) {
        // --- Halves ---
        addSnapItem(menu, .leftHalf, icon: "◧")
        addSnapItem(menu, .rightHalf, icon: "◨")
        addSnapItem(menu, .topHalf, icon: "⬒")
        addSnapItem(menu, .bottomHalf, icon: "⬓")
        menu.addItem(.separator())

        // --- Quarters ---
        addSnapItem(menu, .topLeft, icon: "◰")
        addSnapItem(menu, .topRight, icon: "◳")
        addSnapItem(menu, .bottomLeft, icon: "◱")
        addSnapItem(menu, .bottomRight, icon: "◲")
        menu.addItem(.separator())

        // --- Thirds ---
        addSnapItem(menu, .leftThird, icon: "⊏")
        addSnapItem(menu, .centerThird, icon: "⊓")
        addSnapItem(menu, .rightThird, icon: "⊐")
        menu.addItem(.separator())

        // --- Two Thirds ---
        addSnapItem(menu, .leftTwoThirds, icon: "◧")
        addSnapItem(menu, .centerTwoThirds, icon: "⊓")
        addSnapItem(menu, .rightTwoThirds, icon: "◨")
        menu.addItem(.separator())

        // --- Display ---
        addSnapItem(menu, .nextDisplay, icon: "▶")
        addSnapItem(menu, .previousDisplay, icon: "◀")
        menu.addItem(.separator())

        // --- Maximize / Center / Restore ---
        addSnapItem(menu, .maximize, icon: "⬜")
        addSnapItem(menu, .center, icon: "⊞")
        addSnapItem(menu, .restore, icon: "↩")
        menu.addItem(.separator())

        // --- Settings ---
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openPreferences), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        // --- Ignore current app ---
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName ?? "App"
        let bundleID = frontApp?.bundleIdentifier ?? ""

        if !bundleID.isEmpty && bundleID != "app.nudge.Nudge" {
            let isIgnored = UserPreferences.shared.isAppIgnored(bundleID)
            let ignoreTitle = isIgnored ? "Stop Ignoring \"\(appName)\"" : "Ignore \"\(appName)\""
            let ignoreItem = NSMenuItem(title: ignoreTitle, action: #selector(toggleIgnoreApp(_:)), keyEquivalent: "")
            ignoreItem.target = self
            ignoreItem.representedObject = bundleID
            if isIgnored {
                ignoreItem.state = .on
            }
            menu.addItem(ignoreItem)
            menu.addItem(.separator())
        }

        // --- About / Quit ---
        let aboutItem = NSMenuItem(title: "About Nudge", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func addSnapItem(_ menu: NSMenu, _ action: SnapAction, icon: String) {
        let hotkey = UserPreferences.shared.hotkey(for: action)

        // Build the menu item with shortcut shown inline
        let item = NSMenuItem()
        item.target = self
        item.action = #selector(menuActionClicked(_:))
        item.representedObject = action

        // Set key equivalent for native shortcut display
        let (keyEquiv, modMask) = nativeKeyEquivalent(modifiers: hotkey.modifiers, keyCode: hotkey.keyCode)
        item.keyEquivalent = keyEquiv
        item.keyEquivalentModifierMask = modMask

        // Title with icon
        item.title = "\(icon)  \(action.displayName)"

        menu.addItem(item)
    }

    /// Convert Carbon modifier + keyCode to NSMenuItem keyEquivalent + modifierMask
    private func nativeKeyEquivalent(modifiers: UInt32, keyCode: UInt32) -> (String, NSEvent.ModifierFlags) {
        var mask: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if modifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        if modifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }

        let key: String
        switch Int(keyCode) {
        case kVK_LeftArrow:  key = String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case kVK_RightArrow: key = String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case kVK_UpArrow:    key = String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case kVK_DownArrow:  key = String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case kVK_Return:     key = "\r"
        case kVK_Delete:     key = String(UnicodeScalar(NSDeleteFunctionKey)!)
        case kVK_ANSI_U: key = "u"
        case kVK_ANSI_I: key = "i"
        case kVK_ANSI_J: key = "j"
        case kVK_ANSI_K: key = "k"
        case kVK_ANSI_D: key = "d"
        case kVK_ANSI_F: key = "f"
        case kVK_ANSI_G: key = "g"
        case kVK_ANSI_E: key = "e"
        case kVK_ANSI_R: key = "r"
        case kVK_ANSI_T: key = "t"
        case kVK_ANSI_C: key = "c"
        default: key = ""
        }
        return (key, mask)
    }

    // MARK: - Actions

    @objc private func menuActionClicked(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? SnapAction else { return }
        WindowManager.shared.performAction(action)
    }

    @objc private func toggleIgnoreApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        if UserPreferences.shared.isAppIgnored(bundleID) {
            UserPreferences.shared.removeIgnoredApp(bundleID)
        } else {
            UserPreferences.shared.addIgnoredApp(bundleID)
        }
    }

    @objc private func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Nudge"
        alert.informativeText = "Version 1.0.0\nA free, open-source macOS window manager.\n\nhttps://github.com/mikusnuz/nudge"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Fallback icon

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
}
