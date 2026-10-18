import Foundation
import XCTest
import TalkiesCore
@testable import TalkiesConnectors

/// cmux connector tests against JSON recorded from cmux 0.65.0 (`tests/fixtures/agents/cmux/`).
/// None of these tests needs cmux installed or running.
final class CmuxConnectorTests: XCTestCase {
    private static let atlasAgent = "9B766A7B-559D-54FF-A1ED-5F7E6414BFB1"
    private static let atlasShell = "964DE941-37C8-5EB0-AF5D-76337CE12E5F"
    private static let atlasWorkspace = "7773831C-DE1F-58C7-9EE3-2151D8BCE530"
    private static let borealisAgent = "870628FA-AB8F-59A4-892A-E5E20D9D0B72"
    private static let cirrusAgent = "82B0AF2B-36DD-5E20-BC27-066E3007981E"
    private static let doradoAgent = "E4A28BE3-D050-5777-9BD8-4B1843835B97"

    // MARK: - Argument building

    func testArgumentsUseUUIDHandlesAndNoShell() throws {
        XCTAssertEqual(CmuxArguments.tree(), ["--json", "--id-format", "uuids", "tree", "--all"])
        XCTAssertEqual(CmuxArguments.notifications(), ["--json", "--id-format", "uuids", "list-notifications"])
        XCTAssertEqual(
            try CmuxArguments.inputState(surfaceID: Self.atlasAgent),
            ["rpc", "surface.input_state", "{\"surface_id\":\"\(Self.atlasAgent)\"}"]
        )
        XCTAssertEqual(
            try CmuxArguments.readScreen(workspaceID: Self.atlasWorkspace, surfaceID: Self.atlasAgent, lines: 40),
            ["read-screen", "--workspace", Self.atlasWorkspace, "--surface", Self.atlasAgent, "--lines", "40"]
        )
        XCTAssertEqual(
            try CmuxArguments.focusPanel(workspaceID: Self.atlasWorkspace, surfaceID: Self.atlasAgent),
            ["focus-panel", "--panel", Self.atlasAgent, "--workspace", Self.atlasWorkspace]
        )
    }

    func testAgentMessageReadsTextFromStdinAndNeverForces() throws {
        let arguments = try CmuxArguments.agentMessage(surfaceID: Self.atlasAgent)
        XCTAssertEqual(arguments, ["agent", "message", Self.atlasAgent, "--from", "Talkies", "-"])
        XCTAssertFalse(arguments.contains("--force"))
    }

    func testNonUUIDHandlesAreRejectedSoTheyCannotBecomeFlags() {
        XCTAssertThrowsError(try CmuxArguments.agentMessage(surfaceID: "--force"))
        XCTAssertThrowsError(try CmuxArguments.inputState(surfaceID: "workspace:2"))
    }

    func testLocatorPrefersAppBundleThenPath() {
        let candidates = CmuxExecutableLocator.candidates(environment: ["PATH": "/custom/bin:/usr/bin"], homeDirectory: "/Users/me")
        XCTAssertEqual(candidates.first, "/Applications/cmux.app/Contents/Resources/bin/cmux")
        XCTAssertTrue(candidates.contains("/custom/bin/cmux"))
        XCTAssertEqual(
            CmuxExecutableLocator.locate(environment: ["PATH": "/custom/bin"], homeDirectory: "/Users/me", isExecutable: { $0 == "/custom/bin/cmux" }),
            URL(fileURLWithPath: "/custom/bin/cmux")
        )
        XCTAssertNil(CmuxExecutableLocator.locate(environment: [:], homeDirectory: "/Users/me", isExecutable: { _ in false }))
    }

    func testLocatorIgnoresRelativePathEntries() {
        let candidates = CmuxExecutableLocator.candidates(environment: ["PATH": "bin:.:/abs/bin:"], homeDirectory: "/Users/me")
        XCTAssertTrue(candidates.allSatisfy { $0.hasPrefix("/") })
        XCTAssertTrue(candidates.contains("/abs/bin/cmux"))
        XCTAssertNil(CmuxExecutableLocator.locate(environment: ["PATH": "bin"], homeDirectory: "/Users/me", isExecutable: { $0 == "bin/cmux" }))
    }

    func testListingCapsParallelCmuxCalls() async throws {
        let runner = try FakeCmux()
        _ = try await CmuxConnector(executable: FakeCmux.executable, runner: runner).list()
        XCTAssertEqual(runner.calls.filter { $0.arguments.first == "rpc" }.count, 6)
        XCTAssertLessThanOrEqual(runner.peakConcurrentRPCs, CmuxConnector.maxConcurrentCalls)
        XCTAssertGreaterThan(runner.peakConcurrentRPCs, 1, "Calls still run in parallel")
    }

    // MARK: - JSON parsing

    func testParsesRecordedTree() throws {
        let tree = try CmuxTree.decode(Self.fixture("tree-all.json"))
        XCTAssertEqual(tree.windows.count, 1)
        XCTAssertEqual(tree.windows[0].workspaces.map(\.title), ["Atlas", "Borealis", "Shared", "scratch"])
        XCTAssertEqual(tree.windows[0].workspaces[0].panes[0].surfaces.map(\.id), [Self.atlasAgent, Self.atlasShell])
    }

    func testParsesInputStatesAndMapsLifecycle() throws {
        let states = try Self.inputStates()
        XCTAssertEqual(states[Self.atlasAgent]?.status, .working)
        XCTAssertEqual(states[Self.atlasAgent]?.inputState, .empty)
        XCTAssertEqual(states[Self.borealisAgent]?.inputState, .draft)
        XCTAssertEqual(states[Self.cirrusAgent]?.status, .needsInput)
        XCTAssertEqual(states[Self.cirrusAgent]?.inputState, .dialog)
        XCTAssertEqual(states[Self.atlasShell]?.isAgent, false)
    }

    func testListsOnlyAgentsAndNamesThemForSpeech() throws {
        let agents = CmuxConnector.agents(from: try CmuxTree.decode(Self.fixture("tree-all.json")), inputStates: try Self.inputStates())
        XCTAssertEqual(agents.map(\.name), ["Atlas", "Borealis", "Cirrus", "Dorado"], "Shells are not listed")
        XCTAssertEqual(agents[0].id, Self.atlasAgent)
        XCTAssertEqual(agents[0].workspaceID, Self.atlasWorkspace)
        XCTAssertEqual(agents[0].target, "agent:cmux/\(Self.atlasAgent)")
        XCTAssertEqual(agents[2].aliases, ["Shared"], "Agents sharing a workspace answer to its title as an alias")

        let parser = AgentIntentParser(agents: agents)
        XCTAssertEqual(parser.parse("Atlas, run the tests").address, .agent(id: Self.atlasAgent))
        guard case .ambiguous(_, let candidates)? = parser.parse("Shared, status").address else {
            return XCTFail("A shared workspace title must ask which agent")
        }
        XCTAssertEqual(Set(candidates), [Self.cirrusAgent, Self.doradoAgent])
    }

    func testDeliveryGuardRefusesDraftsDialogsAndShells() throws {
        let states = try Self.inputStates()
        XCTAssertNil(CmuxConnector.deliveryRefusal(for: states[Self.atlasAgent]!))
        XCTAssertEqual(CmuxConnector.deliveryRefusal(for: states[Self.borealisAgent]!), .draftOpen)
        XCTAssertEqual(CmuxConnector.deliveryRefusal(for: states[Self.cirrusAgent]!), .dialogOpen)
        XCTAssertEqual(CmuxConnector.deliveryRefusal(for: states[Self.atlasShell]!), .notAnAgent)
    }

    func testRecordedErrorsMapToActionableConnectorErrors() throws {
        let samples = try JSONDecoder().decode([String: ErrorSample].self, from: Self.fixture("cli-errors.json"))
        XCTAssertFalse(samples.isEmpty)
        for (name, sample) in samples {
            let kind = CmuxErrorClassifier.classify(exitCode: sample.exitCode, standardError: sample.stderr)
            switch (sample.expect, kind) {
            case ("access_denied", .accessDenied), ("not_running", .notRunning), ("not_found", .notFound), ("failed", .failed):
                break
            default:
                XCTFail("\(name) mapped to \(kind), expected \(sample.expect)")
            }
        }
        guard case .accessDenied(let guidance) = CmuxErrorClassifier.classify(exitCode: 1, standardError: samples["access_denied_cmux_only"]!.stderr) else {
            return XCTFail("Expected access denied")
        }
        XCTAssertTrue(guidance.contains("Settings → Automation"))
        XCTAssertTrue(guidance.contains("Password mode"))
    }

    // MARK: - Connector behavior through a fake CLI

    func testListQueriesTreeThenInputStatePerTerminalSurface() async throws {
        let runner = try FakeCmux()
        let agents = try await CmuxConnector(executable: FakeCmux.executable, runner: runner).list()
        XCTAssertEqual(agents.map(\.name), ["Atlas", "Borealis", "Cirrus", "Dorado"])
        XCTAssertEqual(agents.map(\.status), [.working, .idle, .needsInput, .idle])
        let calls = runner.calls
        XCTAssertEqual(calls.first?.arguments, CmuxArguments.tree())
        XCTAssertEqual(calls.filter { $0.arguments.first == "rpc" }.count, 6)
        XCTAssertTrue(calls.allSatisfy { $0.executable == FakeCmux.executable })
    }

    func testPromptDeliversThroughAgentMessageWithTextOnStdin() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let atlas = try await connector.list()[0]
        let result = try await connector.prompt(atlas, text: "Run the tests; rm -rf / && echo $(whoami)")

        XCTAssertEqual(result, .delivered)
        let message = try XCTUnwrap(runner.calls.last)
        XCTAssertEqual(message.arguments, ["agent", "message", Self.atlasAgent, "--from", "Talkies", "-"])
        XCTAssertEqual(message.standardInput, Data("Run the tests; rm -rf / && echo $(whoami)".utf8))
        XCTAssertFalse(message.arguments.joined(separator: " ").contains("rm -rf"), "Prompt text never reaches argv")
    }

    func testPromptToAgentWithDraftIsRefusedAndNothingIsSent() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let borealis = try await connector.list()[1]
        let result = try await connector.prompt(borealis, text: "Update the changelog")

        XCTAssertEqual(result, .refused(.draftOpen))
        XCTAssertFalse(runner.calls.contains { $0.arguments.starts(with: ["agent", "message"]) })
    }

    func testPromptToAgentShowingDialogIsRefused() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let cirrus = try await connector.list()[2]
        let result = try await connector.prompt(cirrus, text: "yes")
        XCTAssertEqual(result, .refused(.dialogOpen))
        XCTAssertFalse(runner.calls.contains { $0.arguments.starts(with: ["agent", "message"]) })
    }

    func testPromptToBareShellIsRefused() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let shell = AgentRef(connector: "cmux", id: Self.atlasShell, name: "~/src/atlas", workspace: "Atlas", workspaceID: Self.atlasWorkspace)
        let result = try await connector.prompt(shell, text: "ls")
        XCTAssertEqual(result, .refused(.notAnAgent))
        XCTAssertFalse(runner.calls.contains { $0.arguments.starts(with: ["agent", "message"]) })
    }

    func testRejectedDeliveryReportsCmuxReason() async throws {
        let runner = try FakeCmux(messageFailure: "Error: no_hooks: This agent does not accept messages\n")
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let atlas = try await connector.list()[0]
        let result = try await connector.prompt(atlas, text: "hi")
        XCTAssertEqual(result, .refused(.rejected("no_hooks: This agent does not accept messages")))
    }

    func testSocketPasswordIsPassedOnlyThroughTheEnvironment() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner, socketPassword: { "s3cret-pass" })
        _ = try await connector.list()
        XCTAssertFalse(runner.calls.isEmpty)
        for call in runner.calls {
            XCTAssertEqual(call.environment["CMUX_SOCKET_PASSWORD"], "s3cret-pass")
            XCTAssertFalse(call.arguments.contains { $0.contains("s3cret-pass") || $0 == "--password" })
        }
    }

    func testNoPasswordMeansNoPasswordVariable() async throws {
        let runner = try FakeCmux()
        _ = try await CmuxConnector(executable: FakeCmux.executable, runner: runner).list()
        XCTAssertTrue(runner.calls.allSatisfy { $0.environment["CMUX_SOCKET_PASSWORD"] == nil })
    }

    func testAccessDeniedSurfacesSetupGuidanceOnce() async throws {
        let runner = try FakeCmux(globalFailure: "Error: ERROR: Access denied - only processes started inside cmux can connect\n")
        do {
            _ = try await CmuxConnector(executable: FakeCmux.executable, runner: runner).list()
            XCTFail("Expected access denied")
        } catch AgentConnectorError.accessDenied(let tool, let guidance) {
            XCTAssertEqual(tool, "cmux")
            XCTAssertEqual(guidance, CmuxErrorClassifier.accessDeniedGuidance)
        }
        XCTAssertEqual(runner.calls.count, 1, "Never retry in a loop after a refusal")
    }

    func testMissingExecutableReportsNotInstalled() async {
        do {
            _ = try await CmuxConnector(executable: nil, runner: try FakeCmux()).list()
            XCTFail("Expected not installed")
        } catch {
            XCTAssertEqual(error as? AgentConnectorError, .toolNotInstalled(tool: "cmux"))
        }
    }

    func testStatusReportsDraftAndLifecycle() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let agents = try await connector.list()
        let report = try await connector.status(of: agents[1])
        XCTAssertEqual(report.status, .idle)
        XCTAssertEqual(report.inputState, .draft)
        XCTAssertEqual(AgentStatusSentence.make(report, number: 2), "Agent 2, Borealis: idle. No questions waiting. A draft is open.")
    }

    func testReadLastPrefersNewestNotificationThenScreen() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let agents = try await connector.list()
        let atlasLast = try await connector.readLast(agents[0], lines: 30)
        XCTAssertEqual(atlasLast, "Fixed the flaky snapshot test and pushed the branch. All 212 tests pass.")

        let doradoLast = try await connector.readLast(agents[3], lines: 30)
        XCTAssertEqual(doradoLast, "screen text")
        XCTAssertEqual(runner.calls.last?.arguments.first, "read-screen")
    }

    func testShowSelectsWorkspaceThenFocusesSurface() async throws {
        let runner = try FakeCmux()
        let connector = CmuxConnector(executable: FakeCmux.executable, runner: runner)
        let atlas = try await connector.list()[0]
        try await connector.show(atlas)
        XCTAssertEqual(runner.calls.suffix(2).map(\.arguments), [
            ["select-workspace", "--workspace", Self.atlasWorkspace],
            ["focus-panel", "--panel", Self.atlasAgent, "--workspace", Self.atlasWorkspace],
        ])
    }

    func testCapabilitiesDoNotClaimApprovalOrInterrupt() async {
        let connector = CmuxConnector(executable: nil)
        XCTAssertFalse(connector.capabilities.contains(.approve))
        XCTAssertFalse(connector.capabilities.contains(.interrupt))
        do {
            try await connector.respond(AgentRef(connector: "cmux", id: Self.atlasAgent, name: "Atlas"), requestRef: "r", decision: .allowOnce)
            XCTFail("Expected unsupported")
        } catch {
            XCTAssertEqual(error as? AgentConnectorError, .unsupported(action: "answer permission requests", tool: "cmux"))
        }
    }

    // MARK: - Fixtures

    static var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "tests/fixtures/agents/cmux")
    }

    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: fixtureDirectory.appending(path: name))
    }

    static func inputStates() throws -> [String: CmuxInputState] {
        let raw = try JSONSerialization.jsonObject(with: fixture("input-states.json")) as? [String: Any] ?? [:]
        return try raw.mapValues { try CmuxInputState.decode(JSONSerialization.data(withJSONObject: $0)) }
    }
}

private struct ErrorSample: Decodable {
    let exitCode: Int32
    let stderr: String
    let expect: String

    enum CodingKeys: String, CodingKey {
        case exitCode = "exit_code"
        case stderr, expect
    }
}

/// Answers cmux CLI calls from the recorded fixtures and records every invocation.
final class FakeCmux: CommandRunner, @unchecked Sendable {
    static let executable = URL(fileURLWithPath: "/Applications/cmux.app/Contents/Resources/bin/cmux")

    private let lock = NSLock()
    private var recorded: [CommandInvocation] = []
    private let tree: Data
    private let notifications: Data
    private let states: [String: Data]
    private let globalFailure: String?
    private let messageFailure: String?
    private var currentRPCs = 0
    private var peakRPCs = 0

    /// Most `rpc` calls that were in flight at the same time.
    var peakConcurrentRPCs: Int { lock.withLock { peakRPCs } }

    init(globalFailure: String? = nil, messageFailure: String? = nil) throws {
        tree = try CmuxConnectorTests.fixture("tree-all.json")
        notifications = try CmuxConnectorTests.fixture("list-notifications.json")
        let raw = try JSONSerialization.jsonObject(with: CmuxConnectorTests.fixture("input-states.json")) as? [String: Any] ?? [:]
        states = try raw.mapValues { try JSONSerialization.data(withJSONObject: $0) }
        self.globalFailure = globalFailure
        self.messageFailure = messageFailure
    }

    var calls: [CommandInvocation] {
        lock.withLock { recorded }
    }

    func run(_ invocation: CommandInvocation) async throws -> CommandOutput {
        lock.withLock { recorded.append(invocation) }

        if let globalFailure {
            return CommandOutput(exitCode: 1, standardOutput: Data(), standardError: Data(globalFailure.utf8))
        }
        let arguments = invocation.arguments
        switch arguments.first {
        case "--json" where arguments.contains("tree"):
            return CommandOutput(exitCode: 0, standardOutput: tree)
        case "--json" where arguments.contains("list-notifications"):
            return CommandOutput(exitCode: 0, standardOutput: notifications)
        case "rpc":
            lock.withLock {
                currentRPCs += 1
                peakRPCs = max(peakRPCs, currentRPCs)
            }
            try await Task.sleep(for: .milliseconds(30))
            lock.withLock { currentRPCs -= 1 }
            let params = try JSONSerialization.jsonObject(with: Data(arguments[2].utf8)) as? [String: String]
            if let id = params?["surface_id"], let state = states[id] {
                return CommandOutput(exitCode: 0, standardOutput: state)
            }
            return CommandOutput(exitCode: 1, standardOutput: Data(), standardError: Data("Error: not_found: Surface not found\n".utf8))
        case "read-screen":
            return CommandOutput(exitCode: 0, standardOutput: Data("screen text\n".utf8))
        case "agent":
            if let messageFailure {
                return CommandOutput(exitCode: 1, standardOutput: Data(), standardError: Data(messageFailure.utf8))
            }
            return CommandOutput(exitCode: 0, standardOutput: Data("OK\n".utf8))
        case "select-workspace", "focus-panel", "ping":
            return CommandOutput(exitCode: 0, standardOutput: Data("OK\n".utf8))
        default:
            return CommandOutput(exitCode: 1, standardOutput: Data(), standardError: Data("Error: unknown command\n".utf8))
        }
    }
}
