import Cocoa
@preconcurrency import ApplicationServices

@MainActor
class TextInserter {
    static let shared = TextInserter()

    // MARK: - Constants

    /// Virtual key code for 'V' key (used for Cmd+V paste)
    private static let vKeyCode: CGKeyCode = 9

    /// Delay to ensure clipboard is ready before pasting (50ms)
    private static let clipboardReadyDelay: TimeInterval = 0.05

    /// Delay before restoring previous clipboard contents (200ms)
    /// This gives the paste operation time to complete before we modify the clipboard
    private static let clipboardRestoreDelay: TimeInterval = 0.2

    // MARK: - State for handling rapid successive operations

    /// Stores the original clipboard content before the first operation in a sequence
    private var originalClipboardContent: String?

    /// Queue to serialize paste operations and prevent race conditions
    private var operationQueue: [(text: String, id: UUID)] = []

    /// Whether an operation is currently being executed
    private var isExecutingOperation = false

    private init() {}

    /// Insert text at the current cursor position using clipboard + paste
    /// This is more reliable than character-by-character typing which can cause reordering issues
    /// Handles rapid successive calls by queueing operations to prevent clipboard race conditions
    func insertTextAtCursor(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Capture original clipboard only on first call in a sequence
        if operationQueue.isEmpty && !isExecutingOperation {
            originalClipboardContent = pasteboard.string(forType: .string)
        }

        // Enqueue the operation
        let operationId = UUID()
        operationQueue.append((text: text, id: operationId))

        // Start processing if not already running
        processNextOperation()
    }

    /// Process the next operation in the queue serially
    private func processNextOperation() {
        // Don't start a new operation if one is already running or queue is empty
        guard !isExecutingOperation, !operationQueue.isEmpty else { return }

        isExecutingOperation = true
        let operation = operationQueue.removeFirst()
        let pasteboard = NSPasteboard.general

        // Copy text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(operation.text, forType: .string)

        // Small delay to ensure clipboard is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.clipboardReadyDelay) {
            // Simulate Cmd+V paste
            self.simulatePaste()

            // Wait for paste to complete before processing next operation
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.clipboardRestoreDelay) {
                self.isExecutingOperation = false

                // If more operations queued, process them
                if !self.operationQueue.isEmpty {
                    self.processNextOperation()
                } else {
                    // All operations complete - restore original clipboard
                    pasteboard.clearContents()
                    if let original = self.originalClipboardContent {
                        pasteboard.setString(original, forType: .string)
                    }
                    self.originalClipboardContent = nil
                }
            }
        }
    }

    /// Simulate Cmd+V paste keystroke
    private func simulatePaste() {
        // Create key down event with Command modifier
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: Self.vKeyCode, keyDown: true),
           let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: Self.vKeyCode, keyDown: false) {

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
