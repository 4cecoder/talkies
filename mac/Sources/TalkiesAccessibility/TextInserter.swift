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

/// Snapshot of AX attributes observed for the focused element. Used for deterministic
/// policy decisions and for privacy-safe diagnostics. No content values.
public struct AXTargetSnapshot: Equatable, Sendable {
    public let role: String?
    public let subrole: String?
    public let enabledPresent: Bool
    public let enabled: Bool?
    public let selectedTextSettable: Bool?
}

/// The concrete action the inserter will take after inspecting the focused target.
enum InsertionAction {
    case useDirectAX
    case useClipboardPaste
    case reportNoFocused
    case reportUnsupported
    case reportWriteDenied
}

/// Pure, testable policy decision. Given only safe metadata about the focused element
/// and the app bundle type, decide whether to attempt AXSelectedText, fall back to
/// guarded paste, or deny. This is the seam for both tests and diagnostics.
///
/// For browser-like bundles we are deterministic about using the guarded paste path
/// for plausible editing targets (classic text roles or common browser container roles
/// when enabled is not explicitly false). This addresses the case where AXSelectedText
/// may report .success (or the element reports a classic role) but the text does not
/// become visible to the user.
func chooseInsertionAction(snapshot: AXTargetSnapshot, isTerminal: Bool, isBrowserLike: Bool) -> (action: InsertionAction, path: String) {
    if isTerminal {
        return (.useClipboardPaste, "terminal-paste")
    }
        if isBrowserLike {
            // Deterministic guarded paste for supported browser editing targets.
            // We do not rely on AXSelectedText "success" (or classic role report) meaning
            // the text will be visible/usable to the user. Chromium/Electron web content
            // can silently ignore or lag. Paste path bypasses that.
            let plausible = snapshot.role == nil
                || AccessibilityTextRoleSupport.supports(snapshot.role ?? "")
                || (snapshot.role ?? "").contains("Group")
                || (snapshot.role ?? "").contains("WebArea")
                || (snapshot.role ?? "").contains("Text")
                || (snapshot.role ?? "").contains("Field")
                || (snapshot.role ?? "").contains("Area")
            if plausible && !(snapshot.enabledPresent && snapshot.enabled == false) {
                // Still refuse to paste into explicitly password/secure surfaces.
                let roleLower = (snapshot.role ?? "").lowercased()
                if roleLower.contains("password") || roleLower.contains("secure") {
                    return (.reportUnsupported, "browser-secure")
                }
                return (.useClipboardPaste, "browser-paste")
            }
            return (.reportUnsupported, "browser-non-editable")
        }
    // Native / non-browser-like: prefer direct AX for classic controls.
    if snapshot.enabledPresent && snapshot.enabled == false {
        return (.reportUnsupported, "disabled")
    }
    if let set = snapshot.selectedTextSettable, set == false,
       let r = snapshot.role, AccessibilityTextRoleSupport.supports(r) {
        return (.reportWriteDenied, "not-settable")
    }
    return (.useDirectAX, "ax-selectedtext")
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

    /// Privacy-safe snapshot of the last insertion decision (roles, attributes presence, chosen path, outcome).
    /// Never includes text, selection, AXValue or clipboard contents.
    var lastDiagnostics: InsertionAttemptDiagnostics? { get }
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

    /// Privacy-safe diagnostics for the most recent insertion attempt (if any).
    /// Only metadata (PIDs, bundles, roles, attribute presence, chosen path, outcome).
    /// Never contains text, selection, field values or clipboard contents.
    public var lastDiagnostics: InsertionAttemptDiagnostics? {
        accessibilityClient.lastDiagnostics
    }
}

@MainActor
private final class SystemTextAccessibilityClient: TextAccessibilityClient {
    private let pasteEngine: ClipboardPasteEngine
    private(set) var lastDiagnostics: InsertionAttemptDiagnostics?

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

        let isTerminal = TerminalApplicationSupport.supports(resolvedBundle)
        let isBrowser = BrowserLikeApplicationSupport.mayBenefitFromPasteFallback(resolvedBundle)

        // Terminal: always paste, record bounded diag, never Return.
        if isTerminal {
            let ok = pasteEngine.pasteUsingClipboardAndCmdV(text: text)
            lastDiagnostics = InsertionAttemptDiagnostics(
                targetPID: processIdentifier,
                targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil,
                frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(),
                focusedRole: nil,
                focusedSubrole: nil,
                enabledAttributePresent: false,
                enabled: nil,
                selectedTextSettable: nil,
                writeAXError: ok ? "success(paste)" : "pasteFailed",
                chosenPath: "terminal-paste",
                finalOutcome: ok ? "inserted" : "writeDenied"
            )
            return ok ? .inserted : .writeDenied
        }

        // Build snapshot for policy and diagnostics (metadata only).
        var snapRole: String?
        var snapSubrole: String?
        var snapEnabledPresent = false
        var snapEnabled: Bool?
        var snapSettable: Bool?

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        if focusResult != .success || focusedValue == nil || CFGetTypeID(focusedValue!) != AXUIElementGetTypeID() {
            lastDiagnostics = InsertionAttemptDiagnostics(
                targetPID: processIdentifier,
                targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil,
                frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(),
                focusedRole: nil,
                focusedSubrole: nil,
                enabledAttributePresent: false,
                enabled: nil,
                selectedTextSettable: nil,
                writeAXError: "noFocusedElement",
                chosenPath: "no-focused-element",
                finalOutcome: "noFocusedElement"
            )
            return .noFocusedElement
        }
        let focusedElement = unsafeDowncast(focusedValue!, to: AXUIElement.self)
        snapRole = Self.stringAttribute(kAXRoleAttribute, from: focusedElement)
        snapSubrole = Self.stringAttribute(kAXSubroleAttribute, from: focusedElement)

        var enabledCF: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXEnabledAttribute as CFString, &enabledCF) == .success,
           let num = enabledCF as? NSNumber {
            snapEnabledPresent = true
            snapEnabled = num.boolValue
        }
        var settableCF: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(focusedElement, kAXSelectedTextAttribute as CFString, &settableCF) == .success {
            snapSettable = settableCF.boolValue
        }

        let snapshot = AXTargetSnapshot(
            role: snapRole,
            subrole: snapSubrole,
            enabledPresent: snapEnabledPresent,
            enabled: snapEnabled,
            selectedTextSettable: snapSettable
        )

        let (action, path) = chooseInsertionAction(snapshot: snapshot, isTerminal: false, isBrowserLike: isBrowser)

        // Guard: never paste into explicitly disabled.
        if action == .useClipboardPaste && snapshot.enabledPresent && snapshot.enabled == false {
            let diag = InsertionAttemptDiagnostics(
                targetPID: processIdentifier, targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil, frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(), focusedRole: snapshot.role, focusedSubrole: snapshot.subrole,
                enabledAttributePresent: snapshot.enabledPresent, enabled: snapshot.enabled,
                selectedTextSettable: snapshot.selectedTextSettable,
                writeAXError: "disabled", chosenPath: path, finalOutcome: "unsupportedControl"
            )
            lastDiagnostics = diag
            return .unsupportedControl
        }

        // Secure/password fields: treat as unsupported for automatic paste (user can manual if appropriate).
        if action == .useClipboardPaste,
           let r = snapshot.role, (r.lowercased().contains("password") || r.lowercased().contains("secure")) {
            let diag = InsertionAttemptDiagnostics(
                targetPID: processIdentifier, targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil, frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(), focusedRole: snapshot.role, focusedSubrole: snapshot.subrole,
                enabledAttributePresent: snapshot.enabledPresent, enabled: snapshot.enabled,
                selectedTextSettable: snapshot.selectedTextSettable,
                writeAXError: "secure", chosenPath: path, finalOutcome: "unsupportedControl"
            )
            lastDiagnostics = diag
            return .unsupportedControl
        }

        switch action {
        case .useClipboardPaste:
            let ok = pasteEngine.pasteUsingClipboardAndCmdV(text: text)
            let outcome = ok ? "inserted" : "writeDenied"
            let diag = InsertionAttemptDiagnostics(
                targetPID: processIdentifier, targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil, frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(), focusedRole: snapshot.role, focusedSubrole: snapshot.subrole,
                enabledAttributePresent: snapshot.enabledPresent, enabled: snapshot.enabled,
                selectedTextSettable: snapshot.selectedTextSettable,
                writeAXError: ok ? "success(paste)" : "pasteFailed", chosenPath: path, finalOutcome: outcome
            )
            lastDiagnostics = diag
            return ok ? .inserted : .writeDenied

        case .useDirectAX:
            // Perform the AX write for native/classic that passed guards.
            // (We already have the element from snapshot construction path; re-fetch minimally.)
            let appElement = AXUIElementCreateApplication(processIdentifier)
            var focusedValue: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
            guard let fv = focusedValue, CFGetTypeID(fv) == AXUIElementGetTypeID() else {
                return .noFocusedElement
            }
            let fe = unsafeDowncast(fv, to: AXUIElement.self)
            let setResult = AXUIElementSetAttributeValue(fe, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
            let writeOk = (setResult == .success)
            let diag = InsertionAttemptDiagnostics(
                targetPID: processIdentifier, targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil, frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(), focusedRole: snapshot.role, focusedSubrole: snapshot.subrole,
                enabledAttributePresent: snapshot.enabledPresent, enabled: snapshot.enabled,
                selectedTextSettable: snapshot.selectedTextSettable,
                writeAXError: writeOk ? "success" : String(describing: setResult),
                chosenPath: path, finalOutcome: writeOk ? "inserted" : "writeDenied"
            )
            lastDiagnostics = diag
            return writeOk ? .inserted : .writeDenied

        case .reportNoFocused:
            let diag = InsertionAttemptDiagnostics(
                targetPID: processIdentifier, targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil, frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(), focusedRole: nil, focusedSubrole: nil,
                enabledAttributePresent: false, enabled: nil, selectedTextSettable: nil,
                writeAXError: "noFocusedElement", chosenPath: path, finalOutcome: "noFocusedElement"
            )
            lastDiagnostics = diag
            return .noFocusedElement

        case .reportUnsupported:
            let diag = InsertionAttemptDiagnostics(
                targetPID: processIdentifier, targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil, frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(), focusedRole: snapshot.role, focusedSubrole: snapshot.subrole,
                enabledAttributePresent: snapshot.enabledPresent, enabled: snapshot.enabled,
                selectedTextSettable: snapshot.selectedTextSettable,
                writeAXError: "unsupported", chosenPath: path, finalOutcome: "unsupportedControl"
            )
            lastDiagnostics = diag
            return .unsupportedControl

        case .reportWriteDenied:
            let diag = InsertionAttemptDiagnostics(
                targetPID: processIdentifier, targetBundle: resolvedBundle,
                frontmostPIDAtCapture: nil, frontmostPIDAtInsert: frontmostProcessIdentifier,
                axTrusted: isTrusted(), focusedRole: snapshot.role, focusedSubrole: snapshot.subrole,
                enabledAttributePresent: snapshot.enabledPresent, enabled: snapshot.enabled,
                selectedTextSettable: snapshot.selectedTextSettable,
                writeAXError: "writeDenied", chosenPath: path, finalOutcome: "writeDenied"
            )
            lastDiagnostics = diag
            return .writeDenied
        }
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
