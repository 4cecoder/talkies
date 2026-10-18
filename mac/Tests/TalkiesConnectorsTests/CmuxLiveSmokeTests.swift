import Foundation
import XCTest
import TalkiesCore
@testable import TalkiesConnectors

/// Read-only smoke test against a real, running cmux. It lists agents and reads their status;
/// it never sends a message, focuses, or types anything.
///
/// ```sh
/// cd mac && TALKIES_CMUX_SMOKE=1 swift test --filter CmuxLiveSmokeTests
/// ```
///
/// Run it from a cmux terminal, or after allowing external clients in cmux Settings → Automation
/// (set `CMUX_SOCKET_PASSWORD` for Password mode).
final class CmuxLiveSmokeTests: XCTestCase {
    func testListsAgentsAndReadsStatusFromRunningCmux() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TALKIES_CMUX_SMOKE"] == "1", "Set TALKIES_CMUX_SMOKE=1 to run against a live cmux")
        let executable = try XCTUnwrap(CmuxExecutableLocator.locate(), "cmux CLI not found")
        let connector = CmuxConnector(
            executable: executable,
            socketPassword: { ProcessInfo.processInfo.environment["CMUX_SOCKET_PASSWORD"] }
        )

        try await connector.ping()
        let agents = try await connector.list()
        print("cmux smoke: \(agents.count) agent(s) via \(executable.path)")
        for (index, agent) in agents.enumerated() {
            XCTAssertNotNil(UUID(uuidString: agent.id), "Agent ids are UUIDs")
            let report = try await connector.status(of: agent)
            print("cmux smoke: \(AgentStatusSentence.make(report, number: index + 1))")
        }
        print("cmux smoke: \(AgentStatusSentence.list(agents))")
    }
}
