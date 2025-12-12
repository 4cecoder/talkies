import SwiftUI
import Foundation
import AVFoundation
import KokoroSwift
import MLX
import MLXUtilsLibrary

// MARK: - MLX Text-to-Speech Plugin
class MLXTTSPlugin: TalkiesPlugin, ObservableObject {
    let id = "mlx-tts"
    let name = "Text-to-Speech"
    let description = "Convert text to speech using MLX on Apple Silicon"
    let icon = "speaker.wave.3"

    enum TTSEngine: String, CaseIterable {
        case native = "Native macOS"
        case kokoro = "Kokoro TTS"
    }

    @Published var isEnabled = false {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "mlx-tts.isEnabled") }
    }
    @Published var selectedEngine: TTSEngine = .native {
        didSet {
            UserDefaults.standard.set(selectedEngine.rawValue, forKey: "mlx-tts.selectedEngine")
            Task { await checkStatus() }
        }
    }
    @Published var pluginStatus: MLXTTSStatus = .notInstalled
    @Published var availableVoices: [String] = []
    @Published var selectedVoice = "default" {
        didSet { UserDefaults.standard.set(selectedVoice, forKey: "mlx-tts.selectedVoice") }
    }

    // TTS parameters
    @Published var text: String = ""
    @Published var speed: Double = 1.0
    @Published var pitch: Double = 1.0
    @Published var volume: Double = 1.0

    @Published var isSynthesizing = false
    @Published var generatedAudioPath: String?
    @Published var lastError: String?

    // Audio player for preview
    private var audioPlayer: AVAudioPlayer?

    // Kokoro TTS (wrapped in actor-isolated storage)
    private var kokoroTTS: KokoroTTS?
    private var kokoroVoices: [String: MLXArray] = [:]

    // Storage for background access
    private final class TTSStorage: @unchecked Sendable {
        var tts: KokoroTTS?
        var voices: [String: MLXArray] = [:]
        private let lock = NSLock()

        func set(tts: KokoroTTS?, voices: [String: MLXArray]) {
            lock.lock()
            defer { lock.unlock() }
            self.tts = tts
            self.voices = voices
        }

        func getTTS() -> KokoroTTS? {
            lock.lock()
            defer { lock.unlock() }
            return tts
        }

        func getVoice(name: String) -> MLXArray? {
            lock.lock()
            defer { lock.unlock() }
            return voices[name]
        }
    }

    private let ttsStorage = TTSStorage()

    enum MLXTTSStatus {
        case checking
        case notInstalled
        case ready
        case error(String)
    }

    init() {
        // Load saved settings
        isEnabled = UserDefaults.standard.bool(forKey: "mlx-tts.isEnabled")
        if let savedEngine = UserDefaults.standard.string(forKey: "mlx-tts.selectedEngine"),
           let engine = TTSEngine(rawValue: savedEngine) {
            selectedEngine = engine
        }

        Task {
            await checkStatus()
        }
    }

    nonisolated func checkStatus() async {
        await MainActor.run {
            self.pluginStatus = .checking
        }

        let engine = await selectedEngine
        switch engine {
        case .native:
            await loadNativeVoices()
            await MainActor.run {
                self.pluginStatus = .ready
            }

        case .kokoro:
            await loadKokoroTTS()
        }
    }

    nonisolated private func loadNativeVoices() async {
        let voices = NSSpeechSynthesizer.availableVoices.map { voice in
            let attributes = NSSpeechSynthesizer.attributes(forVoice: voice)
            return attributes[.name] as? String ?? voice.rawValue
        }

        let savedVoice = UserDefaults.standard.string(forKey: "mlx-tts.selectedVoice")

        await MainActor.run {
            self.availableVoices = voices
            if let savedVoice, voices.contains(savedVoice) {
                self.selectedVoice = savedVoice
            } else if !voices.isEmpty {
                self.selectedVoice = voices[0]
            }
        }
    }

    nonisolated private func checkForMetalLibrary() async -> Bool {
        // Check common locations for .metallib files
        let searchPaths = [
            ".build/arm64-apple-macosx/debug",
            ".build/debug",
            ".build/arm64-apple-macosx/release",
            ".build/release"
        ]

        for path in searchPaths {
            let fm = FileManager.default
            guard fm.fileExists(atPath: path) else { continue }

            do {
                let contents = try fm.contentsOfDirectory(atPath: path)
                // Look for any .metallib file
                if contents.contains(where: { $0.hasSuffix(".metallib") }) {
                    print("✓ Found .metallib file in \(path)")
                    return true
                }
            } catch {
                print("Error reading \(path): \(error)")
            }
        }

        // Also check for the specific default.metallib in mlx-swift checkout
        let mlxCheckoutPath = ".build/checkouts/mlx-swift"
        if FileManager.default.fileExists(atPath: mlxCheckoutPath) {
            // Recursively search for default.metallib
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/find")
            task.arguments = [mlxCheckoutPath, "-name", "default.metallib", "-o", "-name", "*.metallib"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("✓ Found .metallib file in mlx-swift checkout")
                    return true
                }
            } catch {
                print("Error searching for metallib: \(error)")
            }
        }

        print("❌ No .metallib files found in any search path")
        return false
    }

    nonisolated private func loadKokoroTTS() async {
        // CRITICAL: MLX requires Metal library (default.metallib) to be compiled by Xcode
        // Check for it BEFORE attempting initialization to prevent C++ fatal errors
        print("⚠️ Checking for MLX Metal shaders...")

        // Search for .metallib files in the build directory
        let metalLibExists = await checkForMetalLibrary()

        if !metalLibExists {
            print("❌ No .metallib files found - Kokoro TTS cannot be loaded")
            await MainActor.run {
                self.pluginStatus = .error("Kokoro TTS requires Xcode. Using Native TTS instead.")
                self.lastError = "⚠️ Kokoro TTS unavailable: MLX Metal shaders require Xcode to compile.\n\nThe required default.metallib file is missing. This can only be generated by building with Xcode.\n\nAutomatically switched to Native macOS TTS."
                self.selectedEngine = .native
            }
            return
        }

        print("✓ Metal library found, attempting to load Kokoro TTS...")

        do {
            // Get the model path
            let modelPath = URL(fileURLWithPath: "Resources/Kokoro/model")

            // Initialize Kokoro TTS
            print("Initializing KokoroTTS...")
            let tts = KokoroTTS(modelPath: modelPath, g2p: .misaki)
            print("✓ KokoroTTS initialized successfully")

            // Load voice embeddings
            let voicesDir = modelPath.appendingPathComponent("voices")
            let voiceFiles = try FileManager.default.contentsOfDirectory(at: voicesDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "npz" }

            var voices: [String: MLXArray] = [:]
            var voiceNames: [String] = []

            for voiceFile in voiceFiles {
                let voiceName = voiceFile.deletingPathExtension().lastPathComponent
                if let voiceData = NpyzReader.read(fileFromPath: voiceFile, isPacked: true),
                   let voiceArray = voiceData["voice"] {
                    voices[voiceName] = voiceArray
                    voiceNames.append(voiceName)
                }
            }

            let savedVoice = UserDefaults.standard.string(forKey: "mlx-tts.selectedVoice")

            // Store in thread-safe storage
            ttsStorage.set(tts: tts, voices: voices)

            await MainActor.run {
                // Note: kokoroTTS and kokoroVoices are stored in ttsStorage for thread-safe access
                self.availableVoices = voiceNames.sorted()

                if let savedVoice, voiceNames.contains(savedVoice) {
                    self.selectedVoice = savedVoice
                } else if !voiceNames.isEmpty {
                    self.selectedVoice = voiceNames[0]
                }

                self.pluginStatus = .ready
            }
        } catch {
            await MainActor.run {
                let errorMsg = error.localizedDescription

                // Check if it's the MLX Metal library error
                if errorMsg.contains("metallib") || errorMsg.contains("library not found") {
                    self.pluginStatus = .error("Kokoro TTS requires Xcode. Using Native TTS instead.")
                    self.lastError = "⚠️ Kokoro TTS unavailable: MLX Metal shaders require Xcode to compile.\n\nAutomatically switched to Native macOS TTS."

                    // Automatically fall back to native TTS
                    self.selectedEngine = .native
                    print("⚠️ Kokoro TTS failed (Metal library missing), falling back to Native TTS")
                } else {
                    self.pluginStatus = .error(errorMsg)
                    self.lastError = "Failed to load Kokoro TTS: \(errorMsg)"
                }
            }
        }
    }

    func synthesizeSpeech(text: String) async throws -> URL {
        isSynthesizing = true
        lastError = nil

        let engine = selectedEngine
        switch engine {
        case .native:
            return try await synthesizeNative(text: text)
        case .kokoro:
            return try await synthesizeKokoro(text: text)
        }
    }

    nonisolated private func synthesizeNative(text: String) async throws -> URL {
        let selectedVoiceName = await selectedVoice
        let currentSpeed = await speed

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                // Create speech synthesizer
                let synthesizer = NSSpeechSynthesizer()

                // Find the voice by name
                if let voiceIdentifier = NSSpeechSynthesizer.availableVoices.first(where: { voice in
                    let attributes = NSSpeechSynthesizer.attributes(forVoice: voice)
                    let name = attributes[.name] as? String
                    return name == selectedVoiceName
                }) {
                    synthesizer.setVoice(voiceIdentifier)
                }

                // Set rate (speed)
                synthesizer.rate = Float(currentSpeed) * 200 // Default rate is ~200 wpm

                // Generate audio file
                let tempDir = FileManager.default.temporaryDirectory
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let filename = "talkies-tts-\(timestamp).aiff"
                let fileURL = tempDir.appendingPathComponent(filename)

                // Start synthesizing to file
                synthesizer.startSpeaking(text, to: fileURL)

                // Wait for completion (synchronous for now, but wrapped in async)
                while synthesizer.isSpeaking {
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                }

                Task { @MainActor in
                    self.generatedAudioPath = fileURL.path
                    self.isSynthesizing = false
                    continuation.resume(returning: fileURL)
                }
            }
        }
    }

    nonisolated private func synthesizeKokoro(text: String) async throws -> URL {
        let currentSpeed = await speed
        let voice = await selectedVoice

        // Get from thread-safe storage
        guard let tts = ttsStorage.getTTS() else {
            throw NSError(domain: "MLXTTSPlugin", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Kokoro TTS not initialized"
            ])
        }

        guard let voiceEmbedding = ttsStorage.getVoice(name: voice) else {
            throw NSError(domain: "MLXTTSPlugin", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Voice embedding not found: \(voice)"
            ])
        }

        // Generate audio using Kokoro TTS (off main actor)
        let (audioSamples, _) = try tts.generateAudio(
            voice: voiceEmbedding,
            language: .enUS,
            text: text,
            speed: Float(currentSpeed)
        )

        // Convert audio samples to wav file
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "talkies-kokoro-\(timestamp).wav"
        let fileURL = tempDir.appendingPathComponent(filename)

        // Write WAV file
        try writeWAVFile(samples: audioSamples, to: fileURL, sampleRate: 24000)

        await MainActor.run {
            self.generatedAudioPath = fileURL.path
            self.isSynthesizing = false
        }

        return fileURL
    }

    nonisolated private func writeWAVFile(samples: [Float], to url: URL, sampleRate: Int) throws {
        // Convert Float samples to Int16
        let int16Samples = samples.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * Float(Int16.max))
        }

        // WAV header
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = UInt32(int16Samples.count * 2)

        var data = Data()

        // RIFF chunk
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: (36 + dataSize).littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })  // audio format (PCM)
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        for sample in int16Samples {
            data.append(withUnsafeBytes(of: sample.littleEndian) { Data($0) })
        }

        try data.write(to: url)
    }

    func playAudio(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = Float(volume)
            audioPlayer?.play()
        } catch {
            lastError = "Failed to play audio: \(error.localizedDescription)"
        }
    }

    func stopAudio() {
        audioPlayer?.stop()
    }

    func settingsView() -> AnyView {
        AnyView(MLXTTSSettingsView(plugin: self))
    }
}

// MARK: - Settings View
struct MLXTTSSettingsView: View {
    @ObservedObject var plugin: MLXTTSPlugin

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                TTSStatusCard(status: plugin.pluginStatus)

                // Engine Selection
                EngineSelectionCard(selectedEngine: $plugin.selectedEngine)

                // Info card about the selected engine
                if plugin.selectedEngine == .native {
                    NativeTTSInfoCard()
                } else {
                    KokoroTTSInfoCard()
                }

                // Voice Selection
                VoiceCard(
                    availableVoices: plugin.availableVoices,
                    selectedVoice: $plugin.selectedVoice,
                    engineName: plugin.selectedEngine.rawValue
                )

                // Text Input
                TextInputCard(text: $plugin.text)

                // Voice Parameters
                VoiceParametersCard(
                    speed: $plugin.speed,
                    pitch: $plugin.pitch,
                    volume: $plugin.volume
                )

                // Synthesize Button
                if plugin.isEnabled {
                    Button(action: {
                        Task {
                            try? await plugin.synthesizeSpeech(text: plugin.text)
                        }
                    }) {
                        HStack {
                            if plugin.isSynthesizing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(plugin.isSynthesizing ? "Synthesizing..." : "Generate Speech")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(plugin.isSynthesizing ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(plugin.isSynthesizing || plugin.text.isEmpty)
                }

                // Audio Controls
                if let audioPath = plugin.generatedAudioPath,
                   FileManager.default.fileExists(atPath: audioPath) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Generated Audio")
                            .font(.headline)

                        HStack {
                            Button(action: {
                                plugin.playAudio(url: URL(fileURLWithPath: audioPath))
                            }) {
                                Label("Play", systemImage: "play.fill")
                            }

                            Button(action: {
                                plugin.stopAudio()
                            }) {
                                Label("Stop", systemImage: "stop.fill")
                            }

                            Spacer()

                            Button("Open in Finder") {
                                NSWorkspace.shared.selectFile(audioPath, inFileViewerRootedAtPath: "")
                            }
                        }
                        .buttonStyle(.bordered)
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
struct TTSStatusCard: View {
    let status: MLXTTSPlugin.MLXTTSStatus

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
        case .checking: return "Checking MLX TTS status..."
        case .notInstalled: return "MLX TTS not installed"
        case .ready: return "Ready"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

struct EngineSelectionCard: View {
    @Binding var selectedEngine: MLXTTSPlugin.TTSEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TTS Engine")
                .font(.headline)

            Picker("", selection: $selectedEngine) {
                ForEach(MLXTTSPlugin.TTSEngine.allCases, id: \.self) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Text("Choose between native macOS TTS or Kokoro neural TTS")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct VoiceCard: View {
    let availableVoices: [String]
    @Binding var selectedVoice: String
    let engineName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice")
                .font(.headline)

            if availableVoices.isEmpty {
                Text("No voices available")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Picker("", selection: $selectedVoice) {
                    ForEach(availableVoices, id: \.self) { voice in
                        Text(voice.capitalized).tag(voice)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Text("\(engineName) voices (\(availableVoices.count) available)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct KokoroTTSInfoCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.blue)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text("Kokoro Neural TTS")
                    .font(.headline)

                Text("High-quality neural text-to-speech powered by MLX. Generates natural-sounding speech on Apple Silicon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TextInputCard: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text to Synthesize")
                .font(.headline)

            TextEditor(text: $text)
                .font(.body)
                .frame(height: 120)
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            Text("Enter the text you want to convert to speech")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct VoiceParametersCard: View {
    @Binding var speed: Double
    @Binding var pitch: Double
    @Binding var volume: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Parameters")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Speed: \(String(format: "%.1fx", speed))")
                    Spacer()
                    Button("Reset") { speed = 1.0 }
                        .font(.caption)
                }
                Slider(value: $speed, in: 0.5...2.0, step: 0.1)
                Text("Adjust speech speed (0.5x = slower, 2.0x = faster)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pitch: \(String(format: "%.1fx", pitch))")
                    Spacer()
                    Button("Reset") { pitch = 1.0 }
                        .font(.caption)
                }
                Slider(value: $pitch, in: 0.5...2.0, step: 0.1)
                Text("Adjust voice pitch (0.5x = lower, 2.0x = higher)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume: \(Int(volume * 100))%")
                    Spacer()
                    Button("Reset") { volume = 1.0 }
                        .font(.caption)
                }
                Slider(value: $volume, in: 0.0...1.0, step: 0.05)
                Text("Adjust playback volume")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct NativeTTSInfoCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                Text("Native macOS Text-to-Speech")
                    .font(.headline)

                Text("Uses your Mac's built-in speech synthesis - no setup required! Choose from all installed system voices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SetupStep: View {
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
                    .foregroundColor(.blue)
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
                        .foregroundColor(showCopied ? .green : .blue)
                }
                .buttonStyle(.borderless)
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - MLX-Audio Integration Helpers
struct TTSConfiguration {
    let text: String
    let voice: String
    let speed: Float
    let pitch: Float
}

class MLXTextToSpeech {
    let modelName: String

    init(modelName: String) async throws {
        self.modelName = modelName
        // Initialize model here
    }

    func synthesize(configuration: TTSConfiguration) async throws -> Data {
        // This is a placeholder - actual implementation would use MLX-Audio
        // For now, we'll return empty data as this requires the actual MLX-Audio integration
        throw NSError(domain: "MLXTTSPlugin", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "MLX-Audio integration in progress. Please install and configure MLX-Audio models."
        ])
    }
}

// MARK: - DiffusionKit Integration Helpers (for Image Gen Plugin)
struct DiffusionConfiguration {
    let prompt: String
    let negativePrompt: String?
    let guidanceScale: Float
    let numInferenceSteps: Int
    let width: Int
    let height: Int
    let seed: UInt32?
}

class StableDiffusionPipeline {
    let modelName: String

    init(modelName: String) async throws {
        self.modelName = modelName
        // Initialize model here
    }

    func generate(configuration: DiffusionConfiguration) async throws -> NSImage {
        // This is a placeholder - actual implementation would use DiffusionKit
        throw NSError(domain: "MLXImageGenPlugin", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "DiffusionKit integration in progress. Please install and configure Stable Diffusion models."
        ])
    }
}
