import Foundation
import XCTest
import TalkiesCore
@testable import Talkies

/// Agent-mode controller behavior with a fake connector: the cancel window, held sends,
/// cancel, explicit send, refusals, and "Which agent?".
@MainActor
final class AgentModeControllerTests: XCTestCase {
    private let atlas = AgentRef(connector: "fake", id: "atlas", name: "Atlas", status: .working, workspace: "Atlas", workspaceID: "w1")
    private let borealis = AgentRef(connector: "fake", id: "borealis", name: "Borealis", status: .idle, workspace: "Borealis", workspaceID: "w2")
    private var spoken: [String] = []
    private var speechOn = true

    private func makeController(_ connector: FakeAgentConnector, window: Double = 0.2) -> AgentModeController {
        AgentModeController(
            connector: connector,
            cancelWindowSeconds: window,
            speechEnabled: { [unowned self] in self.speechOn },
            speaker: { [unowned self] text in self.spoken.append(text) },
            confirmationSound: {}
        )
    }

    private func waitUntil(_ timeout: Double = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func noticeText(_ controller: AgentModeController) -> String? {
        if case .notice(let notice) = controller.phase { return notice.text }
        return nil
    }

    private func pending(_ controller: AgentModeController) -> AgentModeController.PendingAction? {
        if case .pending(let pending) = controller.phase { return pending }
        return nil
    }

    func testPromptWaitsForTheCancelWindowThenDelivers() async {
        let connector = FakeAgentConnector(agents: [atlas, borealis])
        let controller = makeController(connector)

        await controller.handle("Atlas, run the tests")
        XCTAssertEqual(pending(controller)?.kind, .prompt("Run the tests"))
        XCTAssertEqual(pending(controller)?.agent.id, "atlas")
        XCTAssertTrue(connector.prompts.isEmpty, "Nothing is sent during the cancel window")

        await waitUntil { !connector.prompts.isEmpty }
        XCTAssertEqual(connector.prompts.map(\.text), ["Run the tests"])
        XCTAssertEqual(connector.prompts.map(\.agent), ["atlas"])
        await waitUntil { self.noticeText(controller) != nil }
        XCTAssertEqual(noticeText(controller), "Sent to Atlas.")
        XCTAssertEqual(controller.selectedTargetID, "atlas", "Addressing selects the target")
    }

    func testCancelDuringTheWindowSendsNothing() async throws {
        let connector = FakeAgentConnector(agents: [atlas])
        let controller = makeController(connector)
        await controller.handle("Atlas, run the tests")
        controller.cancelPending()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(connector.prompts.isEmpty)
        XCTAssertEqual(noticeText(controller), "Cancelled. Nothing was sent to Atlas.")
    }

    func testHeldSendNeverFiresWithoutAnExplicitSend() async throws {
        let connector = FakeAgentConnector(agents: [atlas])
        let controller = makeController(connector)
        await controller.handle("Atlas, run the tests")

        controller.beginListening() // agent key pressed during the window
        XCTAssertEqual(pending(controller)?.isHeld, true)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(connector.prompts.isEmpty)

        // An empty or failed capture keeps the send held; it does not restart the countdown.
        controller.captureEndedWithoutSpeech()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(connector.prompts.isEmpty)
        XCTAssertEqual(pending(controller)?.isHeld, true)

        await controller.handle("send")
        XCTAssertEqual(connector.prompts.map(\.text), ["Run the tests"])
    }

    func testSpokenCancelCancelsAHeldSend() async throws {
        let connector = FakeAgentConnector(agents: [atlas])
        let controller = makeController(connector)
        await controller.handle("Atlas, run the tests")
        controller.beginListening()
        await controller.handle("Cancel.")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(connector.prompts.isEmpty)
        XCTAssertEqual(noticeText(controller), "Cancelled. Nothing was sent to Atlas.")
        XCTAssertEqual(connector.listCalls, 1, "cancel acts without another cmux call")
    }

    func testSendAddressedToAnotherAgentDoesNotFire() async throws {
        let connector = FakeAgentConnector(agents: [atlas, borealis])
        let controller = makeController(connector)
        await controller.handle("Atlas, run the tests")
        controller.beginListening()

        await controller.handle("Borealis, send")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertTrue(connector.prompts.isEmpty)
        XCTAssertEqual(pending(controller)?.isHeld, true)
        XCTAssertTrue(pending(controller)?.note?.contains("for Atlas") == true)

        await controller.handle("Atlas, send")
        XCTAssertEqual(connector.prompts.map(\.agent), ["atlas"])
    }

    func testDictationHoldsAPendingSendAndHidesThePanel() async throws {
        let connector = FakeAgentConnector(agents: [atlas])
        let controller = makeController(connector)
        await controller.handle("Atlas, run the tests")
        controller.dictationStarted()
        XCTAssertFalse(controller.showsPanel, "The dictation status stays visible")
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(connector.prompts.isEmpty, "A send never fires unseen during dictation")
        XCTAssertEqual(pending(controller)?.isHeld, true)

        controller.beginListening()
        XCTAssertTrue(controller.showsPanel)
    }

    func testDraftRefusalExplainsAndSendsNothing() async {
        let connector = FakeAgentConnector(agents: [atlas], promptResult: .refused(.draftOpen))
        let controller = makeController(connector)
        await controller.handle("Atlas, run the tests")
        await controller.firePendingNow()
        XCTAssertTrue(noticeText(controller)?.contains("Atlas has a draft open, so nothing was sent") == true)
        XCTAssertFalse(connector.delivered)
    }

    func testApprovalIsRefusedInPhaseOne() async {
        let connector = FakeAgentConnector(agents: [atlas])
        let controller = makeController(connector)
        await controller.handle("Atlas, approve")
        XCTAssertTrue(noticeText(controller)?.hasPrefix("Approvals aren't available by voice yet") == true)
        XCTAssertTrue(connector.prompts.isEmpty, "A refused command is never sent as prompt text")
    }

    func testAmbiguousNameAsksAndChoiceMatchesById() async {
        let cirrus = AgentRef(connector: "fake", id: "cirrus", name: "Cirrus", aliases: ["Shared"], status: .idle, workspace: "Shared")
        let dorado = AgentRef(connector: "fake", id: "dorado", name: "Dorado", aliases: ["Shared"], status: .idle, workspace: "Shared")
        let connector = FakeAgentConnector(agents: [cirrus, dorado])
        let controller = makeController(connector)

        await controller.handle("Shared, status")
        guard case .choosing(let candidates, _) = controller.phase else { return XCTFail("Expected Which agent?") }
        XCTAssertEqual(Set(candidates.map(\.id)), ["cirrus", "dorado"])
        XCTAssertEqual(spoken.last, "Which agent? Cirrus or Dorado.")

        // The list was refreshed since: same agent, different status.
        let refreshed = AgentRef(connector: "fake", id: "dorado", name: "Dorado", aliases: ["Shared"], status: .working, workspace: "Shared")
        controller.select(refreshed)
        await waitUntil { self.noticeText(controller) != nil }
        XCTAssertEqual(noticeText(controller), "Agent 2, Dorado, in workspace Shared: working. No questions waiting.")
    }

    func testStatusIsSpokenOnlyWhenEnabled() async {
        let connector = FakeAgentConnector(agents: [atlas])
        let controller = makeController(connector)
        await controller.handle("What's Atlas doing?")
        XCTAssertEqual(spoken.last, "Agent 1, Atlas: working. No questions waiting.")

        speechOn = false
        spoken.removeAll()
        await controller.handle("Atlas, status")
        XCTAssertEqual(noticeText(controller), "Agent 1, Atlas: working. No questions waiting.")
        XCTAssertTrue(spoken.isEmpty)
    }

    func testUnaddressedPromptWithoutTargetAsks() async {
        let connector = FakeAgentConnector(agents: [atlas, borealis])
        let controller = makeController(connector)
        await controller.handle("Run the tests")
        guard case .choosing = controller.phase else { return XCTFail("Talkies must ask, not guess") }
        XCTAssertTrue(connector.prompts.isEmpty)
    }
}

/// In-memory connector for controller tests.
final class FakeAgentConnector: AgentConnector, @unchecked Sendable {
    let id = "fake"
    let displayName = "cmux"
    let capabilities: AgentCapabilities = [.list, .read, .prompt, .show]

    private let lock = NSLock()
    private let agentList: [AgentRef]
    private let promptResult: AgentDeliveryResult
    private var recordedPrompts: [(agent: String, text: String)] = []
    private var lists = 0

    init(agents: [AgentRef], promptResult: AgentDeliveryResult = .delivered) {
        agentList = agents
        self.promptResult = promptResult
    }

    var prompts: [(agent: String, text: String)] { lock.withLock { recordedPrompts } }
    var listCalls: Int { lock.withLock { lists } }
    var delivered: Bool { promptResult == .delivered && !prompts.isEmpty }

    func list() async throws -> [AgentRef] {
        lock.withLock { lists += 1 }
        return agentList
    }

    func status(of agent: AgentRef) async throws -> AgentStatusReport {
        AgentStatusReport(agent: agent, status: agent.status, inputState: .empty, waitingOnHuman: false)
    }

    func readLast(_ agent: AgentRef, lines: Int) async throws -> String { "Done." }

    func prompt(_ agent: AgentRef, text: String) async throws -> AgentDeliveryResult {
        if promptResult == .delivered {
            lock.withLock { recordedPrompts.append((agent.id, text)) }
        }
        return promptResult
    }

    func show(_ agent: AgentRef) async throws {}
}
