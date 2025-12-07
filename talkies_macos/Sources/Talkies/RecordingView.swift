import SwiftUI
import AVFoundation

struct RecordingView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var selectedModel = "medium"
    @State private var selectedLanguage = "auto"
    @State private var showingSaveAlert = false
    @State private var showingError = false
    
    private let models = ["tiny", "base", "small", "medium", "large", "large-v3-turbo"]
    private let languages = ["auto", "en", "es", "fr", "de", "it", "pt", "ru", "ja", "zh", "ko", "ar", "hi"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Live Recording")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Real-time transcription with MLX Whisper")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !transcriptionService.segments.isEmpty {
                    Button("Export") {
                        showingSaveAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
            
            HSplitView {
                // Left panel - Controls
                VStack(spacing: 24) {
                    // Settings Card
                    ModelSettingsCard(
                        selectedModel: $selectedModel,
                        selectedLanguage: $selectedLanguage,
                        models: models,
                        languages: languages
                    )
                    
                    // Recording Controls
                    RecordingControlsView()
                    
                    // Audio Level Meter
                    AudioLevelView(audioLevel: audioRecorder.audioLevel)
                    
                    Spacer()
                }
                .padding(30)
                .frame(minWidth: 350)
                .background(Color(NSColor.controlBackgroundColor))
                
                // Right panel - Live Transcript
                VStack(spacing: 0) {
                    // Transcript Header
                    HStack {
                        Text("Live Transcript")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if transcriptionService.isTranscribing {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(transcriptionService.isTranscribing ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: transcriptionService.isTranscribing)
                                
                                Text("Transcribing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    Divider()
                    
                    // Transcript Content
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if transcriptionService.segments.isEmpty {
                                EmptyStateView()
                            } else {
                                ForEach(transcriptionService.segments) { segment in
                                    TranscriptSegmentView(segment: segment)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                }
                .frame(minWidth: 500)
            }
        }
        .alert("Export Transcript", isPresented: $showingSaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("VTT") {
                saveTranscript(format: .vtt)
            }
            Button("SRT") {
                saveTranscript(format: .srt)
            }
            Button("TXT") {
                saveTranscript(format: .txt)
            }
        } message: {
            Text("Choose export format:")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(transcriptionService.error ?? "An unknown error occurred")
        }
        .onChange(of: transcriptionService.error) { _, error in
            if error != nil {
                showingError = true
            }
        }
    }
    
    private func saveTranscript(format: ExportFormat) {
        let content: String
        let fileName: String
        
        switch format {
        case .vtt:
            content = transcriptionService.exportVTT()
            fileName = "talkies_\(Date().timeIntervalSince1970).vtt"
        case .srt:
            content = transcriptionService.exportSRT()
            fileName = "talkies_\(Date().timeIntervalSince1970).srt"
        case .txt:
            content = transcriptionService.exportTXT()
            fileName = "talkies_\(Date().timeIntervalSince1970).txt"
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = fileName
        
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

enum ExportFormat {
    case vtt, srt, txt
}

struct ModelSettingsCard: View {
    @Binding var selectedModel: String
    @Binding var selectedLanguage: String
    let models: [String]
    let languages: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Model")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Picker("Model", selection: $selectedModel) {
                    ForEach(models, id: \.self) { model in
                        Text(model.capitalized).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Language")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Picker("Language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { language in
                        Text(language.uppercased()).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

struct RecordingControlsView: View {
    @EnvironmentObject var audioRecorder: AudioRecorder
    @EnvironmentObject var transcriptionService: TranscriptionService
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main Record Button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.orange : Color.red)
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .onAppear {
                if audioRecorder.isRecording {
                    isAnimating = true
                }
            }
            .onChange(of: audioRecorder.isRecording) { _, isRecording in
                isAnimating = isRecording
            }
            
            Text(audioRecorder.isRecording ? "Stop Recording" : "Start Recording")
                .font(.headline)
                .foregroundColor(.primary)
            
            if audioRecorder.isRecording {
                Text(audioRecorder.formattedDuration)
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
            transcriptionService.stopTranscription()
        } else {
            audioRecorder.startRecording()
            transcriptionService.startTranscription()
        }
    }
}

struct AudioLevelView: View {
    let audioLevel: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio Level")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: index, level: audioLevel))
                            .frame(width: (geometry.size.width - 38) / 20, height: 8)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 4)
    }
    
    private func barColor(for index: Int, level: Float) -> Color {
        let threshold = Float(index) / 20.0
        
        if level > threshold {
            if level > 0.8 {
                return .red
            } else if level > 0.6 {
                return .orange
            } else {
                return .green
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
}

struct TranscriptSegmentView: View {
    let segment: TranscriptSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(segment.timestamp)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text(segment.text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Ready to Transcribe")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Click 'Start Recording' and begin speaking")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Your transcription will appear here in real-time")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }
}

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
            .environmentObject(AudioRecorder())
            .environmentObject(TranscriptionService())
            .frame(width: 1200, height: 800)
    }
}