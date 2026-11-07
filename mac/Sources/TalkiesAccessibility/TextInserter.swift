import Cocoa
@preconcurrency import ApplicationServices

/// Metadata-only diagnostics for a single insertion attempt.
/// Never contains transcript text, field contents, selection strings, AXValue, or clipboard data.
/// Used to distinguish capture, bundle/role, attribute presence vs value, trust, write errors, and chosen code path.
public struct InsertionAttemptDiagnostics: Equatable, Sendable {
    public let targetPID: pid_t
    public let targetBundle: String?
    public let frontmostPIDAtCapture: pid_t?
    public let frontmostPIDAtInsert: pid_t?
    public let axTrusted: Bool
    public let focusedRole: String?
    public let focusedSubrole: String?
    public let enabledAttributePresent: Bool
    public let enabled: Bool?
    public let selectedTextSettable: Bool?
    public let writeAXError: String?          // e.g. "success", "kAXErrorCannotComplete", ...
    public let chosenPath: String             // "terminal-paste", "ax-selectedtext", "browser-ax-fallback-paste", "no-focused-element", ...
    public let finalOutcome: String           // high-level classification for the attempt
}

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

/// Role allowlist for classic AX text controls where AXSelectedText is the expected and reliable path.
/// Browser contenteditable and some web views often surface under AXGroup/AXWebArea while still
/// sometimes accepting AXSelectedText; unknown roles get a chance at the write but are also
/// candidates for automatic clipboard fallback when the write fails.
enum AccessibilityTextRoleSupport {
    private static let roles: Set<String> = [
        kAXTextFieldRole as String,
        kAXTextAreaRole as String,
        kAXComboBoxRole as String,
        "AXSearchField"
    ]

    static func supports(_ role: String) -> Bool {
        roles.contains(role)
    }
}

enum TerminalApplicationSupport {
    static func supports(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.cmuxterm.app" || bundleIdentifier == "com.mitchellh.ghostty"
    }
}

/// Bundles for which we are willing to use an automatic clipboard+Cmd-V fallback
/// (same mechanism as terminals) when a direct AXSelectedText write fails or is unsuitable.
/// This provides robust automatic insertion for Chromium/Electron and other browsers that
/// frequently expose web content under roles that do not reliably support AXSelectedText,
/// while still preferring the direct AX path for classic native and Safari form controls.
enum BrowserLikeApplicationSupport {
    private static let bundles: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "org.mozilla.firefox",
        "com.operasoftware.Opera"
    ]

    static func mayBenefitFromPasteFallback(_ bundleIdentifier: String?) -> Bool {
        guard let b = bundleIdentifier else { return false }
        return bundles.contains(b) || b.contains("Chrome") || b.contains("Edge") || b.contains("Brave")
    }
}

/// Minimal abstraction over the clipboard + Cmd-V path.
/// Used for terminals (by design) and as a robust automatic fallback for browser-like
/// targets when AXSelectedText is not reliable. Injectable for tests.
@MainActor
protocol ClipboardPasteEngine {
    func pasteUsingClipboardAndCmdV(text: String) -> Bool
}

@MainActor
private struct RealClipboardPasteEngine: ClipboardPasteEngine {
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

        // Guarded delayed restore: only restore if no intervening user copy occurred.
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

/// Inserts into a verified focused control.
/// - Terminals (cmux/Ghostty) always use the guarded clipboard + Cmd-V path.
/// - Classic native text fields prefer AXSelectedText.
/// - Browser content and other surfaces that do not reliably support AXSelectedText
///   fall back to the same automatic guarded clipboard + Cmd-V path when the AX write
///   fails or is unsuitable. This provides robust automatic insertion without requiring
///   the user to manually copy/paste, while still preferring direct AX for surfaces that work.
/// Never synthesizes Return. Clipboard is restored with changeCount guard.
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

    public func rememberDestinationBeforeTakingFocus() {
        if let destination = captureDestination() {
            focusReturnDestination = destination
        }
    }

    @discardableResult
    public func returnFocusToRememberedDestination() -> TextInsertionDestination? {
        let remembered = focusReturnDestination
        focusReturnDestination = nil
        if let current = captureDestination() { return current }
        guard let remembered else { return nil }
        accessibilityClient.activateApplication(remembered.processIdentifier)
        return remembered
    }

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
    private let pasteEngine: ClipboardPasteEngine

    init(pasteEngine: ClipboardPasteEngine = RealClipboardPasteEngine()) {
        self.pasteEngine = pasteEngine
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
        let resolvedBundle = bundleIdentifier
            ?? NSRunningApplication(processIdentifier: processIdentifier)?.bundleIdentifier

        // Terminal path (cmux, Ghostty) — always guarded clipboard + Cmd-V (virtualKey 9).
        // Never Return (virtualKey 36). Clipboard restore is changeCount guarded.
        if TerminalApplicationSupport.supports(resolvedBundle) {
            return pasteEngine.pasteUsingClipboardAndCmdV(text: text) ? .inserted : .writeDenied
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
        let subrole = Self.stringAttribute(kAXSubroleAttribute, from: focusedElement)

        // Read AXEnabled with presence tracking. Absent attribute is recorded distinctly from "false".
        var enabledPresent = false
        var enabledValue: Bool?
        var enabledCF: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXEnabledAttribute as CFString, &enabledCF) == .success,
           let num = enabledCF as? NSNumber {
            enabledPresent = true
            enabledValue = num.boolValue
        }

        // If we have a definitive "disabled" signal, do not attempt write (avoids write-then-report-failure).
        if enabledPresent, let en = enabledValue, en == false {
            return .unsupportedControl
        }

        // Check whether AXSelectedText is settable on this element.
        var settableCF: DarwinBoolean = false
        let settableResult = AXUIElementIsAttributeSettable(focusedElement, kAXSelectedTextAttribute as CFString, &settableCF)
        let isSettable = (settableResult == .success) ? settableCF.boolValue : nil

        // If we know it is not settable, avoid the write for classic controls and fall through to fallback logic below.
        if let set = isSettable, set == false, AccessibilityTextRoleSupport.supports(role ?? "") {
            return .writeDenied
        }

        // AXSelectedText write. This is the preferred path for native + Safari form controls.
        let setResult = AXUIElementSetAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        let writeSucceeded = (setResult == .success)

        if writeSucceeded {
            // Success on the write: trust it for insertion. We do not re-read the value (would require
            // reading potentially sensitive field contents) and do not perform speculative verification
            // that could race. If the surface silently ignored the write, the user will see no text and
            // can re-dictate; we avoid duplicating by never retrying automatically here.
            return .inserted
        }

        // Write did not succeed (or we decided not to attempt for a classic non-settable control).
        // For browser-like bundles or non-classic roles, use the automatic guarded clipboard + Cmd-V
        // fallback. This is the same engine as terminals and provides robust automatic insertion
        // without requiring the user to perform a manual copy/paste step.
        if BrowserLikeApplicationSupport.mayBenefitFromPasteFallback(resolvedBundle) ||
           !AccessibilityTextRoleSupport.supports(role ?? "") {
            return pasteEngine.pasteUsingClipboardAndCmdV(text: text) ? .inserted : .writeDenied
        }

        // Otherwise surface the precise reason so the caller can guide the user.
        return .writeDenied
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

// Test support

func shouldRestoreTerminalClipboard(currentChangeCount: Int, capturedAfterStage: Int) -> Bool {
    currentChangeCount == capturedAfterStage
}

// The clipboard paste path (terminals and browser fallback) always uses virtualKey 9 (Cmd-V) + maskCommand.
// It must never post virtualKey 36 (Return).
