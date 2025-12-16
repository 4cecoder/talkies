import SwiftUI
import AVFoundation
import Combine
import os.lock
import CoreAudio

// Thread-safe handler for audio tap - completely separate from MainActor
final class AudioTapHandler: @unchecked Sendable {
    private var _level: Float = 0.0
    private let lock = OSAllocatedUnfairLock()
    let audioFile: AVAudioFile?

    init(audioFile: AVAudioFile?) {
        self.audioFile = audioFile
    }

    var level: Float {
        get { lock.withLock { _level } }
        set { lock.withLock { _level = newValue } }
    }

    func handleTap(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        // Write buffer to file
        try? audioFile?.write(from: buffer)

        // Calculate audio level
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let normalizedLevel = min(max(20 * log10(rms + 0.0001), -60), 0) / 60

        level = normalizedLevel + 1.0
    }

    // Install tap from a nonisolated context to avoid MainActor closure inference
    nonisolated static func installTap(on inputNode: AVAudioInputNode, format: AVAudioFormat?, handler: AudioTapHandler) {
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            handler.handleTap(buffer: buffer, time: time)
        }
    }
}

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

    // Thread-safe handler for audio tap
    private var tapHandler: AudioTapHandler?

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
    
    func startRecording(deviceID: String? = nil) {
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

            // Set the preferred input device if specified (macOS only)
            #if os(macOS)
            if let deviceID = deviceID {
                setPreferredInputDevice(deviceID: deviceID)
            }
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
            // Use a nonisolated static method to install the tap, avoiding MainActor closure inference
            tapHandler = AudioTapHandler(audioFile: audioFile)
            AudioTapHandler.installTap(on: inputNode, format: inputNode.outputFormat(forBus: 0), handler: tapHandler!)
            
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
        self.tapHandler = nil
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
            Task { @MainActor in
                self.duration += 0.1
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startAudioLevelTimer() {
        guard let handler = tapHandler else { return }
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Read from thread-safe handler and update published property on main thread
            Task { @MainActor in
                self.audioLevel = handler.level
            }
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
    
    #if os(macOS)
    private func setPreferredInputDevice(deviceID: String) {
        // Find all CoreAudio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        ) == noErr else {
            print("      ❌ Failed to get audio devices size")
            return
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        ) == noErr else {
            print("      ❌ Failed to get audio devices")
            return
        }

        // Find matching device by UID
        for audioDeviceID in audioDevices {
            var uidPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var uid: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<CFString>.size)

            let status = AudioObjectGetPropertyData(
                audioDeviceID,
                &uidPropertyAddress,
                0,
                nil,
                &uidSize,
                &uid
            )

            if status == noErr, let uidString = uid?.takeUnretainedValue() as String?, uidString == deviceID {
                print("      ✓ Found device with UID: \(uidString), setting as default input")

                // Set as default input device
                var defaultInputPropertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultInputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )

                var deviceToSet = audioDeviceID
                let setStatus = AudioObjectSetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &defaultInputPropertyAddress,
                    0,
                    nil,
                    UInt32(MemoryLayout<AudioDeviceID>.size),
                    &deviceToSet
                )

                if setStatus == noErr {
                    print("      ✓ Successfully set default input device")
                } else {
                    print("      ❌ Failed to set default input device: \(setStatus)")
                }
                break
            }
        }
    }
    #endif

    deinit {
        // Cleanup will happen automatically when deallocated
    }
}