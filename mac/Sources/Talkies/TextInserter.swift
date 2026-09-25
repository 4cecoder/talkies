import Cocoa
@preconcurrency import ApplicationServices
import TalkiesCore

struct TextInsertionDestination {
    let processIdentifier: pid_t
    let applicationName: String
}

enum TextInsertionResult {
    case inserted(applicationName: String)
    case copiedForManualPaste(reason: String)
    case failed(reason: String)
}

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
    private static let clipboardRestoreDelay: Duration = .milliseconds(450)

    // MARK: - State for handling rapid successive operations

    /// Stores every original clipboard item and representation before a paste sequence.
    private var originalClipboardContent: ClipboardSnapshot?

    private struct PendingOperation {
        let text: String
        let destination: TextInsertionDestination?
        let continuation: CheckedContinuation<TextInsertionResult, Never>
    }

    private var operationQueue: [PendingOperation] = []
    private var activeOperation: PendingOperation?

    /// Whether an operation is currently being executed
    private var isExecutingOperation = false

    private init() {}

    func captureDestination() -> TextInsertionDestination? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return nil
        }

        return TextInsertionDestination(
            processIdentifier: application.processIdentifier,
            applicationName: application.localizedName ?? "the previous app"
        )
    }

    /// Paste into the app focused when dictation began; keep a manual-paste path
    /// available whenever the destination or system permissions prevent that.
    func insertTextAtCursor(_ text: String, into destination: TextInsertionDestination?) async -> TextInsertionResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failed(reason: "There is no transcript to insert.")
        }

        return await withCheckedContinuation { continuation in
            let pasteboard = NSPasteboard.general
            if operationQueue.isEmpty && !isExecutingOperation {
                originalClipboardContent = Self.snapshot(from: pasteboard)
            }
            operationQueue.append(PendingOperation(text: text, destination: destination, continuation: continuation))
            processNextOperation()
        }
    }

    private func processNextOperation() {
        guard !isExecutingOperation, !operationQueue.isEmpty else { return }

        isExecutingOperation = true
        let operation = operationQueue.removeFirst()
        activeOperation = operation
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()
        guard pasteboard.setString(operation.text, forType: .string) else {
            print("⚠️ TextInserter: Could not stage text on the clipboard")
            finishOperation(
                using: pasteboard,
                result: .failed(reason: "Talkies could not copy the transcript."),
                preserveTranscriptOnClipboard: false
            )
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.clipboardReadyDelay))

            guard let destination = operation.destination,
                  let application = NSRunningApplication(processIdentifier: destination.processIdentifier),
                  !application.isTerminated else {
                finishOperation(
                    using: pasteboard,
                    result: .copiedForManualPaste(reason: "The original app is unavailable. Press ⌘V to paste."),
                    preserveTranscriptOnClipboard: true
                )
                return
            }

            guard AXIsProcessTrusted() else {
                finishOperation(
                    using: pasteboard,
                    result: .copiedForManualPaste(reason: "Allow Accessibility access, then press ⌘V to paste."),
                    preserveTranscriptOnClipboard: true
                )
                return
            }

            if !application.isActive && !application.activate(options: []) {
                finishOperation(
                    using: pasteboard,
                    result: .copiedForManualPaste(reason: "Could not return to \(destination.applicationName). Press ⌘V to paste."),
                    preserveTranscriptOnClipboard: true
                )
                return
            }

            try? await Task.sleep(for: .milliseconds(100))
            guard await Self.simulatePaste() else {
                finishOperation(
                    using: pasteboard,
                    result: .copiedForManualPaste(reason: "Paste was blocked. The transcript is on your clipboard; press ⌘V."),
                    preserveTranscriptOnClipboard: true
                )
                return
            }

            try? await Task.sleep(for: Self.clipboardRestoreDelay)
            finishOperation(
                using: pasteboard,
                result: .inserted(applicationName: destination.applicationName),
                preserveTranscriptOnClipboard: false
            )
        }
    }

    private func finishOperation(
        using pasteboard: NSPasteboard,
        result: TextInsertionResult,
        preserveTranscriptOnClipboard: Bool
    ) {
        isExecutingOperation = false
        let finishedOperation = activeOperation
        activeOperation = nil

        if !operationQueue.isEmpty {
            processNextOperation()
        } else {
            if preserveTranscriptOnClipboard {
                originalClipboardContent = nil
            } else {
                Self.restore(originalClipboardContent, to: pasteboard)
                originalClipboardContent = nil
            }
        }

        finishedOperation?.continuation.resume(returning: result)
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

    /// Send Cmd+V after returning focus to the original target app.
    private static func simulatePaste() async -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
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
