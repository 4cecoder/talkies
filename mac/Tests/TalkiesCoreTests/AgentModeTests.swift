import XCTest
@testable import TalkiesCore

final class AgentNameMatcherTests: XCTestCase {
    private let matcher = AgentNameMatcher(candidates: [
        AgentNameCandidate(id: "atlas", names: ["Atlas"]),
        AgentNameCandidate(id: "borealis", names: ["Borealis", "Bory"]),
        AgentNameCandidate(id: "juno", names: ["Juno"]),
        AgentNameCandidate(id: "june", names: ["June"]),
    ])

    func testExactNameIsUniqueEvenWithPhoneticNeighbor() {
        XCTAssertEqual(matcher.match("Juno"), .unique(id: "juno", score: 1))
    }

    func testNormalizationIgnoresCaseSpacingAndPunctuation() {
        XCTAssertEqual(matcher.match("  ATLAS! "), .unique(id: "atlas", score: 1))
        XCTAssertEqual(matcher.match("at last"), .unique(id: "atlas", score: AgentNameMatcher.similarity("atlast", "atlas")))
    }

    func testAliasMatches() {
        guard case .unique(let id, _) = matcher.match("bory") else { return XCTFail("Expected alias match") }
        XCTAssertEqual(id, "borealis")
    }

    func testEquallyCloseNamesAreAmbiguous() {
        guard case .ambiguous(let ids) = matcher.match("Jun") else { return XCTFail("Expected ambiguity") }
        XCTAssertEqual(Set(ids), ["juno", "june"])
    }

    func testUnrelatedWordsDoNotMatch() {
        XCTAssertEqual(matcher.match("refactor"), .none)
        XCTAssertEqual(matcher.match(""), .none)
    }

    func testMinimumEditSimilarityRejectsPhoneticOnlyMatches() {
        let rex = AgentNameMatcher(candidates: [AgentNameCandidate(id: "rex", names: ["Rex"])])
        XCTAssertEqual(AgentNameMatcher.phoneticKey("rocks"), AgentNameMatcher.phoneticKey("rex"))
        XCTAssertNotEqual(rex.match("rocks"), .none)
        XCTAssertEqual(rex.match("rocks", minimumEditSimilarity: AgentNameMatcher.leadingNameMinimumEdit), .none)
    }

    func testPhoneticKeyMergesCommonSpellings() {
        XCTAssertEqual(AgentNameMatcher.phoneticKey("Cirrus"), AgentNameMatcher.phoneticKey("Sirius"))
        XCTAssertEqual(AgentNameMatcher.phoneticKey("Borealis"), AgentNameMatcher.phoneticKey("bore alice"))
        XCTAssertEqual(AgentNameMatcher.phoneticKey("Phoebe"), AgentNameMatcher.phoneticKey("Feebee"))
        XCTAssertNotEqual(AgentNameMatcher.phoneticKey("Atlas"), AgentNameMatcher.phoneticKey("Borealis"))
    }

    func testShortPhoneticKeysEarnNoPhoneticCredit() {
        // "my" and "Maya" share the one-sound key "m"; that alone must not make a match.
        XCTAssertLessThan(AgentNameMatcher.similarity("my", "maya"), AgentNameMatcher.addressThreshold)
    }

    func testSpokenNumbers() {
        XCTAssertEqual(AgentSpeechText.number("2"), 2)
        XCTAssertEqual(AgentSpeechText.number("two"), 2)
        XCTAssertEqual(AgentSpeechText.number("to"), 2)
        XCTAssertNil(AgentSpeechText.number("0"))
        XCTAssertNil(AgentSpeechText.number("tests"))
    }
}

final class AgentSafetyGateTests: XCTestCase {
    private let gate = AgentSafetyGate.phase1
    private let cmux: AgentCapabilities = [.list, .read, .prompt, .show]

    func testReadOnlyCommandsRunImmediately() {
        for command in [AgentCommand.status, .list, .readLast] {
            XCTAssertEqual(gate.evaluate(.command(command, argument: nil), capabilities: cmux), .runNow, command.rawValue)
        }
    }

    func testPromptsAndShowWaitForTheTwoSecondCancelWindow() {
        XCTAssertEqual(gate.evaluate(.prompt("Run the tests"), capabilities: cmux), .cancelWindow(seconds: 2))
        XCTAssertEqual(gate.evaluate(.command(.show, argument: nil), capabilities: cmux), .cancelWindow(seconds: 2))
    }

    func testCancelAndSendNowControlThePendingActionImmediately() {
        XCTAssertEqual(gate.evaluate(.command(.cancel, argument: nil), capabilities: cmux), .runNow)
        XCTAssertEqual(gate.evaluate(.command(.send, argument: nil), capabilities: cmux), .runNow)
    }

    func testPhaseOneRefusesApprovalsAndLaterCommands() {
        for command in [AgentCommand.approve, .deny, .confirm, .interrupt, .remember, .recall] {
            XCTAssertEqual(
                gate.evaluate(.command(command, argument: nil), capabilities: .init(rawValue: ~0)),
                .refuse(.notAvailableYet(command)),
                command.rawValue
            )
        }
    }

    func testApprovalRefusalExplainsWhereToAnswer() {
        XCTAssertTrue(AgentGateRefusal.notAvailableYet(.approve).message.contains("Approvals aren't available by voice yet"))
    }

    func testMissingConnectorCapabilityIsRefusedNotFaked() {
        XCTAssertEqual(gate.evaluate(.prompt("hi"), capabilities: [.list]), .refuse(.connectorCannot(.send)))
        XCTAssertEqual(gate.evaluate(.command(.show, argument: nil), capabilities: [.list, .prompt]), .refuse(.connectorCannot(.show)))
        XCTAssertEqual(gate.evaluate(.command(.readLast, argument: nil), capabilities: [.list]), .refuse(.connectorCannot(.readLast)))
    }

    func testPromptToAutoApprovingAgentNeedsConfirmationWhichPhaseOneLacks() {
        XCTAssertEqual(gate.evaluate(.prompt("Delete the build"), capabilities: cmux, targetAutoApproves: true), .refuse(.confirmationUnavailable))
        let later = AgentSafetyGate(enabledCommands: [.approve], allowsConfirmation: true)
        XCTAssertEqual(later.evaluate(.prompt("Delete the build"), capabilities: cmux, targetAutoApproves: true), .confirm(timeoutSeconds: 15))
        XCTAssertEqual(later.evaluate(.command(.approve, argument: nil), capabilities: .approve), .confirm(timeoutSeconds: 15))
    }

    func testTiersMatchTheDesign() {
        XCTAssertEqual(AgentCommand.status.tier, .read)
        XCTAssertEqual(AgentCommand.recall.tier, .read)
        XCTAssertEqual(AgentCommand.show.tier, .reversible)
        XCTAssertEqual(AgentCommand.interrupt.tier, .reversible)
        XCTAssertEqual(AgentCommand.approve.tier, .consequential)
        XCTAssertLessThan(AgentCommand.deny.tier, AgentCommand.approve.tier, "Deny is the safe direction")
    }
}

final class AgentStatusSentenceTests: XCTestCase {
    private let borealis = AgentRef(connector: "cmux", id: "b", name: "Borealis", status: .working, workspace: "talkies", workspaceID: "w")

    func testStatusSentenceMatchesFlowC() {
        let report = AgentStatusReport(agent: borealis, status: .working, inputState: .empty, waitingOnHuman: false)
        XCTAssertEqual(AgentStatusSentence.make(report, number: 2), "Agent 2, Borealis, in workspace talkies: working. No questions waiting.")
    }

    func testWorkspaceIsOmittedWhenItIsTheName() {
        let atlas = AgentRef(connector: "cmux", id: "a", name: "Atlas", workspace: "Atlas")
        let report = AgentStatusReport(agent: atlas, status: .idle, inputState: .draft, waitingOnHuman: false)
        XCTAssertEqual(AgentStatusSentence.make(report, number: nil), "Atlas: idle. No questions waiting. A draft is open.")
    }

    func testWaitingAgentSaysAQuestionIsWaiting() {
        let report = AgentStatusReport(agent: borealis, status: .needsInput, inputState: .dialog, waitingOnHuman: true)
        XCTAssertEqual(AgentStatusSentence.make(report, number: nil), "Borealis, in workspace talkies: waiting for your answer. A question is waiting.")
    }

    func testListSentence() {
        let atlas = AgentRef(connector: "cmux", id: "a", name: "Atlas", status: .idle)
        XCTAssertEqual(AgentStatusSentence.list([atlas, borealis]), "2 agents. 1, Atlas, idle. 2, Borealis, working.")
        XCTAssertEqual(AgentStatusSentence.list([]), "No agents are running.")
    }

    func testSpokenExcerptCutsAtSentenceBoundary() {
        let text = "First sentence here. Second sentence follows. Third one is long enough to cross."
        XCTAssertEqual(AgentStatusSentence.spokenExcerpt(text, maxWords: 6), "First sentence here. Second sentence follows. More on the screen.")
        XCTAssertEqual(AgentStatusSentence.spokenExcerpt("Short reply.", maxWords: 6), "Short reply.")
    }
}

final class AgentHotkeyTests: XCTestCase {
    func testAgentHotkeyConflictsOnlyWithTheSamePhysicalKey() {
        XCTAssertTrue(AgentHotkey.rightOption.conflicts(with: .rightOption))
        XCTAssertFalse(AgentHotkey.leftOption.conflicts(with: .rightOption))
        XCTAssertFalse(AgentHotkey.rightCommand.conflicts(with: .rightOption))
    }

    func testDeviceMasksAreDistinct() {
        let masks = AgentHotkey.allCases.map(\.deviceFlagMask)
        XCTAssertEqual(Set(masks).count, masks.count)
    }

    func testDictationModeNeverParsesCommands() {
        let parser = AgentIntentParser(candidates: [AgentNameCandidate(id: "atlas", names: ["Atlas"])])
        XCTAssertEqual(CaptureRouter.route("Atlas, approve", mode: .dictation, parser: parser), .insert("Atlas, approve"))
        XCTAssertEqual(
            CaptureRouter.route("Atlas, approve", mode: .agent, parser: parser),
            .agent(AgentUtterance(address: .agent(id: "atlas"), intent: .command(.approve, argument: nil)))
        )
    }
}
