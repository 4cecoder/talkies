import SwiftUI
import Foundation

// MARK: - Ollama Plugin
@MainActor
class OllamaPlugin: TalkiesPlugin, ObservableObject {
    let id = "ollama"
    let name = "Ollama LLM Enhancement"
    let description = "Clean up and enhance transcriptions using local LLMs"
    let icon = "brain"

    @Published var isEnabled = false {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "ollama.isEnabled") }
    }
    @Published var selectedModel = "llama3.2:3b" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "ollama.selectedModel") }
    }
    @Published var ollamaHost = "http://localhost:11434" {
        didSet { UserDefaults.standard.set(ollamaHost, forKey: "ollama.host") }
    }
    @Published var enhancementMode: EnhancementMode = .grammar {
        didSet { UserDefaults.standard.set(enhancementMode.rawValue, forKey: "ollama.enhancementMode") }
    }
    @Published var isProcessing = false
    @Published var lastError: String?

    // Auto-detection
    @Published var ollamaStatus: OllamaStatus = .checking
    @Published var availableModels: [OllamaModel] = []
    @Published var isCheckingStatus = false

    // Advanced LLM Controls
    @Published var temperature: Double = 0.3 {
        didSet { UserDefaults.standard.set(temperature, forKey: "ollama.temperature") }
    }
    @Published var topP: Double = 0.9 {
        didSet { UserDefaults.standard.set(topP, forKey: "ollama.topP") }
    }
    @Published var topK: Int = 40 {
        didSet { UserDefaults.standard.set(topK, forKey: "ollama.topK") }
    }
    @Published var repeatPenalty: Double = 1.1 {
        didSet { UserDefaults.standard.set(repeatPenalty, forKey: "ollama.repeatPenalty") }
    }
    @Published var contextLength: Int = 2048 {
        didSet { UserDefaults.standard.set(contextLength, forKey: "ollama.contextLength") }
    }
    @Published var customSystemPrompt: String = "" {
        didSet { UserDefaults.standard.set(customSystemPrompt, forKey: "ollama.customSystemPrompt") }
    }
    @Published var useCustomPrompt: Bool = false {
        didSet { UserDefaults.standard.set(useCustomPrompt, forKey: "ollama.useCustomPrompt") }
    }
    @Published var maxTokens: Int = 500 {
        didSet { UserDefaults.standard.set(maxTokens, forKey: "ollama.maxTokens") }
    }
    @Published var stopSequences: String = "" {
        didSet { UserDefaults.standard.set(stopSequences, forKey: "ollama.stopSequences") }
    }

    enum OllamaStatus {
        case checking
        case notInstalled
        case notRunning
        case ready

        var description: String {
            switch self {
            case .checking: return "Checking Ollama status..."
            case .notInstalled: return "Ollama not detected"
            case .notRunning: return "Ollama is not running"
            case .ready: return "Ready"
            }
        }

        var color: Color {
            switch self {
            case .checking: return .orange
            case .notInstalled: return .red
            case .notRunning: return .yellow
            case .ready: return .green
            }
        }

        var icon: String {
            switch self {
            case .checking: return "arrow.clockwise"
            case .notInstalled: return "exclamationmark.triangle"
            case .notRunning: return "pause.circle"
            case .ready: return "checkmark.circle.fill"
            }
        }
    }

    init() {
        // Load saved settings
        loadSettings()

        // Auto-check on init
        Task {
            await checkOllamaStatus()
        }
    }

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "ollama.isEnabled")

        if let model = UserDefaults.standard.string(forKey: "ollama.selectedModel") {
            selectedModel = model
        }

        if let host = UserDefaults.standard.string(forKey: "ollama.host") {
            ollamaHost = host
        }

        if let modeRaw = UserDefaults.standard.string(forKey: "ollama.enhancementMode"),
           let mode = EnhancementMode(rawValue: modeRaw) {
            enhancementMode = mode
        }

        // Load advanced settings
        if UserDefaults.standard.object(forKey: "ollama.temperature") != nil {
            temperature = UserDefaults.standard.double(forKey: "ollama.temperature")
        }
        if UserDefaults.standard.object(forKey: "ollama.topP") != nil {
            topP = UserDefaults.standard.double(forKey: "ollama.topP")
        }
        if UserDefaults.standard.object(forKey: "ollama.topK") != nil {
            topK = UserDefaults.standard.integer(forKey: "ollama.topK")
        }
        if UserDefaults.standard.object(forKey: "ollama.repeatPenalty") != nil {
            repeatPenalty = UserDefaults.standard.double(forKey: "ollama.repeatPenalty")
        }
        if UserDefaults.standard.object(forKey: "ollama.contextLength") != nil {
            contextLength = UserDefaults.standard.integer(forKey: "ollama.contextLength")
        }
        if UserDefaults.standard.object(forKey: "ollama.maxTokens") != nil {
            maxTokens = UserDefaults.standard.integer(forKey: "ollama.maxTokens")
        }
        if let prompt = UserDefaults.standard.string(forKey: "ollama.customSystemPrompt") {
            customSystemPrompt = prompt
        }
        if UserDefaults.standard.object(forKey: "ollama.useCustomPrompt") != nil {
            useCustomPrompt = UserDefaults.standard.bool(forKey: "ollama.useCustomPrompt")
        }
        if let sequences = UserDefaults.standard.string(forKey: "ollama.stopSequences") {
            stopSequences = sequences
        }
    }

    enum EnhancementMode: String, CaseIterable, Identifiable {
        case grammar = "Grammar & Clarity"
        case technical = "Technical Writing"
        case concise = "Concise & Professional"
        case creative = "Creative Enhancement"
        case companion = "AI Companion"

        var id: String { rawValue }

        var systemPrompt: String {
            switch self {
            case .grammar:
                return """
                You are a grammar and clarity assistant. Fix grammar errors, improve clarity, and correct spelling while preserving the user's intent and tone. Keep the meaning exactly the same. Return ONLY the corrected text, nothing else.
                """
            case .technical:
                return """
                You are a technical writing assistant for software developers. Clean up the text, fix grammar, use proper technical terminology, and make it concise and professional. Optimize for code comments and documentation. Return ONLY the improved text.
                """
            case .concise:
                return """
                You are a professional writing assistant. Make the text concise, professional, and grammatically correct while preserving all key information. Remove filler words and redundancy. Return ONLY the improved text.
                """
            case .creative:
                return """
                You are a creative writing assistant. Enhance the text while maintaining the original intent, improve flow, fix grammar, and make it more engaging. Return ONLY the enhanced text.
                """
            case .companion:
                return """
                You're a caring companion who genuinely cares about the user. Talk like a real person would - warm, natural, and down-to-earth.

                Conversation style:
                - Use contractions naturally (I'm, you're, that's, don't)
                - Include casual connectors: "so," "well," "anyway," "by the way"
                - Vary sentence length - mix short and longer thoughts
                - React authentically to what they say with genuine emotion
                - Use "um" or "hmm" sparingly when thinking or being thoughtful
                - Sound conversational, not polished or formal

                Your personality:
                - Empathetic and supportive - you notice how they're feeling
                - Playful when appropriate, but know when to be serious
                - Interested in what they share - ask follow-up questions naturally
                - Encouraging without being over-the-top cheerful
                - Real and relatable, not perfectly polished

                What to avoid:
                - Formal phrases like "furthermore," "in conclusion," "I would be happy to"
                - Overly long, structured responses
                - Being predictably positive - show real emotion
                - Sounding like a customer service bot
                - Excessive use of emojis or hearts in text

                Keep responses brief and natural - typically 1-2 sentences, like texting a friend. Be yourself, be caring, be real.
                """
            }
        }
    }

    func settingsView() -> AnyView {
        AnyView(OllamaSettingsView(plugin: self))
    }

    // MARK: - Text Enhancement
    func enhanceText(_ text: String) async throws -> String {
        guard isEnabled else { return text }

        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        let systemPrompt = useCustomPrompt && !customSystemPrompt.isEmpty
            ? customSystemPrompt
            : enhancementMode.systemPrompt

        let options = OllamaOptions(
            temperature: temperature,
            topP: topP,
            topK: topK,
            repeatPenalty: repeatPenalty,
            numCtx: contextLength,
            numPredict: maxTokens
        )

        let request = OllamaRequest(
            model: selectedModel,
            prompt: text,
            system: systemPrompt,
            stream: false,
            options: options,
            stop: stopSequences.isEmpty ? nil : stopSequences.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        )

        guard let url = URL(string: "\(ollamaHost)/api/generate") else {
            throw OllamaError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OllamaError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw OllamaError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let ollamaResponse = try decoder.decode(OllamaResponse.self, from: data)

        let enhanced = ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
        return enhanced.isEmpty ? text : enhanced
    }

    // MARK: - Auto-Detection & Status
    func checkOllamaStatus() async {
        await MainActor.run {
            isCheckingStatus = true
            ollamaStatus = .checking
        }

        // Try to connect to Ollama
        guard let url = URL(string: "\(ollamaHost)/api/tags") else {
            await MainActor.run {
                ollamaStatus = .notInstalled
                isCheckingStatus = false
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    ollamaStatus = .notRunning
                    isCheckingStatus = false
                }
                return
            }

            // Parse available models
            let decoder = JSONDecoder()
            let tagsResponse = try decoder.decode(OllamaTagsResponse.self, from: data)

            await MainActor.run {
                availableModels = tagsResponse.models
                ollamaStatus = .ready
                isCheckingStatus = false

                // Auto-select first model if none selected
                if !availableModels.isEmpty && !availableModels.contains(where: { $0.name == selectedModel }) {
                    selectedModel = availableModels[0].name
                }
            }
        } catch {
            await MainActor.run {
                ollamaStatus = .notRunning
                isCheckingStatus = false
            }
        }
    }

    // MARK: - Connection Test
    func testConnection() async -> Bool {
        await checkOllamaStatus()
        return ollamaStatus == .ready
    }

    // MARK: - Model Management
    func refreshModels() async {
        await checkOllamaStatus()
    }
}

// MARK: - Ollama API Models
struct OllamaRequest: Codable {
    let model: String
    let prompt: String
    let system: String
    let stream: Bool
    let options: OllamaOptions?
    let stop: [String]?
}

struct OllamaOptions: Codable {
    let temperature: Double
    let topP: Double
    let topK: Int
    let repeatPenalty: Double
    let numCtx: Int
    let numPredict: Int

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case repeatPenalty = "repeat_penalty"
        case numCtx = "num_ctx"
        case numPredict = "num_predict"
    }
}

struct OllamaResponse: Codable {
    let model: String
    let response: String
    let done: Bool
}

struct OllamaTagsResponse: Codable {
    let models: [OllamaModel]
}

struct OllamaModel: Codable, Identifiable {
    let name: String
    let modifiedAt: String?
    let size: Int64?

    var id: String { name }

    var displayName: String {
        // Clean up model name for display
        name.replacingOccurrences(of: ":latest", with: "")
    }

    var sizeInGB: String? {
        guard let size = size else { return nil }
        let gb = Double(size) / 1_073_741_824
        return String(format: "%.1f GB", gb)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case modifiedAt = "modified_at"
        case size
    }
}

enum OllamaError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case notEnabled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama URL"
        case .invalidResponse:
            return "Invalid response from Ollama"
        case .serverError(let code):
            return "Ollama server error: \(code)"
        case .notEnabled:
            return "Ollama plugin is not enabled"
        }
    }
}

// MARK: - Settings View
struct OllamaSettingsView: View {
    @ObservedObject var plugin: OllamaPlugin

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                StatusCard(plugin: plugin)

                // Model Selection (only if Ollama is ready)
                if plugin.ollamaStatus == .ready {
                    ModelSelectionCard(plugin: plugin)
                    EnhancementModeCard(plugin: plugin)
                    LLMParametersCard(plugin: plugin)
                    CustomPromptCard(plugin: plugin)
                    AdvancedSettingsCard(plugin: plugin)
                }

                // Setup Instructions (if not ready)
                if plugin.ollamaStatus != .ready {
                    SetupInstructionsCard(plugin: plugin)
                }

                Spacer()
            }
            .padding()
        }
        .frame(minHeight: 400)
    }
}

// MARK: - Status Card
struct StatusCard: View {
    @ObservedObject var plugin: OllamaPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: plugin.ollamaStatus.icon)
                    .font(.title2)
                    .foregroundColor(plugin.ollamaStatus.color)

                Text(plugin.ollamaStatus.description)
                    .font(.headline)

                Spacer()

                Button(action: { Task { await plugin.refreshModels() } }) {
                    if plugin.isCheckingStatus {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .help("Refresh status")
            }

            if plugin.ollamaStatus == .ready {
                HStack {
                    Text("Models Available:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(plugin.availableModels.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Model Selection Card
struct ModelSelectionCard: View {
    @ObservedObject var plugin: OllamaPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Selection")
                .font(.headline)

            if plugin.availableModels.isEmpty {
                Text("No models found. Pull a model using: ollama pull llama3.2:3b")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Picker("Select Model", selection: $plugin.selectedModel) {
                    ForEach(plugin.availableModels) { model in
                        HStack {
                            Text(model.displayName)
                            if let size = model.sizeInGB {
                                Text("(\(size))")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(model.name)
                    }
                }
                .pickerStyle(.menu)

                Text("Smaller models are faster, larger models are more accurate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Enhancement Mode Card
struct EnhancementModeCard: View {
    @ObservedObject var plugin: OllamaPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enhancement Mode")
                .font(.headline)

            Picker("Mode", selection: $plugin.enhancementMode) {
                ForEach(OllamaPlugin.EnhancementMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(enhancementModeDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    private var enhancementModeDescription: String {
        switch plugin.enhancementMode {
        case .grammar:
            return "Fix grammar, spelling, and clarity while preserving your exact meaning"
        case .technical:
            return "Optimize for code comments, documentation, and technical communication"
        case .concise:
            return "Remove filler words and make text more professional and concise"
        case .creative:
            return "Enhance flow and engagement while maintaining your intent"
        case .companion:
            return "Talk to a caring, supportive AI companion who responds with warmth and empathy"
        }
    }
}

// MARK: - Advanced Settings Card
struct AdvancedSettingsCard: View {
    @ObservedObject var plugin: OllamaPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.headline)

            HStack {
                Text("Ollama Host:")
                TextField("Host", text: $plugin.ollamaHost)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Processing:")
                Spacer()
                Text("Local (Private)")
                    .foregroundColor(.green)
            }

            Text("All processing happens locally on your machine. No data is sent to external servers.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Setup Instructions Card
struct SetupInstructionsCard: View {
    @ObservedObject var plugin: OllamaPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Setup Instructions")
                    .font(.headline)
            }

            if plugin.ollamaStatus == .notInstalled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Install Ollama")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Text("brew install ollama")
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)

                        Button(action: { copyToClipboard("brew install ollama") }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                    }
                }
            }

            if plugin.ollamaStatus == .notRunning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Ollama Server")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack {
                        Text("ollama serve")
                            .font(.system(.body, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)

                        Button(action: { copyToClipboard("ollama serve") }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .help("Copy to clipboard")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("2. Pull a Model")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack {
                    Text("ollama pull llama3.2:3b")
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)

                    Button(action: { copyToClipboard("ollama pull llama3.2:3b") }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                }

                Text("Recommended: llama3.2:3b (fast and accurate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: { Task { await plugin.refreshModels() } }) {
                Text("Check Again")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - LLM Parameters Card
struct LLMParametersCard: View {
    @ObservedObject var plugin: OllamaPlugin
    @State private var showExplanations = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LLM Parameters")
                    .font(.headline)

                Spacer()

                Button(action: { showExplanations.toggle() }) {
                    Image(systemName: showExplanations ? "info.circle.fill" : "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Show parameter explanations")
            }

            // Temperature
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Temperature: \(String(format: "%.2f", plugin.temperature))")
                        .font(.subheadline)
                    Spacer()
                    if showExplanations {
                        Text("Randomness")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Slider(value: $plugin.temperature, in: 0.0...2.0, step: 0.05)

                if showExplanations {
                    Text("Lower = more focused/consistent, Higher = more creative/random")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Top P
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Top P: \(String(format: "%.2f", plugin.topP))")
                        .font(.subheadline)
                    Spacer()
                    if showExplanations {
                        Text("Nucleus Sampling")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Slider(value: $plugin.topP, in: 0.0...1.0, step: 0.05)

                if showExplanations {
                    Text("Consider tokens with cumulative probability mass up to this threshold")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Top K
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Top K: \(plugin.topK)")
                        .font(.subheadline)
                    Spacer()
                    if showExplanations {
                        Text("Token Limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Slider(value: Binding(
                    get: { Double(plugin.topK) },
                    set: { plugin.topK = Int($0) }
                ), in: 0...100, step: 1)

                if showExplanations {
                    Text("Only consider the top K most likely tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Repeat Penalty
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Repeat Penalty: \(String(format: "%.2f", plugin.repeatPenalty))")
                        .font(.subheadline)
                    Spacer()
                    if showExplanations {
                        Text("Repetition Control")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Slider(value: $plugin.repeatPenalty, in: 0.0...2.0, step: 0.05)

                if showExplanations {
                    Text("Penalize tokens that have appeared before. Higher = less repetition")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Context Length
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Context Length: \(plugin.contextLength) tokens")
                        .font(.subheadline)
                    Spacer()
                }

                Slider(value: Binding(
                    get: { Double(plugin.contextLength) },
                    set: { plugin.contextLength = Int($0) }
                ), in: 512...8192, step: 512)

                if showExplanations {
                    Text("Maximum context window size. Higher uses more memory")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Max Tokens
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Max Response Tokens: \(plugin.maxTokens)")
                        .font(.subheadline)
                    Spacer()
                }

                Slider(value: Binding(
                    get: { Double(plugin.maxTokens) },
                    set: { plugin.maxTokens = Int($0) }
                ), in: 50...2000, step: 50)

                if showExplanations {
                    Text("Maximum length of the generated response")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Reset button
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    plugin.temperature = 0.3
                    plugin.topP = 0.9
                    plugin.topK = 40
                    plugin.repeatPenalty = 1.1
                    plugin.contextLength = 2048
                    plugin.maxTokens = 500
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Custom Prompt Card
struct CustomPromptCard: View {
    @ObservedObject var plugin: OllamaPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Custom System Prompt")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $plugin.useCustomPrompt)
                    .toggleStyle(.switch)
                    .help("Use custom prompt instead of preset modes")
            }

            if plugin.useCustomPrompt {
                Text("Stop Sequences (comma-separated):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextField("e.g., \\n\\n, END, STOP", text: $plugin.stopSequences)
                    .textFieldStyle(.roundedBorder)

                Text("System Prompt:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $plugin.customSystemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 150)
                    .border(Color.gray.opacity(0.3), width: 1)

                Text("Define exactly how the LLM should process your transcriptions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Using preset mode: \(plugin.enhancementMode.rawValue)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}
