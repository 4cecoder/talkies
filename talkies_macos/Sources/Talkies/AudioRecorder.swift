import SwiftUI
import AVFoundation
import Combine

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var duration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var hasPermission = false

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var audioFileURL: URL?
    private var timer: Timer?
    private var audioLevelTimer: Timer?

    var onRecordingComplete: ((URL) -> Void)?
    
    override init() {
        super.init()
        requestMicrophonePermission()
    }
    
    func requestMicrophonePermission() {
        #if os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            self.hasPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                }
            }
        default:
            self.hasPermission = false
        }
        #else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.hasPermission = granted
            }
        }
        #endif
    }
    
    func startRecording() {
        print("      AudioRecorder.startRecording() - START")
        guard hasPermission else {
            print("      ❌ No microphone permission")
            requestMicrophonePermission()
            return
        }
        print("      ✓ Has microphone permission")

        do {
            print("      Setting up audio engine...")
            #if !os(macOS)
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif

            audioEngine = AVAudioEngine()
            inputNode = audioEngine?.inputNode

            guard let inputNode = inputNode,
                  let audioEngine = audioEngine else {
                return
            }
            
            // Create temporary file for recording
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            audioFileURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")

            guard let audioURL = audioFileURL else { return }
            audioFile = try AVAudioFile(forWriting: audioURL, settings: inputNode.outputFormat(forBus: 0).settings)
            
            // Install tap directly on input node for recording and level monitoring
            // DO NOT connect to mainMixerNode to avoid feedback loop
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { [weak self] buffer, time in
                guard let self = self,
                      let audioFile = self.audioFile else { return }
                
                // Write buffer to file
                try? audioFile.write(from: buffer)
                
                // Calculate audio level
                let channelData = buffer.floatChannelData![0]
                let channelDataPointer = UnsafeMutablePointer<Float>(channelData)
                let channelDataArray = Array(UnsafeBufferPointer(start: channelDataPointer, count: Int(buffer.frameLength)))
                
                let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
                let normalizedLevel = min(max(20 * log10(rms + 0.0001), -60), 0) / 60
                
                DispatchQueue.main.async {
                    self.audioLevel = normalizedLevel + 1.0
                }
            }
            
            print("      Starting audio engine...")
            try audioEngine.start()
            print("      ✓ Audio engine started")

            isRecording = true
            isPaused = false
            duration = 0
            print("      ✓ State set: isRecording=true, isPaused=false, duration=0")

            print("      Starting timers...")
            startTimer()
            startAudioLevelTimer()
            print("      ✓ Timers started")
            print("      AudioRecorder.startRecording() - SUCCESS")

        } catch {
            print("      ❌ Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard let engine = audioEngine else { return }

        engine.stop()
        inputNode?.removeTap(onBus: 0)

        isRecording = false
        isPaused = false

        stopTimer()
        stopAudioLevelTimer()

        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        #endif

        // Trigger transcription callback if audio file exists
        if let audioURL = audioFileURL {
            onRecordingComplete?(audioURL)
        }

        self.audioEngine = nil
        self.inputNode = nil
        self.audioFile = nil
        self.audioFileURL = nil
    }
    
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        isPaused = true
        stopTimer()
        stopAudioLevelTimer()
        
        audioEngine?.pause()
    }
    
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        isPaused = false
        startTimer()
        startAudioLevelTimer()
        
        try? audioEngine?.start()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.duration += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startAudioLevelTimer() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Audio level is updated in the tap callback
        }
    }
    
    private func stopAudioLevelTimer() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    deinit {
        // Cleanup will happen automatically when deallocated
    }
}