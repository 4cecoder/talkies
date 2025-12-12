import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // Glassmorphic background
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with tabs - Raycast style
                HStack(spacing: 12) {
                    TabButton(title: "Record", icon: "mic.fill", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Transcript", icon: "doc.text.fill", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "Settings", icon: "gearshape.fill", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }

                    Spacer()

                    // Status indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(audioRecorder.isRecording ? Color.red : (transcriptionService.isTranscribing ? Color.orange : Color.green))
                            .frame(width: 6, height: 6)

                        Text(audioRecorder.isRecording ? "Recording" : (transcriptionService.isTranscribing ? "Transcribing..." : transcriptionService.statusMessage))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))

                Divider()
                    .background(Color.white.opacity(0.1))

                // Main content area
                Group {
                    switch selectedTab {
                    case 0:
                        CompactRecordingView()
                    case 1:
                        CompactTranscriptView()
                    case 2:
                        CompactSettingsView()
                    default:
                        CompactRecordingView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 680, height: 600)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// Visual Effect Blur for glassmorphism
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Compact views for Raycast-style UI
struct CompactRecordingView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var selectedModel = "medium"
    @State private var selectedLanguage = "auto"

    init() {
        // Setup callback when recording completes
    }

    var body: some View {
        VStack(spacing: 20) {
            // Recording button
            Button(action: toggleRecording) {
                HStack(spacing: 12) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(audioRecorder.isRecording ? .red : .white)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(audioRecorder.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if audioRecorder.isRecording {
                            Text(audioRecorder.formattedDuration)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Cmd+Shift+Space")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Live transcript
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if transcriptionService.isDownloadingModel {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text("Downloading Whisper model...")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))

                            Text("This only happens once")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else if transcriptionService.isTranscribing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text("Transcribing your audio...")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else if transcriptionService.segments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))

                            Text("Waiting for audio...")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(transcriptionService.segments.suffix(5)) { segment in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(segment.timestamp)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))

                                Text(segment.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            // Transcription will be triggered via callback
        } else {
            // Setup callback to transcribe when recording stops
            audioRecorder.onRecordingComplete = { [weak transcriptionService] audioURL in
                transcriptionService?.setAudioFileURL(audioURL)
            }
            audioRecorder.startRecording()
            transcriptionService.startTranscription()
        }
    }
}

struct CompactTranscriptView: View {
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var showingExport = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with export button
            HStack {
                Text("Full Transcript")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if !transcriptionService.segments.isEmpty {
                    Button("Export") {
                        showingExport = true
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if transcriptionService.segments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))

                            Text("No transcript yet")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    } else {
                        ForEach(transcriptionService.segments) { segment in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(segment.timestamp)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))

                                Text(segment.text)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

struct CompactSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Model")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Text("medium (default)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Backend")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Text("MLX (GPU Accelerated)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Keyboard Shortcut")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Text("⌘⇧Space - Toggle window")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AudioRecorder())
            .environmentObject(TranscriptionService())
            .frame(width: 1200, height: 800)
    }
}