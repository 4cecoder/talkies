import Foundation
import XCTest
@testable import TalkiesConnectors

/// Exercises the real `Process` runner with system tools; no cmux needed.
final class ProcessCommandRunnerTests: XCTestCase {
    private let runner = ProcessCommandRunner()

    func testStandardInputReachesTheChild() async throws {
        let text = "Run the tests; rm -rf / && echo $(whoami)"
        let output = try await runner.run(CommandInvocation(
            executable: URL(fileURLWithPath: "/bin/cat"),
            arguments: [],
            standardInput: Data(text.utf8)
        ))
        XCTAssertEqual(output.exitCode, 0)
        XCTAssertEqual(output.standardOutputText, text)
    }

    func testLargeInputAndOutputDoNotDeadlock() async throws {
        let big = Data(repeating: UInt8(ascii: "a"), count: 2 * 1024 * 1024)
        let output = try await runner.run(CommandInvocation(executable: URL(fileURLWithPath: "/bin/cat"), arguments: [], standardInput: big))
        XCTAssertEqual(output.standardOutput.count, big.count)
    }

    func testChildThatExitsWithoutReadingStdinDoesNotRaiseSIGPIPE() async throws {
        // Without F_SETNOSIGPIPE this write kills the test process with SIGPIPE.
        let big = Data(repeating: UInt8(ascii: "x"), count: 4 * 1024 * 1024)
        for _ in 0..<5 {
            do {
                let output = try await runner.run(CommandInvocation(executable: URL(fileURLWithPath: "/usr/bin/false"), arguments: [], standardInput: big))
                XCTAssertEqual(output.exitCode, 1, "A failing child reports its own exit status")
            } catch CommandRunnerError.standardInputFailed {
                XCTFail("A non-zero exit should be reported as the exit status")
            }
            do {
                _ = try await runner.run(CommandInvocation(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [], standardInput: big))
            } catch CommandRunnerError.standardInputFailed {
                // Expected: EPIPE surfaces as an ordinary error.
            }
        }
    }

    func testEnvironmentOverridesAreVisibleOnlyToTheChild() async throws {
        let output = try await runner.run(CommandInvocation(
            executable: URL(fileURLWithPath: "/usr/bin/printenv"),
            arguments: ["CMUX_SOCKET_PASSWORD"],
            environment: ["CMUX_SOCKET_PASSWORD": "s3cret-pass"]
        ))
        XCTAssertEqual(output.standardOutputText.trimmingCharacters(in: .whitespacesAndNewlines), "s3cret-pass")
        XCTAssertNotEqual(ProcessInfo.processInfo.environment["CMUX_SOCKET_PASSWORD"], "s3cret-pass")
    }

    func testTimeoutTerminatesTheChild() async throws {
        let start = Date()
        do {
            _ = try await runner.run(CommandInvocation(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["30"], timeout: 0.3))
            XCTFail("Expected a timeout")
        } catch {
            XCTAssertEqual(error as? CommandRunnerError, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testTimeoutEscalatesToSIGKILLWhenTermIsIgnored() async throws {
        let start = Date()
        do {
            _ = try await runner.run(CommandInvocation(
                executable: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "trap '' TERM; while :; do sleep 1; done"],
                timeout: 0.3
            ))
            XCTFail("Expected a timeout")
        } catch {
            XCTAssertEqual(error as? CommandRunnerError, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2 * ProcessCommandRunner.terminationGrace + 3)
    }

    func testNonZeroExitAndStderrAreReported() async throws {
        let output = try await runner.run(CommandInvocation(executable: URL(fileURLWithPath: "/bin/ls"), arguments: ["/definitely/missing/path"]))
        XCTAssertNotEqual(output.exitCode, 0)
        XCTAssertFalse(output.standardErrorText.isEmpty)
    }

    func testMissingExecutable() async {
        do {
            _ = try await runner.run(CommandInvocation(executable: URL(fileURLWithPath: "/no/such/cmux"), arguments: []))
            XCTFail("Expected missing executable")
        } catch {
            XCTAssertEqual(error as? CommandRunnerError, .executableMissing("/no/such/cmux"))
        }
    }
}
