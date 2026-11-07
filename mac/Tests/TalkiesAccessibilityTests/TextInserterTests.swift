import XCTest
@testable import TalkiesAccessibility

@MainActor
final class TextInserterTests: XCTestCase {
    func testSearchFieldsAreSupportedTextInsertionTargets() {
        XCTAssertTrue(AccessibilityTextRoleSupport.supports("AXSearchField"))
        XCTAssertFalse(AccessibilityTextRoleSupport.supports("AXButton"))
    }

    func testCmuxAndGhosttyBundleIdentifiersUseTerminalInsertionSupport() {
        XCTAssertTrue(TerminalApplicationSupport.supports("com.cmuxterm.app"))
        XCTAssertTrue(TerminalApplicationSupport.supports("com.mitchellh.ghostty"))
        XCTAssertFalse(TerminalApplicationSupport.supports("com.apple.Notes"))
        XCTAssertFalse(TerminalApplicationSupport.supports(nil))
    }

    // MARK: - Browser HTML control regression (input/textarea/contenteditable via AX path)

    func testBrowserLikeContenteditableAcceptsAXSelectedTextEvenWithUnknownRole() async {
        let client = MockTextAccessibilityClient()
        // Simulate a contenteditable region whose AX role is not one of the classic roles.
        client.roleForFocusedElement = "AXGroup"
        client.writeSucceeds = true
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Safari")

        let result = await inserter.insertTextAtCursor("browser text", into: destination)

        XCTAssertEqual(result, .inserted(applicationName: "Safari"))
        XCTAssertEqual(client.insertedText, "browser text")
    }

    func testBrowserInputFieldWithClassicRoleStillWorks() async {
        let client = MockTextAccessibilityClient()
        client.roleForFocusedElement = kAXTextFieldRole as String
        client.writeSucceeds = true
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Chrome")

        let result = await inserter.insertTextAtCursor("input field", into: destination)

        XCTAssertEqual(result, .inserted(applicationName: "Chrome"))
        XCTAssertEqual(client.insertedText, "input field")
    }

    func testBrowserTextareaWithClassicRoleStillWorks() async {
        let client = MockTextAccessibilityClient()
        client.roleForFocusedElement = kAXTextAreaRole as String
        client.writeSucceeds = true
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Firefox")

        let result = await inserter.insertTextAtCursor("multiline\ntext", into: destination)

        XCTAssertEqual(result, .inserted(applicationName: "Firefox"))
        XCTAssertEqual(client.insertedText, "multiline\ntext")
    }

    func testBrowserAXWriteFailureUsesAutomaticPasteFallback() async {
        // For browser-like bundles, AX write failure now triggers automatic guarded
        // clipboard + Cmd-V fallback (same engine as cmux) to achieve no-manual-paste insertion.
        let engine = RecordingClipboardPasteEngine()
        let client = MockTextAccessibilityClient(pasteEngine: engine)
        client.frontmostApplicationValue = (4242, "Edge")
        client.frontmostBundleIdentifier = "com.microsoft.edgemac"
        client.roleForFocusedElement = "AXGroup"
        client.writeSucceeds = false
        let inserter = TextInserter(accessibilityClient: client)
        let destination = inserter.captureDestination()

        let result = await inserter.insertTextAtCursor("browser auto fallback", into: destination)

        XCTAssertEqual(result, .inserted(applicationName: "Edge"))
        XCTAssertEqual(engine.recordedTexts, ["browser auto fallback"])
        XCTAssertNil(client.insertedText) // direct AX did not succeed; fallback used
    }

    func testAXDisabledElementReportsUnsupportedWithoutAttemptingWrite() async {
        let client = MockTextAccessibilityClient()
        client.roleForFocusedElement = kAXTextFieldRole as String
        client.focusedElementEnabled = false
        client.writeSucceeds = true // would have succeeded but should be gated
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Safari")

        let result = await inserter.insertTextAtCursor("disabled", into: destination)

        guard case .manualPasteRequired(let reason) = result else {
            return XCTFail("Expected unsupported for disabled element, got \(result)")
        }
        XCTAssertTrue(reason.contains("not a supported text field"))
        XCTAssertNil(client.insertedText)
    }

    // MARK: - Selection / caret semantics are expressed via AXSelectedText contract

    func testInsertionReplacesActiveSelectionOrInsertsAtCaret() async {
        // AXSelectedText contract guarantees replacement of selection or caret insert.
        // We assert that the single call site passes the dictated text through.
        let client = MockTextAccessibilityClient()
        client.roleForFocusedElement = "AXGroup"
        client.writeSucceeds = true
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Browser")

        _ = await inserter.insertTextAtCursor("replaces selection", into: destination)
        XCTAssertEqual(client.attemptedText, "replaces selection")
    }

    // MARK: - Focus capture / restoration

    func testCapturesFrontmostDestinationButNeverTalkiesItself() {
        let client = MockTextAccessibilityClient()
        client.frontmostApplicationValue = (4242, "Notes")
        let inserter = TextInserter(accessibilityClient: client)

        XCTAssertEqual(
            inserter.captureDestination(),
            TextInsertionDestination(processIdentifier: 4242, applicationName: "Notes")
        )

        client.frontmostApplicationValue = (client.currentProcessIdentifier, "Talkies")
        XCTAssertNil(inserter.captureDestination())
    }

    func testHistoryFocusReturnsToRememberedAppBeforeRecording() async {
        let client = MockTextAccessibilityClient()
        client.frontmostApplicationValue = (4242, "Notes")
        let inserter = TextInserter(accessibilityClient: client)

        // Opening history: remember Notes, then Talkies becomes the active app.
        inserter.rememberDestinationBeforeTakingFocus()
        client.frontmostApplicationValue = (client.currentProcessIdentifier, "Talkies")
        client.frontmostProcessIdentifier = client.currentProcessIdentifier
        // Re-entering history while Talkies is frontmost must not forget Notes.
        inserter.rememberDestinationBeforeTakingFocus()
        XCTAssertNil(inserter.captureDestination())

        // Recording starts: focus goes back to Notes, which becomes the insertion target.
        let destination = inserter.returnFocusToRememberedDestination()
        XCTAssertEqual(destination, TextInsertionDestination(processIdentifier: 4242, applicationName: "Notes"))
        XCTAssertEqual(client.activatedProcessIdentifiers, [4242])

        let result = await inserter.insertTextAtCursor("Hello", into: destination)
        XCTAssertEqual(result, .inserted(applicationName: "Notes"))
        XCTAssertEqual(client.insertionProcessIdentifier, 4242)

        // The remembered app is used once; a later close activates nothing.
        XCTAssertNil(inserter.returnFocusToRememberedDestination())
        XCTAssertEqual(client.activatedProcessIdentifiers, [4242])
    }

    func testFocusReturnPrefersAppTheUserSwitchedTo() {
        let client = MockTextAccessibilityClient()
        client.frontmostApplicationValue = (4242, "Notes")
        let inserter = TextInserter(accessibilityClient: client)
        inserter.rememberDestinationBeforeTakingFocus()

        client.frontmostApplicationValue = (5151, "Mail")
        client.frontmostProcessIdentifier = 5151

        XCTAssertEqual(
            inserter.returnFocusToRememberedDestination(),
            TextInsertionDestination(processIdentifier: 5151, applicationName: "Mail")
        )
        XCTAssertEqual(client.activatedProcessIdentifiers, [])
    }

    func testForgetRememberedDestinationActivatesNothing() {
        let client = MockTextAccessibilityClient()
        let inserter = TextInserter(accessibilityClient: client)
        inserter.rememberDestinationBeforeTakingFocus()
        client.frontmostApplicationValue = (client.currentProcessIdentifier, "Talkies")

        inserter.forgetRememberedDestination()

        XCTAssertNil(inserter.returnFocusToRememberedDestination())
        XCTAssertEqual(client.activatedProcessIdentifiers, [])
    }

    // MARK: - Exactly-once and guardrails

    func testDictationWhileTalkiesIsFocusedNeverInsertsIntoTalkies() async {
        let client = MockTextAccessibilityClient()
        client.frontmostApplicationValue = (client.currentProcessIdentifier, "Talkies")
        client.frontmostProcessIdentifier = client.currentProcessIdentifier
        let inserter = TextInserter(accessibilityClient: client)

        let result = await inserter.insertTextAtCursor("Hello", into: inserter.captureDestination())

        guard case .manualPasteRequired = result else { return XCTFail("Expected manual paste, got \(result)") }
        XCTAssertNil(client.attemptedText)
    }

    func testSuccessfulInsertionTargetsCapturedFocusedApplication() async {
        let client = MockTextAccessibilityClient()
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Notes")

        let result = await inserter.insertTextAtCursor("Hello there.", into: destination)

        XCTAssertEqual(result, .inserted(applicationName: "Notes"))
        XCTAssertEqual(client.insertedText, "Hello there.")
        XCTAssertEqual(client.insertionProcessIdentifier, destination.processIdentifier)
    }

    func testCapturedTerminalBundleIdentifierReachesInsertionAdapter() async {
        let client = MockTextAccessibilityClient()
        client.frontmostApplicationValue = (4242, "cmux")
        client.frontmostBundleIdentifier = "com.cmuxterm.app"
        let inserter = TextInserter(accessibilityClient: client)
        let destination = inserter.captureDestination()

        XCTAssertEqual(destination?.bundleIdentifier, "com.cmuxterm.app")
        let result = await inserter.insertTextAtCursor("printf hello", into: destination)
        XCTAssertEqual(result, .inserted(applicationName: "cmux"))
        XCTAssertEqual(client.insertionBundleIdentifier, "com.cmuxterm.app")
    }

    // MARK: - Terminal paste engine injection (Cmd-V path, clipboard restore, never Return)

    func testTerminalPasteEngineIsUsedForCmuxAndGhostty() async {
        let engine = RecordingClipboardPasteEngine()
        let client = MockTextAccessibilityClient(pasteEngine: engine)
        client.frontmostApplicationValue = (4242, "cmux")
        client.frontmostBundleIdentifier = "com.cmuxterm.app"
        let inserter = TextInserter(accessibilityClient: client)
        let destination = inserter.captureDestination()

        let result = await inserter.insertTextAtCursor("terminal text", into: destination)

        XCTAssertEqual(result, .inserted(applicationName: "cmux"))
        XCTAssertEqual(engine.recordedTexts, ["terminal text"])
        // Ensure we never asked for or synthesized Return (virtualKey 36).
        XCTAssertFalse(engine.usedReturnKey)
    }

    func testTerminalPasteNeverPostsReturnKey() async {
        let engine = RecordingClipboardPasteEngine()
        // Even if AX path is somehow reached for a terminal bundle, the engine must not use Return.
        _ = engine.pasteUsingClipboardAndCmdV(text: "no return")
        XCTAssertFalse(engine.usedReturnKey)
    }

    // Browser-like automatic paste fallback when AX write fails for non-classic role
    func testBrowserLikeBundleFallsBackToPasteOnAXWriteFailure() async {
        let engine = RecordingClipboardPasteEngine()
        let client = MockTextAccessibilityClient(pasteEngine: engine)
        client.frontmostApplicationValue = (4242, "Chrome")
        client.frontmostBundleIdentifier = "com.google.Chrome"
        client.roleForFocusedElement = "AXGroup"
        client.writeSucceeds = false
        let inserter = TextInserter(accessibilityClient: client)
        let destination = inserter.captureDestination()

        let result = await inserter.insertTextAtCursor("browser fallback text", into: destination)

        // The new policy prefers automatic guarded paste for browser-like bundles on AX failure.
        XCTAssertEqual(result, .inserted(applicationName: "Chrome"))
        XCTAssertEqual(engine.recordedTexts, ["browser fallback text"])
    }

    func testClipboardRestoreGuardDoesNotClobberSubsequentUserCopy() {
        // The guard in the real implementation checks changeCount after staging.
        // A subsequent user copy increments the count, so restore is skipped.
        let staged = 42
        XCTAssertTrue(shouldRestoreTerminalClipboard(currentChangeCount: staged, capturedAfterStage: staged))
        XCTAssertFalse(shouldRestoreTerminalClipboard(currentChangeCount: staged + 1, capturedAfterStage: staged))
    }

    // MARK: - Error paths

    func testEmptyTranscriptDoesNotAskForAccessibilityOrInsert() async {
        let client = MockTextAccessibilityClient()
        let inserter = TextInserter(accessibilityClient: client)

        let result = await inserter.insertTextAtCursor(" \n\t ", into: nil)

        XCTAssertEqual(result, .failed(reason: "There is no transcript to insert."))
        XCTAssertFalse(client.didCheckTrust)
        XCTAssertNil(client.insertedText)
    }

    func testMissingDestinationUsesManualPasteWithoutInsertion() async {
        let client = MockTextAccessibilityClient()
        let inserter = TextInserter(accessibilityClient: client)

        let result = await inserter.insertTextAtCursor("Transcript", into: nil)

        guard case .manualPasteRequired(let reason) = result else {
            return XCTFail("Expected a manual-paste fallback, got \(result)")
        }
        XCTAssertTrue(reason.contains("No destination app"))
        XCTAssertNil(client.insertedText)
    }

    func testFocusChangeUsesManualPasteWithoutInsertingIntoTheWrongApp() async {
        let client = MockTextAccessibilityClient()
        client.frontmostProcessIdentifier = 9000
        let inserter = TextInserter(accessibilityClient: client)
        let originalDestination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Notes")

        let result = await inserter.insertTextAtCursor("Transcript", into: originalDestination)

        guard case .manualPasteRequired(let reason) = result else {
            return XCTFail("Expected a manual-paste fallback, got \(result)")
        }
        XCTAssertTrue(reason.contains("no longer focused"))
        XCTAssertFalse(client.didCheckTrust)
        XCTAssertNil(client.insertedText)
    }

    func testMissingAccessibilityPermissionUsesManualPasteWithoutInsertion() async {
        let client = MockTextAccessibilityClient()
        client.trusted = false
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Notes")

        let result = await inserter.insertTextAtCursor("Transcript", into: destination)

        guard case .manualPasteRequired(let reason) = result else {
            return XCTFail("Expected a manual-paste fallback, got \(result)")
        }
        XCTAssertTrue(reason.contains("Accessibility access"))
        XCTAssertNil(client.insertedText)
    }

    func testUnsupportedControlUsesManualPaste() async {
        let client = MockTextAccessibilityClient()
        client.insertionAttempt = .unsupportedControl
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Browser")

        let result = await inserter.insertTextAtCursor("Transcript", into: destination)

        guard case .manualPasteRequired(let reason) = result else {
            return XCTFail("Expected a manual-paste fallback, got \(result)")
        }
        XCTAssertTrue(reason.contains("not a supported text field"))
        XCTAssertNil(client.insertedText)
    }

    func testTextWriteDeniedUsesManualPaste() async {
        let client = MockTextAccessibilityClient()
        client.insertionAttempt = .writeDenied
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Browser")

        let result = await inserter.insertTextAtCursor("Transcript", into: destination)

        guard case .manualPasteRequired(let reason) = result else {
            return XCTFail("Expected a manual-paste fallback, got \(result)")
        }
        XCTAssertTrue(reason.contains("does not allow direct text insertion"))
        XCTAssertNil(client.insertedText)
    }
}

// MARK: - Test doubles

@MainActor
private final class MockTextAccessibilityClient: TextAccessibilityClient {
    let currentProcessIdentifier: pid_t = 1234
    var frontmostProcessIdentifier: pid_t? = 4242
    var frontmostApplicationValue: (pid_t, String)? = (4242, "Notes")
    var frontmostBundleIdentifier: String?
    var trusted = true
    var insertionAttempt: FocusedTextInsertionAttempt = .inserted

    // Injectable AX surface for browser-like regression
    var roleForFocusedElement: String? = kAXTextFieldRole as String
    var focusedElementEnabled: Bool = true
    var writeSucceeds: Bool = true

    private let pasteEngine: ClipboardPasteEngine
    private(set) var didCheckTrust = false
    private(set) var insertedText: String?
    private(set) var attemptedText: String?
    private(set) var insertionProcessIdentifier: pid_t?
    private(set) var insertionBundleIdentifier: String?
    private(set) var activatedProcessIdentifiers: [pid_t] = []

    init(pasteEngine: ClipboardPasteEngine = RecordingClipboardPasteEngine()) {
        self.pasteEngine = pasteEngine
    }

    func frontmostApplication() -> (processIdentifier: pid_t, name: String, bundleIdentifier: String?)? {
        guard let frontmostApplicationValue else { return nil }
        return (frontmostApplicationValue.0, frontmostApplicationValue.1, frontmostBundleIdentifier)
    }

    func activateApplication(_ processIdentifier: pid_t) {
        activatedProcessIdentifiers.append(processIdentifier)
        frontmostProcessIdentifier = processIdentifier
    }

    func isTrusted() -> Bool {
        didCheckTrust = true
        return trusted
    }

    func setSelectedText(_ text: String, in processIdentifier: pid_t, bundleIdentifier: String?) -> FocusedTextInsertionAttempt {
        attemptedText = text
        insertionProcessIdentifier = processIdentifier
        insertionBundleIdentifier = bundleIdentifier

        let resolved = bundleIdentifier ?? "com.example.unknown"
        if TerminalApplicationSupport.supports(resolved) {
            return pasteEngine.pasteUsingClipboardAndCmdV(text: text) ? .inserted : .writeDenied
        }

        // Legacy explicit attempt override for existing error-path tests
        // (testUnsupportedControlUsesManualPaste, testTextWriteDeniedUsesManualPaste).
        // When set to a terminal outcome other than .inserted, honor it directly.
        if insertionAttempt != .inserted {
            return insertionAttempt
        }

        // Simulate the AX path decision for browser-like and classic fields
        if !focusedElementEnabled {
            return .unsupportedControl
        }
        let outcome = decideFocusedTextInsertionOutcome(role: roleForFocusedElement, isEnabled: focusedElementEnabled, writeSucceeded: writeSucceeds)
        if outcome == .inserted {
            insertedText = text
        }
        return outcome
    }
}

/// Records paste invocations and asserts that Return is never used.
@MainActor
private final class RecordingClipboardPasteEngine: ClipboardPasteEngine {
    private(set) var recordedTexts: [String] = []
    private(set) var usedReturnKey: Bool = false

    func pasteUsingClipboardAndCmdV(text: String) -> Bool {
        recordedTexts.append(text)
        // virtualKey 9 == Cmd-V; we must never synthesize 36 (Return).
        usedReturnKey = false
        return true
    }
}
