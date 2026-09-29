import Foundation

enum LocalInference {
    #if arch(arm64)
    static let speechModel = LocalModelStore.Model.whisperBase
    private static let whisperEngineName = "whisper-cli-arm64"
    private static let llamaEngineName = "llama-completion-arm64"
    private static let llamaGPUArguments = ["-ngl", "99"]
    #else
    static let speechModel = LocalModelStore.Model.whisperTiny
    private static let whisperEngineName = "whisper-cli-x86_64"
    private static let llamaEngineName = "llama-completion-x86_64"
    private static let llamaGPUArguments: [String] = []
    #endif

    static func transcribe(audioURL: URL, modelURL: URL) throws -> String {
        let outputBase = FileManager.default.temporaryDirectory
            .appendingPathComponent("talkies-transcript-\(UUID().uuidString)")
        let outputURL = outputBase.appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        _ = try run(
            executable: whisperEngineName,
            arguments: [
                "-m", modelURL.path,
                "-f", audioURL.path,
                "-nt", "-np", "-l", "auto", "-t", String(max(2, min(8, ProcessInfo.processInfo.processorCount))),
                "-otxt", "-of", outputBase.path
            ]
        )
        let transcript = try String(contentsOf: outputURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { throw InferenceError.emptyTranscript }
        return transcript
    }

    static func clean(_ transcript: String, modelURL: URL, options: TranscriptCleanupOptions) throws -> String {
        let arguments = [
            "-m", modelURL.path,
            "-p", S1MiniPrompt.render(transcript: transcript, options: options),
            "-n", "256", "--temp", "0", "--no-display-prompt", "--no-conversation",
            "--simple-io", "--no-warmup", "-no-cnv"
        ]
        let output: String
        do {
            output = try run(executable: llamaEngineName, arguments: arguments + llamaGPUArguments)
        } catch where !llamaGPUArguments.isEmpty {
            output = try run(executable: llamaEngineName, arguments: arguments)
        }
        return S1MiniPrompt.resolve(original: transcript, output: output)
    }

    private static func run(executable name: String, arguments: [String]) throws -> String {
        let executableURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Helpers", isDirectory: true)
            .appendingPathComponent(name)
        guard
              FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw InferenceError.engineMissing(name)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorURL = FileManager.default.temporaryDirectory.appendingPathComponent("talkies-engine-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? errorHandle.close()
            try? FileManager.default.removeItem(at: errorURL)
        }
        process.standardOutput = outputPipe
        process.standardError = errorHandle

        do {
            try process.run()
        } catch {
            throw InferenceError.couldNotLaunch(name, error.localizedDescription)
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            try? errorHandle.synchronize()
            let log = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? ""
            throw InferenceError.engineFailed(name, log.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

private enum InferenceError: LocalizedError {
    case engineMissing(String)
    case couldNotLaunch(String, String)
    case engineFailed(String, String)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .engineMissing(let name): return "Talkies is missing its local \(name) engine. Reinstall the Monterey test build."
        case .couldNotLaunch(let name, let reason): return "Could not start the local \(name) engine: \(reason)"
        case .engineFailed(let name, let detail):
            let suffix = detail.isEmpty ? "" : " Details: \(detail.suffix(500))"
            return "The local \(name) engine could not finish.\(suffix)"
        case .emptyTranscript: return "No speech was recognized. Try a longer recording or check your microphone."
        }
    }
}
