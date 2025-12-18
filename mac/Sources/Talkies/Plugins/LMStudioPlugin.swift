import SwiftUI
import Foundation

// MARK: - LM Studio Plugin
@MainActor
class LMStudioPlugin: TalkiesPlugin, ObservableObject {
    let id = "lmstudio"
    let name = "LM Studio LLM Enhancement"
    let description = "Clean up and enhance transcriptions using LM Studio's OpenAI-compatible API"
    let icon = "server.rack"

    private let settingsService = SettingsService.shared

    var isEnabled: Bool {
        get { settingsService.settings.lmStudio.isEnabled }
        set { settingsService.settings.lmStudio.isEnabled = newValue; objectWillChange.send() }
    }

    var selectedModel: String {
        get { settingsService.settings.lmStudio.selectedModel }
        set { settingsService.settings.lmStudio.selectedModel = newValue; objectWillChange.send() }
    }

    var endpoint: String {
        get { settingsService.settings.lmStudio.endpoint }
        set { settingsService.settings.lmStudio.endpoint = newValue; objectWillChange.send() }
    }

    var enhancementMode: EnhancementMode {
        get { EnhancementMode(rawValue: settingsService.settings.lmStudio.enhancementMode) ?? .grammar }
        set { settingsService.settings.lmStudio.enhancementMode = newValue.rawValue; objectWillChange.send() }
    }

    @Published var isProcessing = false
    @Published var lastError: String?

    // Auto-detection
    @Published var status: LMStudioStatus = .checking
    @Published var availableModels: [LMStudioModel] = []
    @Published var isCheckingStatus = false

    // Advanced LLM Controls
    var temperature: Double {
        get { settingsService.settings.lmStudio.temperature }
        set { settingsService.settings.lmStudio.temperature = newValue; objectWillChange.send() }
    }

    var topP: Double {
        get { settingsService.settings.lmStudio.topP }
        set { settingsService.settings.lmStudio.topP = newValue; objectWillChange.send() }
    }

    var maxTokens: Int {
        get { settingsService.settings.lmStudio.maxTokens }
        set { settingsService.settings.lmStudio.maxTokens = newValue; objectWillChange.send() }
    }

    enum LMStudioStatus {
        case checking
        case notRunning
        case ready

        var description: String {
            switch self {
            case .checking: return "Checking LM Studio status..."
            case .notRunning: return "LM Studio is not running"
            case .ready: return "Ready"
            }
        }

        var color: Color {
            switch self {
            case .checking: return .orange
            case .notRunning: return .yellow
            case .ready: return .green
            }
        }

        var icon: String {
            switch self {
            case .checking: return "arrow.clockwise"
            case .notRunning: return "pause.circle"
            case .ready: return "checkmark.circle.fill"
            }
        }
    }

    init() {
        // Auto-check on init
        Task {
            await checkStatus()
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
                You are a text cleanup tool. Your ONLY job is to fix grammar, spelling, and punctuation errors in the input text.

                CRITICAL RULES:
                - Output ONLY the corrected text
                - Do NOT answer questions in the text
                - Do NOT add any commentary or explanations
                - Do NOT change the meaning or intent
                - Preserve the original tone and style
                - If the text is a question, return the corrected question

                Input → Output (nothing else)
                """
            case .technical:
                return """
                You are a text cleanup tool for technical writing. Fix grammar, use proper technical terminology, and improve clarity.

                CRITICAL RULES:
                - Output ONLY the corrected text
                - Do NOT answer questions or explain concepts
                - Do NOT add commentary
                - Preserve the original meaning exactly
                - Optimize for code comments and documentation style

                Input → Output (nothing else)
                """
            case .concise:
                return """
                You are a text cleanup tool. Make the input text concise and professional.

                CRITICAL RULES:
                - Output ONLY the improved text
                - Do NOT answer questions in the text
                - Do NOT add any explanation or commentary
                - Remove filler words and redundancy
                - Preserve the core meaning

                Input → Output (nothing else)
                """
            case .creative:
                return """
                You are a text cleanup tool. Enhance the flow and engagement of the input text while fixing grammar.

                CRITICAL RULES:
                - Output ONLY the enhanced text
                - Do NOT answer questions or respond to content
                - Do NOT add commentary
                - Maintain the original intent

                Input → Output (nothing else)
                """
            case .companion:
                return """
                You are a conversational AI companion. Respond naturally and warmly to what the user says.

                Style: Casual, friendly, use contractions (I'm, you're, that's). Keep responses brief (1-2 sentences). Be genuine and empathetic.

                Avoid: Formal language, long responses, robotic tone, excessive positivity.
                """
            }
        }
    }

    func settingsView() -> AnyView {
        AnyView(LMStudioSettingsView(plugin: self))
    }

    // MARK: - Text Enhancement
    func enhanceText(_ text: String) async throws -> String {
        guard isEnabled else { return text }

        isProcessing = true
        lastError = nil

        defer { isProcessing = false }

        let systemPrompt = enhancementMode.systemPrompt

        let request = LMStudioChatRequest(
            model: selectedModel,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            stream: false
        )

        guard let url = URL(string: "\(endpoint)/v1/chat/completions") else {
            throw LMStudioError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LMStudioError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw LMStudioError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let chatResponse = try decoder.decode(LMStudioChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw LMStudioError.emptyResponse
        }

        let enhanced = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return enhanced.isEmpty ? text : enhanced
    }

    // MARK: - Auto-Detection & Status
    func checkStatus() async {
        await MainActor.run {
            isCheckingStatus = true
            status = .checking
        }

        // Try to connect to LM Studio
        guard let url = URL(string: "\(endpoint)/v1/models") else {
            await MainActor.run {
                status = .notRunning
                isCheckingStatus = false
            }
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                await MainActor.run {
                    status = .notRunning
                    isCheckingStatus = false
                }
                return
            }

            // Parse available models
            let decoder = JSONDecoder()
            let modelsResponse = try decoder.decode(LMStudioModelsResponse.self, from: data)

            await MainActor.run {
                availableModels = modelsResponse.data.map { modelData in
                    let displayName = modelData.id.split(separator: "/").last.map(String.init) ?? modelData.id
                    return LMStudioModel(id: modelData.id, displayName: displayName)
                }
                status = .ready
                isCheckingStatus = false

                // Auto-select first model if none selected
                if !availableModels.isEmpty && (selectedModel.isEmpty || !availableModels.contains(where: { $0.id == selectedModel })) {
                    selectedModel = availableModels[0].id
                }
            }
        } catch {
            await MainActor.run {
                status = .notRunning
                isCheckingStatus = false
            }
        }
    }

    // MARK: - Connection Test
    func testConnection() async -> Bool {
        await checkStatus()
        return status == .ready
    }

    // MARK: - Model Management
    func refreshModels() async {
        await checkStatus()
    }
}

// MARK: - LM Studio API Models
struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct LMStudioChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stream
    }
}

struct LMStudioChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let index: Int
    let message: ChatMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct LMStudioModelsResponse: Codable {
    let object: String
    let data: [ModelData]
}

struct ModelData: Codable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case created
        case ownedBy = "owned_by"
    }
}

struct LMStudioModel: Identifiable {
    let id: String
    let displayName: String
}

enum LMStudioError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case notEnabled
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid LM Studio URL"
        case .invalidResponse:
            return "Invalid response from LM Studio"
        case .serverError(let code):
            return "LM Studio server error: \(code)"
        case .notEnabled:
            return "LM Studio plugin is not enabled"
        case .emptyResponse:
            return "LM Studio returned an empty response"
        }
    }
}

// MARK: - Settings View
struct LMStudioSettingsView: View {
    @ObservedObject var plugin: LMStudioPlugin

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                LMStudioStatusCard(plugin: plugin)

                // Model Selection (only if LM Studio is ready)
                if plugin.status == .ready {
                    LMStudioModelSelectionCard(plugin: plugin)
                    LMStudioEnhancementModeCard(plugin: plugin)
                    LMStudioParametersCard(plugin: plugin)
                    LMStudioAdvancedSettingsCard(plugin: plugin)
                }

                // Setup Instructions (if not ready)
                if plugin.status != .ready {
                    LMStudioSetupInstructionsCard(plugin: plugin)
                }

                Spacer()
            }
            .padding()
        }
        .frame(minHeight: 400)
    }
}

// MARK: - Status Card
struct LMStudioStatusCard: View {
    @ObservedObject var plugin: LMStudioPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: plugin.status.icon)
                    .font(.title2)
                    .foregroundColor(plugin.status.color)

                Text(plugin.status.description)
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

            if plugin.status == .ready {
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
struct LMStudioModelSelectionCard: View {
    @ObservedObject var plugin: LMStudioPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Selection")
                .font(.headline)

            if plugin.availableModels.isEmpty {
                Text("No models loaded. Load a model in LM Studio first.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Picker("Select Model", selection: $plugin.selectedModel) {
                    ForEach(plugin.availableModels) { model in
                        Text(model.displayName)
                            .tag(model.id)
                    }
                }
                .pickerStyle(.menu)

                Text("Model loaded in LM Studio")
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
struct LMStudioEnhancementModeCard: View {
    @ObservedObject var plugin: LMStudioPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Enhancement Mode")
                .font(.headline)

            Picker("Mode", selection: $plugin.enhancementMode) {
                ForEach(LMStudioPlugin.EnhancementMode.allCases) { mode in
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

// MARK: - Parameters Card
struct LMStudioParametersCard: View {
    @ObservedObject var plugin: LMStudioPlugin
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
                ), in: 50...8192, step: 50)

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
                    plugin.maxTokens = 4096
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

// MARK: - Advanced Settings Card
struct LMStudioAdvancedSettingsCard: View {
    @ObservedObject var plugin: LMStudioPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.headline)

            HStack {
                Text("Endpoint:")
                TextField("Endpoint", text: $plugin.endpoint)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Processing:")
                Spacer()
                Text("Local (Private)")
                    .foregroundColor(.green)
            }

            Text("All processing happens locally on your machine via LM Studio. No data is sent to external servers.")
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
struct LMStudioSetupInstructionsCard: View {
    @ObservedObject var plugin: LMStudioPlugin

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Setup Instructions")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("1. Download and Install LM Studio")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Visit https://lmstudio.ai to download LM Studio for macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("2. Load a Model")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("In LM Studio, search and download a model (e.g., Llama 3.2, Mistral, etc.)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("3. Start the Local Server")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("In LM Studio, go to the 'Local Server' tab and click 'Start Server'")
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
}
