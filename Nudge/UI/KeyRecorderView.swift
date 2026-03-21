import Cocoa
import Carbon

final class KeyRecorderView: NSView {
    var onRecorded: ((UInt32, UInt32) -> Void)?

    private var isRecording = false
    private var displayLabel: NSTextField!
    private var clearButton: NSButton!

    var currentModifiers: UInt32 = 0
    var currentKeyCode: UInt32 = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 6

        displayLabel = NSTextField(labelWithString: "")
        displayLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(displayLabel)

        clearButton = NSButton(title: "✕", target: self, action: #selector(clearShortcut))
        clearButton.bezelStyle = .inline
        clearButton.font = .systemFont(ofSize: 10)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.isHidden = true
        addSubview(clearButton)

        NSLayoutConstraint.activate([
            displayLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            displayLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func setShortcut(modifiers: UInt32, keyCode: UInt32) {
        currentModifiers = modifiers
        currentKeyCode = keyCode
        displayLabel.stringValue = shortcutString(modifiers: modifiers, keyCode: keyCode)
        clearButton.isHidden = false
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording { stopRecording() } else { startRecording() }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) { stopRecording(); return }

        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else { return }

        let keyCode = UInt32(event.keyCode)

        for action in SnapAction.allCases {
            let existing = UserPreferences.shared.hotkey(for: action)
            if existing.modifiers == modifiers && existing.keyCode == keyCode {
                let alert = NSAlert()
                alert.messageText = "Shortcut Conflict"
                alert.informativeText = "This shortcut is already used by \"\(action.displayName)\"."
                alert.alertStyle = .warning
                alert.runModal()
                stopRecording()
                return
            }
        }

        currentModifiers = modifiers
        currentKeyCode = keyCode
        displayLabel.stringValue = shortcutString(modifiers: modifiers, keyCode: keyCode)
        clearButton.isHidden = false
        stopRecording()
        onRecorded?(modifiers, keyCode)
    }

    override var acceptsFirstResponder: Bool { true }

    private func startRecording() {
        isRecording = true
        displayLabel.stringValue = "Type shortcut..."
        displayLabel.font = .systemFont(ofSize: 12)
        layer?.borderColor = NSColor.systemBlue.cgColor
        layer?.borderWidth = 2
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
        displayLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        if currentModifiers == 0 { displayLabel.stringValue = "" }
    }

    @objc private func clearShortcut() {
        currentModifiers = 0
        currentKeyCode = 0
        displayLabel.stringValue = ""
        clearButton.isHidden = true
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private func shortcutString(modifiers: UInt32, keyCode: UInt32) -> String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        parts.append(keyName(for: keyCode))
        return parts.joined(separator: " ")
    }

    /// Explicit key name mapping — no UCKeyTranslate fallback that returns "?"
    private func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Return: return "Return"
        case kVK_Delete: return "Backspace"
        case kVK_Space: return "Space"
        case kVK_Tab: return "Tab"
        case kVK_Escape: return "Esc"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key\(keyCode)"
        }
    }
}
