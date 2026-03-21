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
        layer?.cornerRadius = 4

        displayLabel = NSTextField(labelWithString: "")
        displayLabel.font = .systemFont(ofSize: 12)
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

        // Check for conflicts
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
        layer?.borderColor = NSColor.systemBlue.cgColor
        layer?.borderWidth = 2
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
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

        switch Int(keyCode) {
        case kVK_LeftArrow: parts.append("←")
        case kVK_RightArrow: parts.append("→")
        case kVK_UpArrow: parts.append("↑")
        case kVK_DownArrow: parts.append("↓")
        case kVK_Return: parts.append("↩")
        case kVK_Delete: parts.append("⌫")
        default:
            let chars = keyCodeToChar(keyCode)
            parts.append(chars)
        }
        return parts.joined()
    }

    private func keyCodeToChar(_ keyCode: UInt32) -> String {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let data = unsafeBitCast(layoutData, to: CFData.self) as Data
        let layout = data.withUnsafeBytes { $0.bindMemory(to: UCKeyboardLayout.self).baseAddress! }
        var deadKeyState: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 4)
        UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit), &deadKeyState, 4, &length, &chars)
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }
}
