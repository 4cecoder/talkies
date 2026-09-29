import AppKit
import Combine
import SwiftUI

@main
struct TalkiesMontereyApp: App {
    var body: some Scene {
        WindowGroup {
            DictationWindow()
                .frame(minWidth: 520, minHeight: 500)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

private struct DictationWindow: View {
    @StateObject private var controller = DictationController()
    @AppStorage("cleanup.enabled") private var cleanupEnabled = false
    @State private var isSettingsShown = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 24)
            WaveformView(samples: controller.capture.waveform, isRecording: controller.capture.isRecording, isWorking: controller.isWorking)
                .frame(height: 104)
                .padding(.horizontal, 32)
            Text(controller.capture.isRecording ? controller.elapsedDescription : controller.status)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(controller.capture.isRecording ? Color.green : Color.secondary)
                .padding(.top, 14)
            Spacer(minLength: 20)
            transcriptCard
            Spacer(minLength: 20)
            controls
            if let message = controller.errorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
            }
            footer
        }
        .padding(24)
        .background(LinearGradient(colors: [Color(red: 0.10, green: 0.08, blue: 0.18), Color(red: 0.06, green: 0.06, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .foregroundColor(.white)
        .sheet(isPresented: $isSettingsShown) {
            settings
                .frame(width: 360, height: 220)
                .padding(24)
                .background(Color(red: 0.10, green: 0.08, blue: 0.18))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 25, weight: .medium))
                .foregroundColor(Color(red: 0.72, green: 0.58, blue: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text("Talkies")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("MONTEREY TEST BUILD")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.52))
            }
            Spacer()
            Button(action: { isSettingsShown = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.09), in: Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Settings")
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TRANSCRIPT")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.52))
                Spacer()
                if !controller.transcript.isEmpty {
                    Button(action: controller.copyTranscript) {
                        Label(controller.didCopy ? "Copied" : "Copy", systemImage: controller.didCopy ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(controller.didCopy ? .green : Color(red: 0.78, green: 0.68, blue: 1))
                }
            }
            ScrollView {
                Text(controller.transcript.isEmpty ? "Your words will appear here. Copy is always a deliberate action; Talkies will not replace clipboard contents on its own." : controller.transcript)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(controller.transcript.isEmpty ? .white.opacity(0.42) : .white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 112)
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var controls: some View {
        VStack(spacing: 0) {
            Button(action: {
                if controller.capture.isRecording {
                    controller.stopRecording(cleanupEnabled: cleanupEnabled)
                } else {
                    controller.startRecording()
                }
            }) {
                Image(systemName: controller.capture.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(controller.capture.isRecording ? Color(red: 0.92, green: 0.26, blue: 0.35) : Color(red: 0.22, green: 0.72, blue: 0.48), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.30), lineWidth: 1))
                    .shadow(color: (controller.capture.isRecording ? Color.red : Color.green).opacity(0.28), radius: 18, y: 5)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(controller.isWorking)
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(controller.capture.isRecording ? "Stop recording" : "Start recording")
            Text(controller.capture.isRecording ? "Stop" : "Record")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
                .padding(.top, 7)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text(cleanupEnabled ? "\(speechBackend) · S1-mini cleanup" : "\(speechBackend) · offline after model setup")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.56))
        }
        .padding(.top, 16)
    }

    private var speechBackend: String {
        #if arch(arm64)
        return "Whisper base · Metal"
        #else
        return "Whisper tiny · CPU"
        #endif
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Local cleanup")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Toggle("Polish transcript with S1-mini", isOn: $cleanupEnabled)
                .toggleStyle(SwitchToggleStyle())
                .foregroundColor(.white)
            Text("For English transcripts. Downloads the verified 462 MiB model once; cleanup then runs locally. Apple silicon uses Metal with a CPU fallback; Intel Macs use CPU. Disable this if you only want local speech recognition.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text("This Monterey build does not send audio or transcripts over the network. Network access is used only to download models on first use.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.46))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WaveformView: View {
    let samples: [Float]
    let isRecording: Bool
    let isWorking: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.07, paused: !isRecording && !isWorking)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    Capsule(style: .continuous)
                        .fill(barColor(index: index))
                        .frame(width: max(2, 288 / CGFloat(max(samples.count, 1)) - 2), height: barHeight(sample: sample, index: index, phase: phase))
                        .animation(.easeOut(duration: 0.12), value: sample)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement()
        .accessibilityLabel(isRecording ? "Recording waveform" : (isWorking ? "Processing waveform" : "Ready waveform"))
    }

    private func barHeight(sample: Float, index: Int, phase: Double) -> CGFloat {
        let position = Double(index) * 0.42
        let idle = 8 + abs(sin(position + phase * 0.22)) * 15
        if isWorking { return CGFloat(9 + abs(sin(Double(index) * 0.56 - phase)) * 30) }
        if isRecording { return CGFloat(max(5, Double(sample) * 78)) }
        return CGFloat(idle)
    }

    private func barColor(index: Int) -> Color {
        if isRecording { return Color(red: 0.40, green: 0.86, blue: 0.67).opacity(0.68 + Double(samples[index]) * 0.32) }
        if isWorking { return Color(red: 0.73, green: 0.58, blue: 1).opacity(0.48 + (Double(index % 6) * 0.08)) }
        return Color(red: 0.69, green: 0.53, blue: 1).opacity(0.42 + (Double(index % 5) * 0.09))
    }
}
