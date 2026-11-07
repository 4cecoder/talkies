import Cocoa
@preconcurrency import ApplicationServices

public struct TextInsertionDestination: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let applicationName: String
    public let bundleIdentifier: String?

    public init(processIdentifier: pid_t, applicationName: String, bundleIdentifier: String? = nil) {
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
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

/// Role allowlist for classic AX text controls. Browser contenteditable regions and some web
/// views commonly surface under other roles (e.g. AXGroup) while still accepting AXSelectedText.
enum AccessibilityTextRoleSupport {
    private static let roles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        // ApplicationServices does not expose a named constant for this role.
        "AXSearchField"
    ]

    static func supports(_ role: String) -> Bool {
        roles.contains(role)
    }
}

/// Pure decision for AX insertion outcome. Exposed for deterministic regression tests.
/// Unknown roles (common for browser contenteditable surfaces) are given a chance to accept
/// the AXSelectedText write; success yields insertion, failure yields unsupported so the
/// caller can guide the user to manual paste.
func decideFocusedTextInsertionOutcome(role: String?, isEnabled: Bool, writeSucceeded: Bool) -> FocusedTextInsertionAttempt {
    guard isEnabled else { return .unsupportedControl }
    if let r = role, AccessibilityTextRoleSupport.supports(r) {
        return writeSucceeded ? .inserted : .writeDenied
    }
    // Unknown role (e.g. contenteditable inside a web view) — attempt was already made by caller.
    return writeSucceeded ? .inserted : .unsupportedControl
}

enum TerminalApplicationSupport {
    static func supports(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.cmuxterm.app" || bundleIdentifier == "com.mitchellh.ghostty"
    }
}

/// Minimal abstraction over the clipboard + Cmd-V path used for terminals.
/// Default implementation performs real pasteboard surgery and CGEvent dispatch.
/// Injectable for deterministic unit tests without touching the live pasteboard.
@MainActor
protocol TerminalPasteEngine {
    /// Stage `text` on the pasteboard, synthesize Cmd-V, then schedule a guarded restore of prior contents.
    /// Returns true if the paste events were posted.
    func pasteUsingClipboardAndCmdV(text: String) -> Bool
}

@MainActor
private struct RealTerminalPasteEngine: TerminalPasteEngine {
    func pasteUsingClipboardAndCmdV(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string),
              let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            restorePasteboard(savedItems, to: pasteboard)
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        let temporaryChangeCount = pasteboard.changeCount
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // Give the target time to read the pasteboard before restoring its prior contents.
        // The guard ensures we do not overwrite a subsequent user copy.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard pasteboard.changeCount == temporaryChangeCount else { return }
            restorePasteboard(savedItems, to: pasteboard)
        }
        return true
    }

    private func restorePasteboard(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}

@MainActor
protocol TextAccessibilityClient {
    var currentProcessIdentifier: pid_t { get }
    var frontmostProcessIdentifier: pid_t? { get }

    func frontmostApplication() -> (processIdentifier: pid_t, name: String, bundleIdentifier: String?)?
    func isTrusted() -> Bool
    func setSelectedText(_ text: String, in processIdentifier: pid_t, bundleIdentifier: String?) -> FocusedTextInsertionAttempt
    func activateApplication(_ processIdentifier: pid_t)
}

/// Inserts into a verified focused control. Terminal apps use a temporary clipboard
/// paste because their panes do not expose standard AX text controls.
@MainActor
public final class TextInserter {
    public static let shared = TextInserter()

    private let accessibilityClient: any TextAccessibilityClient
    private var focusReturnDestination: TextInsertionDestination?

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
            applicationName: application.name,
            bundleIdentifier: application.bundleIdentifier
        )
    }

    /// Call just before Talkies takes keyboard focus on purpose (the history search field).
    /// Remembers the app that had focus so a dictation started meanwhile still targets it.
    public func rememberDestinationBeforeTakingFocus() {
        if let destination = captureDestination() {
            focusReturnDestination = destination
        }
    }

    /// Call when Talkies gives keyboard focus back. Reactivates the app remembered by
    /// `rememberDestinationBeforeTakingFocus()` and returns it, so a recording that starts now
    /// can use it as its insertion destination while macOS is still switching apps. If another
    /// app is already frontmost, that app is returned and nothing is activated. Returns nil when
    /// Talkies is frontmost and no app was remembered.
    @discardableResult
    public func returnFocusToRememberedDestination() -> TextInsertionDestination? {
        let remembered = focusReturnDestination
        focusReturnDestination = nil
        if let current = captureDestination() { return current }
        guard let remembered else { return nil }
        accessibilityClient.activateApplication(remembered.processIdentifier)
        return remembered
    }

    /// Forgets the remembered app without activating it, for when the user moved focus
    /// elsewhere themselves.
    public func forgetRememberedDestination() {
        focusReturnDestination = nil
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

        switch accessibilityClient.setSelectedText(
            text,
            in: destination.processIdentifier,
            bundleIdentifier: destination.bundleIdentifier
        ) {
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
    private let terminalPaste: TerminalPasteEngine

    init(terminalPaste: TerminalPasteEngine = RealTerminalPasteEngine()) {
        self.terminalPaste = terminalPaste
    }

    var currentProcessIdentifier: pid_t {
        ProcessInfo.processInfo.processIdentifier
    }

    var frontmostProcessIdentifier: pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func frontmostApplication() -> (processIdentifier: pid_t, name: String, bundleIdentifier: String?)? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        return (application.processIdentifier, application.localizedName ?? "the previous app", application.bundleIdentifier)
    }

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func activateApplication(_ processIdentifier: pid_t) {
        NSRunningApplication(processIdentifier: processIdentifier)?.activate()
    }

    func setSelectedText(_ text: String, in processIdentifier: pid_t, bundleIdentifier: String?) -> FocusedTextInsertionAttempt {
        let resolvedBundleIdentifier = bundleIdentifier
            ?? NSRunningApplication(processIdentifier: processIdentifier)?.bundleIdentifier
        if TerminalApplicationSupport.supports(resolvedBundleIdentifier) {
            return terminalPaste.pasteUsingClipboardAndCmdV(text: text) ? .inserted : .writeDenied
        }

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
        let role = Self.stringAttribute(kAXRoleAttribute, from: focusedElement)
        let enabled = Self.isEnabled(focusedElement)

        // AXSelectedText replaces the current selection, or inserts at the
        // caret when there is no selection. This is the single source of truth
        // for both classic text fields and browser contenteditable regions that
        // accept the attribute even when their AX role is not one of the classic
        // AXTextField/AXTextArea values.
        let setResult = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        let succeeded = (setResult == .success)
        return decideFocusedTextInsertionOutcome(role: role, isEnabled: enabled, writeSucceeded: succeeded)
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

// MARK: - Test support predicates (clipboard restore guard, key choice documentation)

/// Returns true when the current pasteboard change count matches the value captured right after
/// staging our text. Used by the terminal paste path to avoid clobbering a later user copy.
func shouldRestoreTerminalClipboard(currentChangeCount: Int, capturedAfterStage: Int) -> Bool {
    currentChangeCount == capturedAfterStage
}

// The terminal paste always posts virtualKey 9 (Cmd-V) with maskCommand.
// It must never post virtualKey 36 (Return) or otherwise synthesize a submit.
