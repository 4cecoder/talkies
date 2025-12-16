import Foundation
import Combine

// MARK: - Settings Service
/// Manages application settings with JSON persistence to ~/.talkies/config.json
/// Similar to Windows SettingsService.cs for cross-platform consistency
@MainActor
class SettingsService: ObservableObject {
    // MARK: - Singleton
    static let shared = SettingsService()

    // MARK: - Published Settings
    @Published var settings: AppSettings {
        didSet {
            autoSave()
        }
    }

    // MARK: - File Path
    private let configPath: URL
    private var saveTimer: Timer?
    private let autoSaveDelay: TimeInterval = 0.5 // Auto-save 500ms after last change

    // MARK: - Initialization
    private init() {
        // Check for environment variable override (for testing)
        if let overridePath = ProcessInfo.processInfo.environment["TALKIES_CONFIG_PATH"] {
            let url = URL(fileURLWithPath: overridePath)
            // Create parent directory if needed
            let parentDir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            configPath = url
        } else {
            // Default: ~/.talkies/config.json
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let talkiesDir = homeDir.appendingPathComponent(".talkies")

            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: talkiesDir, withIntermediateDirectories: true)

            configPath = talkiesDir.appendingPathComponent("config.json")
        }

        // Load existing settings or create defaults
        self.settings = Self.loadSettings(from: configPath)

        print("✅ SettingsService initialized")
        print("   Config path: \(configPath.path)")
    }

    // MARK: - Load Settings
    private static func loadSettings(from path: URL) -> AppSettings {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: path.path) else {
                print("ℹ️ Config file not found, using defaults")
                return AppSettings()
            }

            // Read and decode JSON
            let data = try Data(contentsOf: path)
            let decoder = JSONDecoder()
            let settings = try decoder.decode(AppSettings.self, from: data)

            print("✅ Settings loaded from: \(path.path)")
            return settings
        } catch {
            print("⚠️ Failed to load settings: \(error.localizedDescription)")
            print("   Using default settings")
            return AppSettings()
        }
    }

    // MARK: - Save Settings
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)

            try data.write(to: configPath, options: [.atomic])

            if settings.debugMode {
                print("✅ Settings saved to: \(configPath.path)")
            }
        } catch {
            print("⚠️ Failed to save settings: \(error.localizedDescription)")
        }
    }

    // MARK: - Auto-Save
    private func autoSave() {
        // Invalidate existing timer
        saveTimer?.invalidate()

        // Schedule new save
        saveTimer = Timer.scheduledTimer(withTimeInterval: autoSaveDelay, repeats: false) { [weak self] _ in
            self?.save()
        }
    }

    // MARK: - Reset to Defaults
    func resetToDefaults() {
        settings = AppSettings()
        save()
        print("✅ Settings reset to defaults")
    }

    // MARK: - Delete Config File
    func deleteConfigFile() throws {
        try FileManager.default.removeItem(at: configPath)
        print("✅ Config file deleted: \(configPath.path)")
    }

    // MARK: - Migrate from UserDefaults (one-time migration)
    func migrateFromUserDefaults() {
        let defaults = UserDefaults.standard

        // Only migrate if we have old settings and no JSON file
        guard !FileManager.default.fileExists(atPath: configPath.path) else {
            print("ℹ️ Skipping migration - config.json already exists")
            return
        }

        print("🔄 Migrating settings from UserDefaults to JSON...")

        // Migrate general settings
        if defaults.object(forKey: "pushToTalkThreshold") != nil {
            settings.pushToTalkThreshold = defaults.double(forKey: "pushToTalkThreshold")
        }
        if defaults.object(forKey: "launchAtLogin") != nil {
            settings.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        }
        if defaults.object(forKey: "voiceAssistantMode") != nil {
            settings.voiceAssistantMode = defaults.bool(forKey: "voiceAssistantMode")
        }
        if defaults.object(forKey: "insertTextInAssistantMode") != nil {
            settings.insertTextInAssistantMode = defaults.bool(forKey: "insertTextInAssistantMode")
        }
        if defaults.object(forKey: "debugMode") != nil {
            settings.debugMode = defaults.bool(forKey: "debugMode")
        }

        // Migrate Ollama settings
        if defaults.object(forKey: "ollama.isEnabled") != nil {
            settings.ollama.isEnabled = defaults.bool(forKey: "ollama.isEnabled")
        }
        if let model = defaults.string(forKey: "ollama.selectedModel") {
            settings.ollama.selectedModel = model
        }
        if let host = defaults.string(forKey: "ollama.host") {
            settings.ollama.host = host
        }
        if let mode = defaults.string(forKey: "ollama.enhancementMode") {
            settings.ollama.enhancementMode = mode
        }
        if defaults.object(forKey: "ollama.temperature") != nil {
            settings.ollama.temperature = defaults.double(forKey: "ollama.temperature")
        }
        if defaults.object(forKey: "ollama.topP") != nil {
            settings.ollama.topP = defaults.double(forKey: "ollama.topP")
        }
        if defaults.object(forKey: "ollama.topK") != nil {
            settings.ollama.topK = defaults.integer(forKey: "ollama.topK")
        }
        if defaults.object(forKey: "ollama.repeatPenalty") != nil {
            settings.ollama.repeatPenalty = defaults.double(forKey: "ollama.repeatPenalty")
        }
        if defaults.object(forKey: "ollama.contextLength") != nil {
            settings.ollama.contextLength = defaults.integer(forKey: "ollama.contextLength")
        }
        if defaults.object(forKey: "ollama.maxTokens") != nil {
            settings.ollama.maxTokens = defaults.integer(forKey: "ollama.maxTokens")
        }
        if let prompt = defaults.string(forKey: "ollama.customSystemPrompt") {
            settings.ollama.customSystemPrompt = prompt
        }
        if defaults.object(forKey: "ollama.useCustomPrompt") != nil {
            settings.ollama.useCustomPrompt = defaults.bool(forKey: "ollama.useCustomPrompt")
        }
        if let sequences = defaults.string(forKey: "ollama.stopSequences") {
            settings.ollama.stopSequences = sequences
        }

        // Migrate LM Studio settings
        if defaults.object(forKey: "lmstudio.isEnabled") != nil {
            settings.lmStudio.isEnabled = defaults.bool(forKey: "lmstudio.isEnabled")
        }
        if let model = defaults.string(forKey: "lmstudio.selectedModel") {
            settings.lmStudio.selectedModel = model
        }
        if let endpoint = defaults.string(forKey: "lmstudio.endpoint") {
            settings.lmStudio.endpoint = endpoint
        }
        if let mode = defaults.string(forKey: "lmstudio.enhancementMode") {
            settings.lmStudio.enhancementMode = mode
        }
        if defaults.object(forKey: "lmstudio.temperature") != nil {
            settings.lmStudio.temperature = defaults.double(forKey: "lmstudio.temperature")
        }
        if defaults.object(forKey: "lmstudio.topP") != nil {
            settings.lmStudio.topP = defaults.double(forKey: "lmstudio.topP")
        }
        if defaults.object(forKey: "lmstudio.maxTokens") != nil {
            settings.lmStudio.maxTokens = defaults.integer(forKey: "lmstudio.maxTokens")
        }

        // Migrate Sentiment settings
        if defaults.object(forKey: "sentiment.isEnabled") != nil {
            settings.sentiment.isEnabled = defaults.bool(forKey: "sentiment.isEnabled")
        }

        // Migrate MLX TTS settings
        if defaults.object(forKey: "mlx-tts.isEnabled") != nil {
            settings.mlxTTS.isEnabled = defaults.bool(forKey: "mlx-tts.isEnabled")
        }
        if let engine = defaults.string(forKey: "mlx-tts.selectedEngine") {
            settings.mlxTTS.selectedEngine = engine
        }
        if let voice = defaults.string(forKey: "mlx-tts.selectedVoice") {
            settings.mlxTTS.selectedVoice = voice
        }

        // Migrate MLX Image Gen settings
        if defaults.object(forKey: "mlx-image-gen.isEnabled") != nil {
            settings.mlxImageGen.isEnabled = defaults.bool(forKey: "mlx-image-gen.isEnabled")
        }
        if let model = defaults.string(forKey: "mlx-image-gen.selectedModel") {
            settings.mlxImageGen.selectedModel = model
        }

        // Save migrated settings
        save()
        print("✅ Migration complete - settings saved to \(configPath.path)")
    }

    // MARK: - Config Path Accessor
    var configFilePath: String {
        configPath.path
    }
}
