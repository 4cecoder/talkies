import Cocoa
@preconcurrency import ApplicationServices

public struct TextInsertionDestination: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let applicationName: String

    public init(processIdentifier: pid_t, applicationName: String) {
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
    }
}

public enum TextInsertionResult: Equatable, Sendable {
    case inserted(applicationName: String)
    case manualPasteRequired(reason: String)
    case failed(reason: String)
}

enum FocusedTextInsertionAttempt: Equatable {
    case inserted
    case noFocusedElement
    case unsupportedControl
    case writeDenied
}

@MainActor
protocol TextAccessibilityClient {
    var currentProcessIdentifier: pid_t { get }
    var frontmostProcessIdentifier: pid_t? { get }

    func frontmostApplication() -> (processIdentifier: pid_t, name: String)?
    func isTrusted() -> Bool
    func setSelectedText(_ text: String, in processIdentifier: pid_t) -> FocusedTextInsertionAttempt
}

/// Inserts only into a verified, currently focused text control. Dictation
/// insertion does not access the clipboard; copying is a separate user action.
@MainActor
public final class TextInserter {
    public static let shared = TextInserter()

    private let accessibilityClient: any TextAccessibilityClient

    public init() {
        accessibilityClient = SystemTextAccessibilityClient()
    }

    init(accessibilityClient: any TextAccessibilityClient) {
        self.accessibilityClient = accessibilityClient
    }

    /// Capture which app owns keyboard focus before the non-activating dictation
    /// panel is shown. The focused element itself is rechecked at insertion time.
    public func captureDestination() -> TextInsertionDestination? {
        guard let application = accessibilityClient.frontmostApplication(),
              application.processIdentifier != accessibilityClient.currentProcessIdentifier else {
            return nil
        }

        return TextInsertionDestination(
            processIdentifier: application.processIdentifier,
            applicationName: application.name
        )
    }

    public func insertTextAtCursor(
        _ text: String,
        into destination: TextInsertionDestination?
    ) async -> TextInsertionResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failed(reason: "There is no transcript to insert.")
        }

        guard let destination else {
            return .manualPasteRequired(reason: "No destination app was captured. Copy the transcript, then paste it where you want it.")
        }

        guard accessibilityClient.frontmostProcessIdentifier == destination.processIdentifier else {
            return .manualPasteRequired(reason: "The original app is no longer focused. Copy the transcript and choose the field yourself.")
        }

        guard accessibilityClient.isTrusted() else {
            return .manualPasteRequired(reason: "Accessibility access is needed for safe field insertion. Copy the transcript to paste manually.")
        }

        switch accessibilityClient.setSelectedText(text, in: destination.processIdentifier) {
        case .inserted:
            return .inserted(applicationName: destination.applicationName)
        case .noFocusedElement:
            return .manualPasteRequired(reason: "Talkies could not confirm the focused text field. Copy the transcript and paste it yourself.")
        case .unsupportedControl:
            return .manualPasteRequired(reason: "The focused control is not a supported text field. Copy the transcript and choose the input yourself.")
        case .writeDenied:
            return .manualPasteRequired(reason: "This app does not allow direct text insertion. Copy the transcript and press ⌘V in the field.")
        }
    }

    /// Clipboard modification is only allowed after an explicit user click.
    public func copyToClipboard(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    public func checkAccessibilityPermissions() -> Bool {
        accessibilityClient.isTrusted()
    }

    public func requestAccessibilityPermissions() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

@MainActor
private final class SystemTextAccessibilityClient: TextAccessibilityClient {
    private static let supportedTextRoles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String
    ]

    var currentProcessIdentifier: pid_t {
        ProcessInfo.processInfo.processIdentifier
    }

    var frontmostProcessIdentifier: pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func frontmostApplication() -> (processIdentifier: pid_t, name: String)? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        return (application.processIdentifier, application.localizedName ?? "the previous app")
    }

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func setSelectedText(_ text: String, in processIdentifier: pid_t) -> FocusedTextInsertionAttempt {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusResult == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return .noFocusedElement
        }

        let focusedElement = unsafeDowncast(focusedValue, to: AXUIElement.self)
        guard let role = Self.stringAttribute(kAXRoleAttribute, from: focusedElement),
              Self.supportedTextRoles.contains(role),
              Self.isEnabled(focusedElement) else {
            return .unsupportedControl
        }

        // AXSelectedText replaces the current selection, or inserts at the
        // caret when there is no selection. This avoids clipboard races entirely.
        let result = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success ? .inserted : .writeDenied
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
}
