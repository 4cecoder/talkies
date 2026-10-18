import Foundation
import XCTest
@testable import TalkiesCore

/// Runs the shared utterance-to-intent fixtures in `tests/fixtures/intents/`.
/// Every platform's agent-mode parser is expected to pass the same files.
final class AgentIntentFixtureTests: XCTestCase {
    func testSharedIntentFixturesPass() throws {
        let files = try FileManager.default
            .contentsOfDirectory(at: Self.fixtureDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertGreaterThanOrEqual(files.count, 5, "Expected the shared intent fixture files")

        var caseCount = 0
        for file in files {
            let fixture = try JSONDecoder().decode(IntentFixture.self, from: Data(contentsOf: file))
            XCTAssertEqual(fixture.grammarVersion, AgentIntentParser.grammarVersion, file.lastPathComponent)
            let parser = AgentIntentParser(candidates: fixture.agents.map { AgentNameCandidate(id: $0.id, names: [$0.name] + $0.aliases) })

            for testCase in fixture.cases {
                caseCount += 1
                let label = "\(file.lastPathComponent): \"\(testCase.utterance)\""
                let mode = CaptureMode(rawValue: testCase.mode ?? "agent") ?? .agent
                let route = CaptureRouter.route(testCase.utterance, mode: mode, parser: parser)

                if let insert = testCase.insert {
                    XCTAssertEqual(route, .insert(insert), label)
                    continue
                }
                guard case .agent(let utterance) = route else {
                    XCTFail("\(label) was not parsed in agent mode")
                    continue
                }
                XCTAssertEqual(Self.describe(utterance.address), testCase.address?.expected ?? "none", "\(label) address")
                switch utterance.intent {
                case .prompt(let text):
                    XCTAssertEqual(testCase.intent, "prompt", "\(label) intent")
                    XCTAssertEqual(text, testCase.text ?? "", "\(label) prompt text")
                case .command(let command, let argument):
                    XCTAssertEqual(command.rawValue, testCase.intent, "\(label) intent")
                    if let text = testCase.text {
                        XCTAssertEqual(argument, text, "\(label) argument")
                    }
                }
            }
        }
        XCTAssertGreaterThan(caseCount, 50)
    }

    /// Fixture ambiguity cases list candidates only; the spoken text is not part of the contract.
    static func describe(_ address: AgentAddress?) -> String {
        switch address {
        case nil: "none"
        case .agent(let id)?: "agent:\(id)"
        case .number(let number)?: "number:\(number)"
        case .ambiguous(_, let candidates)?: "ambiguous:\(candidates.sorted().joined(separator: ","))"
        }
    }

    static var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "tests/fixtures/intents")
    }
}

private struct IntentFixture: Decodable {
    let grammarVersion: Int
    let agents: [Agent]
    let cases: [Case]

    enum CodingKeys: String, CodingKey {
        case grammarVersion = "grammar_version"
        case agents, cases
    }

    struct Agent: Decodable {
        let id: String
        let name: String
        let aliases: [String]
    }

    struct Case: Decodable {
        let utterance: String
        let mode: String?
        let address: Address?
        let intent: String?
        let text: String?
        let insert: String?
    }

    struct Address: Decodable {
        let agent: String?
        let number: Int?
        let ambiguous: [String]?

        var expected: String {
            if let agent { return "agent:\(agent)" }
            if let number { return "number:\(number)" }
            if let ambiguous { return "ambiguous:\(ambiguous.sorted().joined(separator: ","))" }
            return "none"
        }
    }
}
