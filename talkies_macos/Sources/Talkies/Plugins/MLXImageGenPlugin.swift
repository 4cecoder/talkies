import SwiftUI
import Foundation
import MLX

// MARK: - MLX Image Generation Plugin
@MainActor
class MLXImageGenPlugin: TalkiesPlugin, ObservableObject {
    let id = "mlx-image-gen"
    let name = "Image Generation"
    let description = "Generate images from text using Stable Diffusion on Apple Silicon"
    let icon = "photo.on.rectangle.angled"

    @Published var isEnabled = false {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "mlx-image-gen.isEnabled") }
    }
    @Published var pluginStatus: MLXImageGenStatus = .notInstalled
    @Published var availableModels: [String] = []
    @Published var selectedModel = "FLUX.1-schnell"

    // Generation parameters
    @Published var prompt: String = ""
    @Published var negativePrompt: String = ""
    @Published var steps: Int = 20
    @Published var guidanceScale: Double = 7.5
    @Published var width: Int = 512
    @Published var height: Int = 512
    @Published var seed: Int = -1 // -1 for random

    @Published var isGenerating = false
    @Published var generatedImagePath: String?
    @Published var lastError: String?

    enum MLXImageGenStatus {
        case checking
        case notInstalled
        case ready
        case error(String)
    }

    init() {
        // Load saved settings
        isEnabled = UserDefaults.standard.bool(forKey: "mlx-image-gen.isEnabled")

        // Default available models
        availableModels = [
            "FLUX.1-schnell",
            "FLUX.1-dev",
            "Stable Diffusion 3",
            "Stable Diffusion XL",
            "Stable Diffusion 2.1"
        ]

        if let savedModel = UserDefaults.standard.string(forKey: "mlx-image-gen.selectedModel") {
            selectedModel = savedModel
        }

        Task {
            await checkStatus()
        }
    }

    func checkStatus() async {
        await MainActor.run {
            pluginStatus = .ready
        }
    }

    func generateImage(prompt: String) async throws -> URL {
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }

        do {
            // Configure the pipeline
            let config = DiffusionConfiguration(
                prompt: prompt,
                negativePrompt: negativePrompt.isEmpty ? nil : negativePrompt,
                guidanceScale: Float(guidanceScale),
                numInferenceSteps: steps,
                width: width,
                height: height,
                seed: seed == -1 ? nil : UInt32(seed)
            )

            // Generate image using DiffusionKit
            let pipeline = try await StableDiffusionPipeline(modelName: selectedModel)
            let image = try await pipeline.generate(configuration: config)

            // Save to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let filename = "talkies-generated-\(timestamp).png"
            let fileURL = tempDir.appendingPathComponent(filename)

            // Convert NSImage to PNG data
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw NSError(domain: "MLXImageGenPlugin", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to convert image to PNG"
                ])
            }
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "MLXImageGenPlugin", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to generate PNG data"
                ])
            }
            try pngData.write(to: fileURL)

            await MainActor.run {
                generatedImagePath = fileURL.path
                isGenerating = false
            }

            return fileURL
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isGenerating = false
            }
            throw error
        }
    }

    func settingsView() -> AnyView {
        AnyView(MLXImageGenSettingsView(plugin: self))
    }
}

// MARK: - Settings View
struct MLXImageGenSettingsView: View {
    @ObservedObject var plugin: MLXImageGenPlugin

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                ImageGenStatusCard(status: plugin.pluginStatus)

                // Setup Instructions (shown when not ready)
                if case .notInstalled = plugin.pluginStatus {
                    ImageGenSetupInstructionsCard()
                }

                // Model Selection
                ImageGenModelCard(
                    availableModels: plugin.availableModels,
                    selectedModel: $plugin.selectedModel
                )

                // Prompt Input
                ImagePromptCard(
                    prompt: $plugin.prompt,
                    negativePrompt: $plugin.negativePrompt
                )

                // Generation Parameters
                GenerationParametersCard(
                    steps: $plugin.steps,
                    guidanceScale: $plugin.guidanceScale,
                    width: $plugin.width,
                    height: $plugin.height,
                    seed: $plugin.seed
                )

                // Generate Button
                if plugin.isEnabled {
                    Button(action: {
                        Task {
                            try? await plugin.generateImage(prompt: plugin.prompt)
                        }
                    }) {
                        HStack {
                            if plugin.isGenerating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(plugin.isGenerating ? "Generating..." : "Generate Image")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(plugin.isGenerating ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(plugin.isGenerating || plugin.prompt.isEmpty)
                }

                // Generated Image Preview
                if let imagePath = plugin.generatedImagePath,
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Generated Image")
                            .font(.headline)

                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .cornerRadius(8)

                        HStack {
                            Button("Open in Finder") {
                                NSWorkspace.shared.selectFile(imagePath, inFileViewerRootedAtPath: "")
                            }

                            Button("Copy to Clipboard") {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.writeObjects([nsImage])
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }

                // Error Display
                if let error = plugin.lastError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
        }
    }
}

// MARK: - UI Cards
struct ImageGenStatusCard: View {
    let status: MLXImageGenPlugin.MLXImageGenStatus

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            Text(statusText)
                .font(.subheadline)

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    var statusColor: Color {
        switch status {
        case .checking: return .yellow
        case .notInstalled: return .red
        case .ready: return .green
        case .error: return .red
        }
    }

    var statusText: String {
        switch status {
        case .checking: return "Checking MLX status..."
        case .notInstalled: return "MLX not installed"
        case .ready: return "Ready"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

struct ImageGenModelCard: View {
    let availableModels: [String]
    @Binding var selectedModel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model")
                .font(.headline)

            Picker("", selection: $selectedModel) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ImagePromptCard: View {
    @Binding var prompt: String
    @Binding var negativePrompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompts")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $prompt)
                    .font(.body)
                    .frame(height: 80)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Negative Prompt (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $negativePrompt)
                    .font(.body)
                    .frame(height: 60)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct GenerationParametersCard: View {
    @Binding var steps: Int
    @Binding var guidanceScale: Double
    @Binding var width: Int
    @Binding var height: Int
    @Binding var seed: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Generation Parameters")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Steps: \(steps)")
                    Spacer()
                }
                Slider(value: Binding(
                    get: { Double(steps) },
                    set: { steps = Int($0) }
                ), in: 10...100, step: 5)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Guidance Scale: \(String(format: "%.1f", guidanceScale))")
                    Spacer()
                }
                Slider(value: $guidanceScale, in: 1...20, step: 0.5)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Width")
                    Picker("", selection: $width) {
                        Text("512").tag(512)
                        Text("768").tag(768)
                        Text("1024").tag(1024)
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Height")
                    Picker("", selection: $height) {
                        Text("512").tag(512)
                        Text("768").tag(768)
                        Text("1024").tag(1024)
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Seed (-1 for random)")
                TextField("Seed", value: $seed, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ImageGenSetupInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)

                Text("Setup Instructions")
                    .font(.headline)
            }

            Text("Image generation requires model setup. Choose one of these options:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Text("Option 1: Hugging Face Diffusers App (Recommended)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Download the free Diffusers app from Hugging Face. It includes pre-converted models for Stable Diffusion, FLUX, and more.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Open Hugging Face Diffusers") {
                    NSWorkspace.shared.open(URL(string: "https://huggingface.co/spaces/argmaxinc/DiffusersApp")!)
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Text("Option 2: Manual Installation (Advanced)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ImageGenSetupStep(
                    number: 1,
                    title: "Install Apple's ml-stable-diffusion",
                    command: "pip install ml-stable-diffusion",
                    description: "Apple's tool for converting models to Core ML"
                )

                ImageGenSetupStep(
                    number: 2,
                    title: "Download and Convert a Model",
                    command: "python -m python_coreml_stable_diffusion.torch2coreml --model-version stabilityai/stable-diffusion-2-1-base --convert-unet --convert-text-encoder --convert-vae-decoder --chunk-unet",
                    description: "This downloads and converts Stable Diffusion 2.1 (~5GB)"
                )

                ImageGenSetupStep(
                    number: 3,
                    title: "Place Models in ~/Library/Application Support/Talkies/models",
                    command: "mkdir -p ~/Library/Application\\ Support/Talkies/models && mv coreml-stable-diffusion-2-1-base ~/Library/Application\\ Support/Talkies/models/",
                    description: "Talkies will auto-detect models in this directory"
                )
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ImageGenSetupStep: View {
    let number: Int
    let title: String
    let command: String
    let description: String
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(number).")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack {
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(6)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                }) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .foregroundColor(showCopied ? .green : .orange)
                }
                .buttonStyle(.borderless)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
