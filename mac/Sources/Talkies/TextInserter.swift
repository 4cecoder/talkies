import Cocoa
@preconcurrency import ApplicationServices
import TalkiesCore

struct TextInsertionDestination {
    let processIdentifier: pid_t
    let applicationName: String
}

enum TextInsertionResult {
    case inserted(applicationName: String)
    case manualPasteRequired(reason: String)
    case failed(reason: String)
}

/// Inserts into a verified, focused text control. Automatic insertion never
/// reads from, writes to, or restores the user's clipboard.
@MainActor
class TextInserter {
    static let shared = TextInserter()

    private static let supportedTextRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String
    ]

    private init() {}

    /// Capture which app owns keyboard focus before the non-activating dictation
    /// panel is shown. The focused element itself is rechecked at insertion time.
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

    func insertTextAtCursor(_ text: String, into destination: TextInsertionDestination?) async -> TextInsertionResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failed(reason: "There is no transcript to insert.")
        }

        guard let destination else {
            return .manualPasteRequired(reason: "No destination app was captured. Copy the transcript, then paste it where you want it.")
        }

        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.processIdentifier else {
            return .manualPasteRequired(reason: "The original app is no longer focused. Copy the transcript and choose the field yourself.")
        }

        guard AXIsProcessTrusted() else {
            return .manualPasteRequired(reason: "Accessibility access is needed for safe field insertion. Copy the transcript to paste manually.")
        }

        let appElement = AXUIElementCreateApplication(destination.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusResult == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return .manualPasteRequired(reason: "Talkies could not confirm the focused text field. Copy the transcript and paste it yourself.")
        }

        let focusedElement = unsafeDowncast(focusedValue, to: AXUIElement.self)
        guard let role = Self.stringAttribute(kAXRoleAttribute, from: focusedElement),
              Self.supportedTextRoles.contains(role),
              Self.isEnabled(focusedElement) else {
            return .manualPasteRequired(reason: "The focused control is not a supported text field. Copy the transcript and choose the input yourself.")
        }

        // AXSelectedText replaces the current selection, or inserts at the
        // caret when there is no selection. This avoids clipboard races entirely.
        let insertionResult = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        guard insertionResult == .success else {
            return .manualPasteRequired(reason: "This app does not allow direct text insertion. Copy the transcript and press ⌘V in the field.")
        }

        return .inserted(applicationName: destination.applicationName)
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        return value as? String
    }

    private static func isEnabled(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value) == .success,
              let number = value as? NSNumber else { return false }
        return number.boolValue
    }

    /// Clipboard modification is only allowed after an explicit user click.
    func copyToClipboard(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    func checkAccessibilityPermissions() -> Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermissions() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
