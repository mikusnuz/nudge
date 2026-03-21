import Cocoa
import ServiceManagement

final class PreferencesWindow: NSWindowController {
    private var tabView: NSTabView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "Nudge Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)
        setupTabs()

        // Enable ⌘W to close
        let closeItem = NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(closeItem)
        let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileMenuItem.submenu = fileMenu
        if NSApp.mainMenu == nil {
            NSApp.mainMenu = NSMenu()
        }
        NSApp.mainMenu?.addItem(fileMenuItem)
    }

    private func setupTabs() {
        tabView = NSTabView(frame: window!.contentView!.bounds)
        tabView.autoresizingMask = [.width, .height]

        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = "General"
        generalTab.view = makeGeneralView()
        tabView.addTabViewItem(generalTab)

        let shortcutsTab = NSTabViewItem(identifier: "shortcuts")
        shortcutsTab.label = "Shortcuts"
        shortcutsTab.view = makeShortcutsView()
        tabView.addTabViewItem(shortcutsTab)

        window?.contentView?.addSubview(tabView)
    }

    private func makeGeneralView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))

        let launchCheckbox = NSButton(checkboxWithTitle: "Launch Nudge at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        launchCheckbox.state = UserPreferences.shared.launchAtLogin ? .on : .off
        launchCheckbox.frame = NSRect(x: 20, y: 240, width: 300, height: 24)
        view.addSubview(launchCheckbox)

        let dragSnapCheckbox = NSButton(checkboxWithTitle: "Enable drag-snap (drag windows to screen edges)", target: self, action: #selector(toggleDragSnap(_:)))
        dragSnapCheckbox.state = UserPreferences.shared.dragSnapEnabled ? .on : .off
        dragSnapCheckbox.frame = NSRect(x: 20, y: 210, width: 400, height: 24)
        view.addSubview(dragSnapCheckbox)

        return view
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enabled = sender.state == .on
        UserPreferences.shared.launchAtLogin = enabled
        if #available(macOS 13.0, *) {
            do {
                if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { NSLog("Failed to update login item: \(error)") }
        }
    }

    @objc private func toggleDragSnap(_ sender: NSButton) {
        UserPreferences.shared.dragSnapEnabled = sender.state == .on
        DragSnapManager.shared.reload()
    }

    private func makeShortcutsView() -> NSView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
        scrollView.hasVerticalScroller = true
        scrollView.autoresizingMask = [.width, .height]

        let actions = SnapAction.allCases
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: CGFloat(actions.count) * 36 + 20))

        for (index, action) in actions.enumerated() {
            let y = contentView.frame.height - CGFloat(index + 1) * 36

            let label = NSTextField(labelWithString: action.displayName)
            label.frame = NSRect(x: 20, y: y, width: 200, height: 24)
            contentView.addSubview(label)

            let recorder = KeyRecorderView(frame: NSRect(x: 230, y: y, width: 160, height: 24))
            recorder.identifier = NSUserInterfaceItemIdentifier("recorder-\(index)")
            let hotkey = UserPreferences.shared.hotkey(for: action)
            recorder.setShortcut(modifiers: hotkey.modifiers, keyCode: hotkey.keyCode)
            recorder.onRecorded = { modifiers, keyCode in
                UserPreferences.shared.setCustomHotkey(for: action, modifiers: modifiers, keyCode: keyCode)
                HotkeyManager.shared.reloadHotkeys()
            }
            contentView.addSubview(recorder)

            let resetBtn = NSButton(title: "Reset", target: nil, action: nil)
            resetBtn.bezelStyle = .inline
            resetBtn.frame = NSRect(x: 400, y: y, width: 50, height: 24)
            resetBtn.tag = index
            resetBtn.target = self
            resetBtn.action = #selector(resetShortcut(_:))
            contentView.addSubview(resetBtn)
        }

        scrollView.documentView = contentView
        return scrollView
    }

    @objc private func resetShortcut(_ sender: NSButton) {
        let index = sender.tag
        let action = SnapAction.allCases[index]
        UserPreferences.shared.resetHotkey(for: action)
        HotkeyManager.shared.reloadHotkeys()

        // Update only the affected KeyRecorderView, don't rebuild the whole view
        guard let scrollView = tabView.tabViewItem(at: 1).view as? NSScrollView,
              let contentView = scrollView.documentView else { return }
        let recorderID = NSUserInterfaceItemIdentifier("recorder-\(index)")
        for subview in contentView.subviews {
            if let recorder = subview as? KeyRecorderView, recorder.identifier == recorderID {
                let hotkey = action.defaultHotkey
                recorder.setShortcut(modifiers: hotkey.modifiers, keyCode: hotkey.keyCode)
                break
            }
        }
    }
}
