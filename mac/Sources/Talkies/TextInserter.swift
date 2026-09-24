import Cocoa
@preconcurrency import ApplicationServices
import TalkiesCore

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

    /// Stores every original clipboard item and representation before a paste sequence.
    private var originalClipboardContent: ClipboardSnapshot?

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
            originalClipboardContent = Self.snapshot(from: pasteboard)
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
        let success = pasteboard.setString(operation.text, forType: .string)
        guard success else {
            print("⚠️ TextInserter: Could not stage text on the clipboard")
            finishOperation(using: pasteboard)
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.clipboardReadyDelay))
            let didPaste = await Self.simulatePaste()
            if !didPaste {
                print("⚠️ TextInserter: Paste command failed; transcript remains visible in Talkies for manual copying")
            }
            try? await Task.sleep(for: .seconds(Self.clipboardRestoreDelay))
            self.finishOperation(using: pasteboard)
        }
    }

    private func finishOperation(using pasteboard: NSPasteboard) {
        isExecutingOperation = false
        if !operationQueue.isEmpty {
            processNextOperation()
        } else {
            Self.restore(originalClipboardContent, to: pasteboard)
            originalClipboardContent = nil
        }
    }

    private static func snapshot(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { pasteboardItem in
            pasteboardItem.types.compactMap { type in
                pasteboardItem.data(forType: type).map {
                    ClipboardRepresentation(type: type.rawValue, data: $0)
                }
            }
        }
        return ClipboardSnapshot(items: items)
    }

    private static func restore(_ snapshot: ClipboardSnapshot?, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard let snapshot else { return }

        let items = snapshot.items.map { representations in
            let item = NSPasteboardItem()
            for representation in representations {
                item.setData(representation.data, forType: NSPasteboard.PasteboardType(rawValue: representation.type))
            }
            return item as NSPasteboardWriting
        }

        if !items.isEmpty {
            _ = pasteboard.writeObjects(items)
        }
    }

    /// Simulate Cmd+V without blocking the main thread.
    private static func simulatePaste() async -> Bool {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "tell application \"System Events\" to keystroke \"v\" using command down"]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
            task.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }

            do {
                try task.run()
            } catch {
                print("⚠️ TextInserter: Failed to launch paste command: \(error.localizedDescription)")
                continuation.resume(returning: false)
            }
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
