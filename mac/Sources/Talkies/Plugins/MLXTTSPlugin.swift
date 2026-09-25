import SwiftUI
import Foundation
import AVFoundation

// MARK: - MLX Text-to-Speech Plugin
// NOTE: KokoroSwift dependency temporarily disabled due to Swift 6.2 compatibility bug in MisakiSwift
// This version only supports Native macOS TTS
class MLXTTSPlugin: TalkiesPlugin, ObservableObject {
    let id = "mlx-tts"
    let name = "Text-to-Speech"
    let description = "Convert text to speech using Native macOS TTS"
    let icon = "speaker.wave.3"

    enum TTSEngine: String, CaseIterable {
        case native = "Native macOS"
        // case kokoro = "Kokoro TTS" // DISABLED: MisakiSwift has Swift 6.2 bug
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

        await loadNativeVoices()
        await MainActor.run {
            self.pluginStatus = .ready
        }
    }

    private func loadNativeVoices() async {
        let voices = AVSpeechSynthesisVoice.speechVoices().map(\.name)

        let savedVoice = UserDefaults.standard.string(forKey: "mlx-tts.selectedVoice")

        self.availableVoices = voices
        if let savedVoice, voices.contains(savedVoice) {
            self.selectedVoice = savedVoice
        } else if !voices.isEmpty {
            self.selectedVoice = voices[0]
        }
    }

    func synthesizeSpeech(text: String) async throws -> URL {
        isSynthesizing = true
        lastError = nil
        return try await synthesizeNative(text: text)
    }

    private func synthesizeNative(text: String) async throws -> URL {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.name == selectedVoice }) {
            utterance.voice = voice
        }
        utterance.rate = Float(min(max(speed, 0.5), 2.0)) * AVSpeechUtteranceDefaultSpeechRate

        let filename = "talkies-tts-\(UUID().uuidString).caf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        return try await withCheckedThrowingContinuation { continuation in
            var audioFile: AVAudioFile?
            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
                if pcmBuffer.frameLength == 0 {
                    self.generatedAudioPath = fileURL.path
                    self.isSynthesizing = false
                    continuation.resume(returning: fileURL)
                    return
                }

                do {
                    if audioFile == nil {
                        audioFile = try AVAudioFile(
                            forWriting: fileURL,
                            settings: pcmBuffer.format.settings
                        )
                    }
                    try audioFile?.write(from: pcmBuffer)
                } catch {
                    self.isSynthesizing = false
                    continuation.resume(throwing: error)
                }
            }
        }
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

                // Info about native TTS
                NativeTTSInfoCard()

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
        case .checking: return "Checking TTS status..."
        case .notInstalled: return "TTS not available"
        case .ready: return "Ready"
        case .error(let msg): return "Error: \(msg)"
        }
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
