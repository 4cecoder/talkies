import Cocoa
@preconcurrency import ApplicationServices

@MainActor
class TextInserter {
    static let shared = TextInserter()

    private init() {}

    /// Insert text at the current cursor position using clipboard + paste
    /// This is more reliable than character-by-character typing which can cause reordering issues
    func insertTextAtCursor(_ text: String) {
        // Save current clipboard contents to restore later
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Copy text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Simulate Cmd+V paste
            self.simulatePaste()

            // Restore previous clipboard contents after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let previous = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }

    /// Simulate Cmd+V paste keystroke
    private func simulatePaste() {
        // Virtual key code for 'V' is 9
        let vKeyCode: CGKeyCode = 9

        // Create key down event with Command modifier
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) {

            // Set Command modifier flag
            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            // Post events
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Legacy character-by-character typing (kept as fallback, may have ordering issues)
    func insertTextByTyping(_ text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for character in text {
                self.typeCharacter(character)
            }
        }
    }

    private func typeCharacter(_ character: Character) {
        let string = String(character)

        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {

            keyDown.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))
            keyUp.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            usleep(5000) // 5ms delay between characters
        }
    }

    /// Copy text to clipboard without inserting
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Check if we have accessibility permissions (silent check, no prompt)
    func checkAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request accessibility permissions (shows system prompt)
    func requestAccessibilityPermissions() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
