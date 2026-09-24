import Foundation
import MLXLLM
import MLXLMCommon
import MLX
import TalkiesCore
import Tokenizers

/// Runs the S1-mini text normalizer locally through MLX on Apple silicon.
public actor S1MiniCleaner: TranscriptCleaner {
    public static let modelID = "mlx-community/S1-mini-MLX-4bit"
    public static let modelRevision = "5cbd7aec3401144f88a331d385c40b65fd2548eb"

    private var modelContainer: ModelContainer?
    private let modelStore = S1MiniModelStore()

    public init() {}

    public func clean(
        _ transcript: String,
        options: TranscriptCleanupOptions = TranscriptCleanupOptions()
    ) async throws -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return "" }

        let cpuTask: Task<String, Error> = Device.withDefaultDevice(.cpu) {
            Task {
                let container = try await loadModelIfNeeded()
                let input = UserInput(
                    prompt: .text(S1MiniPrompt.render(transcript: trimmedTranscript, options: options))
                )
                let preparedInput = try await container.prepare(input: input)
                let stream = try await container.generate(
                    input: preparedInput,
                    parameters: GenerateParameters(maxTokens: 1024, temperature: 0)
                )

                var output = ""
                for await event in stream {
                    guard !Task.isCancelled else { throw CancellationError() }
                    if case .chunk(let chunk) = event {
                        output += chunk
                    }
                }
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return try await cpuTask.value
    }

    private func loadModelIfNeeded() async throws -> ModelContainer {
        if let modelContainer { return modelContainer }
        let modelDirectory = try await modelStore.ensureModelAvailable(
            modelID: Self.modelID,
            revision: Self.modelRevision
        )
        let loadedContainer = try await loadModelContainer(
            configuration: ModelConfiguration(directory: modelDirectory)
        )
        modelContainer = loadedContainer
        return loadedContainer
    }
}
