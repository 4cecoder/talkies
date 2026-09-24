import Foundation
import LlamaSwift
import TalkiesCore

/// Runs S1-mini locally with llama.cpp using its recommended CPU quantization.
public actor S1MiniCleaner: TranscriptCleaner {
    public static let modelID = "superwhisper/s1-mini-GGUF"
    public static let modelRevision = "34add00a48a2e5d24e5a4ee5405a99620a3a240c"

    private let modelStore = S1MiniModelStore()
    fileprivate static let backendInitialization: Void = {
        ggml_backend_register(ggml_backend_cpu_reg())
        llama_backend_init()
    }()
    private var runtime: S1MiniRuntime?

    public init() {}

    public func clean(
        _ transcript: String,
        options: TranscriptCleanupOptions = TranscriptCleanupOptions()
    ) async throws -> String {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else { return "" }

        let modelURL = try await modelStore.ensureModelAvailable()
        let activeRuntime: S1MiniRuntime
        if let runtime {
            activeRuntime = runtime
        } else {
            let loadedRuntime = try S1MiniRuntime(modelURL: modelURL)
            runtime = loadedRuntime
            activeRuntime = loadedRuntime
        }
        return try activeRuntime.clean(
            prompt: S1MiniPrompt.render(transcript: trimmedTranscript, options: options)
        )
    }
}

/// Owns one resident CPU model and context. The actor above serializes access.
private final class S1MiniRuntime: @unchecked Sendable {
    private let model: OpaquePointer
    private let context: OpaquePointer
    private let vocabulary: OpaquePointer

    init(modelURL: URL) throws {
        _ = S1MiniCleaner.backendInitialization
        var modelParameters = llama_model_default_params()
        modelParameters.n_gpu_layers = 0
        guard let cpuDevice = ggml_backend_dev_by_type(GGML_BACKEND_DEVICE_TYPE_CPU) else {
            throw S1MiniInferenceError.contextCreationFailed
        }
        var cpuDevices: [OpaquePointer?] = [cpuDevice, nil]
        let loadedModel = cpuDevices.withUnsafeMutableBufferPointer { deviceBuffer in
            modelParameters.devices = deviceBuffer.baseAddress
            return modelURL.path.withCString({ llama_model_load_from_file($0, modelParameters) })
        }
        guard let loadedModel else {
            throw S1MiniInferenceError.modelLoadFailed
        }

        let contextLength: UInt32 = 3072
        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = contextLength
        contextParameters.n_batch = 2048
        contextParameters.n_ubatch = 512
        contextParameters.n_threads = Int32(max(2, min(ProcessInfo.processInfo.activeProcessorCount - 1, 8)))
        contextParameters.n_threads_batch = contextParameters.n_threads

        guard let loadedContext = llama_init_from_model(loadedModel, contextParameters) else {
            llama_model_free(loadedModel)
            throw S1MiniInferenceError.contextCreationFailed
        }
        model = loadedModel
        context = loadedContext
        vocabulary = llama_model_get_vocab(loadedModel)
    }

    deinit {
        llama_free(context)
        llama_model_free(model)
    }

    func clean(prompt: String) throws -> String {
        guard prompt.utf8.count <= 8_192 else { throw S1MiniInferenceError.promptTooLong }

        llama_memory_clear(llama_get_memory(context), true)

        let tokenCapacity = prompt.utf8.count + 16
        var promptTokens = [llama_token](repeating: 0, count: tokenCapacity)
        let promptTokenCount = prompt.withCString {
            llama_tokenize(
                vocabulary,
                $0,
                Int32(prompt.utf8.count),
                &promptTokens,
                Int32(tokenCapacity),
                false,
                true
            )
        }
        guard promptTokenCount > 0 else { throw S1MiniInferenceError.tokenizationFailed }
        guard promptTokenCount < 2048 else { throw S1MiniInferenceError.promptTooLong }

        var batch = llama_batch_init(Int32(promptTokenCount), 0, 1)
        defer { llama_batch_free(batch) }
        batch.n_tokens = promptTokenCount
        for index in 0..<Int(promptTokenCount) {
            batch.token[index] = promptTokens[index]
            batch.pos[index] = Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]?[0] = 0
            batch.logits[index] = 0
        }
        batch.logits[Int(promptTokenCount) - 1] = 1

        guard llama_decode(context, batch) == 0 else { throw S1MiniInferenceError.promptEvaluationFailed }

        let samplerParameters = llama_sampler_chain_default_params()
        guard let sampler = llama_sampler_chain_init(samplerParameters) else {
            throw S1MiniInferenceError.samplerCreationFailed
        }
        defer { llama_sampler_free(sampler) }
        guard let greedySampler = llama_sampler_init_greedy() else {
            throw S1MiniInferenceError.samplerCreationFailed
        }
        llama_sampler_chain_add(sampler, greedySampler)

        let maximumOutputTokens = min(1024, Int(Double(promptTokenCount) * 1.3) + 32)
        var outputBytes = [UInt8]()
        var currentPosition = promptTokenCount

        for _ in 0..<maximumOutputTokens {
            let token = llama_sampler_sample(sampler, context, batch.n_tokens - 1)
            if llama_vocab_is_eog(vocabulary, token) { break }
            llama_sampler_accept(sampler, token)

            var tokenBytes = [CChar](repeating: 0, count: 32)
            let byteCount = llama_token_to_piece(
                vocabulary,
                token,
                &tokenBytes,
                Int32(tokenBytes.count),
                0,
                false
            )
            if byteCount > 0 {
                outputBytes.append(contentsOf: tokenBytes.prefix(Int(byteCount)).map(UInt8.init(bitPattern:)))
            }

            batch.n_tokens = 1
            batch.token[0] = token
            batch.pos[0] = currentPosition
            batch.n_seq_id[0] = 1
            batch.seq_id[0]?[0] = 0
            batch.logits[0] = 1
            currentPosition += 1

            guard llama_decode(context, batch) == 0 else { throw S1MiniInferenceError.generationFailed }
        }

        return String(decoding: outputBytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum S1MiniInferenceError: LocalizedError {
    case modelLoadFailed
    case contextCreationFailed
    case promptTooLong
    case tokenizationFailed
    case promptEvaluationFailed
    case samplerCreationFailed
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed: "Unable to load the local S1-mini GGUF model."
        case .contextCreationFailed: "Unable to create the S1-mini inference context."
        case .promptTooLong: "The transcript exceeds S1-mini's supported input length."
        case .tokenizationFailed: "Unable to tokenize the S1-mini prompt."
        case .promptEvaluationFailed: "Unable to evaluate the S1-mini prompt."
        case .samplerCreationFailed: "Unable to initialize deterministic S1-mini decoding."
        case .generationFailed: "S1-mini stopped while generating the cleaned transcript."
        }
    }
}
