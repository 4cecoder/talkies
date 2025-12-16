import Foundation

// MARK: - App Settings Model
/// Main settings model for Talkies - persisted to ~/.talkies/config.json
struct AppSettings: Codable {
    // MARK: - General Settings
    var pushToTalkThreshold: Double = 0.15
    var launchAtLogin: Bool = false
    var voiceAssistantMode: Bool = false
    var insertTextInAssistantMode: Bool = false
    var debugMode: Bool = false

    // MARK: - Plugin Settings
    var ollama: OllamaSettings = OllamaSettings()
    var lmStudio: LMStudioSettings = LMStudioSettings()
    var sentiment: SentimentSettings = SentimentSettings()
    var mlxTTS: MLXTTSSettings = MLXTTSSettings()
    var mlxImageGen: MLXImageGenSettings = MLXImageGenSettings()

    enum CodingKeys: String, CodingKey {
        case pushToTalkThreshold
        case launchAtLogin
        case voiceAssistantMode
        case insertTextInAssistantMode
        case debugMode
        case ollama
        case lmStudio
        case sentiment
        case mlxTTS = "mlx_tts"
        case mlxImageGen = "mlx_image_gen"
    }
}

// MARK: - Ollama Settings
struct OllamaSettings: Codable {
    var isEnabled: Bool = false
    var selectedModel: String = "llama3.2:3b"
    var host: String = "http://localhost:11434"
    var enhancementMode: String = "grammar"

    // Advanced LLM Parameters
    var temperature: Double = 0.3
    var topP: Double = 0.9
    var topK: Int = 40
    var repeatPenalty: Double = 1.1
    var contextLength: Int = 2048
    var maxTokens: Int = 500
    var customSystemPrompt: String = ""
    var useCustomPrompt: Bool = false
    var stopSequences: String = ""

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case selectedModel
        case host
        case enhancementMode
        case temperature
        case topP
        case topK
        case repeatPenalty
        case contextLength
        case maxTokens
        case customSystemPrompt
        case useCustomPrompt
        case stopSequences
    }
}

// MARK: - LM Studio Settings
struct LMStudioSettings: Codable {
    var isEnabled: Bool = false
    var selectedModel: String = ""
    var endpoint: String = "http://127.0.0.1:1234"
    var enhancementMode: String = "grammar"

    // Advanced LLM Parameters
    var temperature: Double = 0.3
    var topP: Double = 0.9
    var maxTokens: Int = 4096

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case selectedModel
        case endpoint
        case enhancementMode
        case temperature
        case topP
        case maxTokens
    }
}

// MARK: - Sentiment Settings
struct SentimentSettings: Codable {
    var isEnabled: Bool = false

    enum CodingKeys: String, CodingKey {
        case isEnabled
    }
}

// MARK: - MLX TTS Settings
struct MLXTTSSettings: Codable {
    var isEnabled: Bool = false
    var selectedEngine: String = "native"
    var selectedVoice: String = ""

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case selectedEngine
        case selectedVoice
    }
}

// MARK: - MLX Image Generation Settings
struct MLXImageGenSettings: Codable {
    var isEnabled: Bool = false
    var selectedModel: String = ""

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case selectedModel
    }
}
