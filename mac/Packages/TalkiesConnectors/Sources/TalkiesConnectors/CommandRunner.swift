import Foundation

/// One child-process call. There is deliberately no shell: `arguments` is passed to the
/// executable as-is, so recognized speech can never be interpreted as shell syntax.
public struct CommandInvocation: Equatable, Sendable {
    public let executable: URL
    public let arguments: [String]
    /// Variables added to (or replacing) the inherited environment. Secrets go here, never in `arguments`.
    public let environment: [String: String]
    public let standardInput: Data?
    public let timeout: TimeInterval

    public init(executable: URL, arguments: [String], environment: [String: String] = [:], standardInput: Data? = nil, timeout: TimeInterval = 10) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
        self.standardInput = standardInput
        self.timeout = timeout
    }
}

public struct CommandOutput: Equatable, Sendable {
    public let exitCode: Int32
    public let standardOutput: Data
    public let standardError: Data

    public init(exitCode: Int32, standardOutput: Data, standardError: Data = Data()) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var standardOutputText: String { String(decoding: standardOutput, as: UTF8.self) }
    public var standardErrorText: String { String(decoding: standardError, as: UTF8.self) }
}

public enum CommandRunnerError: Error, Equatable, Sendable {
    case executableMissing(String)
    case launchFailed(String)
    case timedOut
}

public protocol CommandRunner: Sendable {
    func run(_ invocation: CommandInvocation) async throws -> CommandOutput
}

/// Runs a command with `Process` and an explicit argument array.
public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ invocation: CommandInvocation) async throws -> CommandOutput {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try Self.runBlocking(invocation))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private final class Buffer: @unchecked Sendable {
        var data = Data()
    }

    private static func runBlocking(_ invocation: CommandInvocation) throws -> CommandOutput {
        guard FileManager.default.isExecutableFile(atPath: invocation.executable.path) else {
            throw CommandRunnerError.executableMissing(invocation.executable.path)
        }

        let process = Process()
        process.executableURL = invocation.executable
        process.arguments = invocation.arguments
        process.environment = ProcessInfo.processInfo.environment.merging(invocation.environment) { _, override in override }

        let output = Pipe(), error = Pipe()
        process.standardOutput = output
        process.standardError = error
        let input = invocation.standardInput.map { _ in Pipe() }
        process.standardInput = input ?? FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw CommandRunnerError.launchFailed(error.localizedDescription)
        }

        // Drain both pipes concurrently so a large reply cannot block the child.
        let group = DispatchGroup()
        let stdout = Buffer(), stderr = Buffer()
        for (pipe, buffer) in [(output, stdout), (error, stderr)] {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                buffer.data = pipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
        }
        if let input, let data = invocation.standardInput {
            let handle = input.fileHandleForWriting
            DispatchQueue.global(qos: .userInitiated).async {
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        }

        if group.wait(timeout: .now() + invocation.timeout) == .timedOut {
            process.terminate()
            _ = group.wait(timeout: .now() + 2)
            throw CommandRunnerError.timedOut
        }
        process.waitUntilExit()
        return CommandOutput(exitCode: process.terminationStatus, standardOutput: stdout.data, standardError: stderr.data)
    }
}
