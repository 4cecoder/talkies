import XCTest
@testable import TalkiesAccessibility

@MainActor
final class TextInserterTests: XCTestCase {
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

    func testSuccessfulInsertionTargetsCapturedFocusedApplication() async {
        let client = MockTextAccessibilityClient()
        let inserter = TextInserter(accessibilityClient: client)
        let destination = TextInsertionDestination(processIdentifier: 4242, applicationName: "Notes")

        let result = await inserter.insertTextAtCursor("Hello there.", into: destination)

        XCTAssertEqual(result, .inserted(applicationName: "Notes"))
        XCTAssertEqual(client.insertedText, "Hello there.")
        XCTAssertEqual(client.insertionProcessIdentifier, destination.processIdentifier)
    }

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

@MainActor
private final class MockTextAccessibilityClient: TextAccessibilityClient {
    let currentProcessIdentifier: pid_t = 1234
    var frontmostProcessIdentifier: pid_t? = 4242
    var frontmostApplicationValue: (pid_t, String)? = (4242, "Notes")
    var trusted = true
    var insertionAttempt: FocusedTextInsertionAttempt = .inserted
    private(set) var didCheckTrust = false
    private(set) var insertedText: String?
    private(set) var attemptedText: String?
    private(set) var insertionProcessIdentifier: pid_t?

    func frontmostApplication() -> (processIdentifier: pid_t, name: String)? {
        guard let frontmostApplicationValue else { return nil }
        return (frontmostApplicationValue.0, frontmostApplicationValue.1)
    }

    func isTrusted() -> Bool {
        didCheckTrust = true
        return trusted
    }

    func setSelectedText(_ text: String, in processIdentifier: pid_t) -> FocusedTextInsertionAttempt {
        attemptedText = text
        insertionProcessIdentifier = processIdentifier
        if insertionAttempt == .inserted {
            insertedText = text
        }
        return insertionAttempt
    }
}
