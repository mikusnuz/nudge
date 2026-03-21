import Cocoa
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var actionMap: [UInt32: SnapAction] = [:]
    private var nextID: UInt32 = 1
    private var isRunning = false
    private var isPerforming = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        installEventHandler()
        registerAllHotkeys()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        unregisterAllHotkeys()
    }

    func reloadHotkeys() {
        unregisterAllHotkeys()
        registerAllHotkeys()
    }

    func pause() {
        unregisterAllHotkeys()
    }

    func resume() {
        registerAllHotkeys()
    }

    // MARK: - Carbon Event Handler

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            HotkeyManager.shared.handleHotkey(id: hotKeyID.id)
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
    }

    private func handleHotkey(id: UInt32) {
        // Prevent re-entry — if an action is in progress, ignore
        guard !isPerforming else { return }
        guard let action = actionMap[id] else { return }

        isPerforming = true

        DispatchQueue.main.async {
            WindowManager.shared.performAction(action)

            // Block further actions for 200ms to prevent double-fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isPerforming = false
            }
        }
    }

    // MARK: - Registration

    private func registerAllHotkeys() {
        for action in SnapAction.allCases {
            let hotkey = UserPreferences.shared.hotkey(for: action)
            registerHotkey(action: action, modifiers: hotkey.modifiers, keyCode: hotkey.keyCode)
        }
    }

    private func registerHotkey(action: SnapAction, modifiers: UInt32, keyCode: UInt32) {
        let id = nextID
        nextID += 1
        actionMap[id] = action
        var hotkeyID = EventHotKeyID(signature: OSType(0x4E554447), id: id)
        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
        if status == noErr, let ref = hotkeyRef {
            hotkeyRefs.append(ref)
        }
    }

    private func unregisterAllHotkeys() {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        actionMap.removeAll()
        nextID = 1
    }
}
