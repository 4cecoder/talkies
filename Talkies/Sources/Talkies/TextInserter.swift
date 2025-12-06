import Cocoa
@preconcurrency import ApplicationServices

@MainActor
class TextInserter {
    static let shared = TextInserter()

    private init() {}

    /// Insert text at the current cursor position
    func insertTextAtCursor(_ text: String) {
        // Method 1: Use CGEvent to simulate typing (most reliable)
        simulateTyping(text)
    }

    private func simulateTyping(_ text: String) {
        // Small delay to ensure focus is correct
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for character in text {
                self.typeCharacter(character)
            }
        }
    }

    private func typeCharacter(_ character: Character) {
        let string = String(character)

        // Create key down and key up events
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {

            // Set the unicode string
            keyDown.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))
            keyUp.keyboardSetUnicodeString(stringLength: string.utf16.count, unicodeString: Array(string.utf16))

            // Post events
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            // Small delay between characters
            usleep(5000) // 5ms
        }
    }

    /// Copy text to clipboard (fallback method)
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
