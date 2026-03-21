# Nudge

A free, open-source macOS window manager.

Nudge lets you snap, resize, and organize your windows with keyboard shortcuts and drag-to-edge gestures — no subscription required.

---

## Features

- **Keyboard Shortcuts** — 18 actions for halves, quarters, thirds, maximize, center, and display moves
- **Drag-to-Snap** — Drag a window to a screen edge or corner to snap it into position
- **Customizable** — Remap any shortcut to your preference through the Settings panel
- **Menu Bar App** — Lives in your menu bar, always accessible, never in your way
- **Multi-Monitor Support** — Move windows across displays with a single keystroke

---

## Default Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Left Half | ⌃⌥← |
| Right Half | ⌃⌥→ |
| Top Half | ⌃⌥↑ |
| Bottom Half | ⌃⌥↓ |
| Top Left | ⌃⌥U |
| Top Right | ⌃⌥I |
| Bottom Left | ⌃⌥J |
| Bottom Right | ⌃⌥K |
| Left Third | ⌃⌥D |
| Center Third | ⌃⌥F |
| Right Third | ⌃⌥G |
| Left Two Thirds | ⌃⌥E |
| Right Two Thirds | ⌃⌥T |
| Maximize | ⌃⌥↩ |
| Center | ⌃⌥C |
| Restore | ⌃⌥⌫ |
| Next Display | ⌃⌥⌘→ |
| Previous Display | ⌃⌥⌘← |

All shortcuts can be remapped in **Nudge → Settings → Shortcuts**.

---

## Requirements

- macOS 11 (Big Sur) or later
- Xcode 14+
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

---

## Installation

### Build from Source

1. Clone the repository:

   ```bash
   git clone https://github.com/mikusnuz/nudge.git
   cd nudge
   ```

2. Install xcodegen (if not already installed):

   ```bash
   brew install xcodegen
   ```

3. Generate the Xcode project:

   ```bash
   xcodegen generate
   ```

4. Open in Xcode and build:

   ```bash
   open Nudge.xcodeproj
   ```

   Press **⌘R** to build and run, or use **Product → Archive** to build a release binary.

5. On first launch, grant Nudge **Accessibility** permissions when prompted in System Settings → Privacy & Security → Accessibility.

---

## License

MIT — see [LICENSE](LICENSE) for details.
