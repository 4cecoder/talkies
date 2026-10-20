@preconcurrency import AVFoundation
import Combine
import Foundation

private final class AudioFileSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?

    init(file: AVAudioFile) { self.file = file }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        try? file?.write(from: buffer)
    }

    func close() {
        lock.lock()
        file = nil
        lock.unlock()
    }
}

private final class AudioMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var history = Array(repeating: Float.zero, count: 48)
    private var nextIndex = 0
    private var count = 0

    func append(_ value: Float) {
        lock.lock()
        history[nextIndex] = value
        nextIndex = (nextIndex + 1) % history.count
        count = min(count + 1, history.count)
        lock.unlock()
    }

    func snapshot() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        let start = (nextIndex - count + history.count) % history.count
        let active = (0..<count).map { history[(start + $0) % history.count] }
        return Array(repeating: 0, count: history.count - active.count) + active
    }
}

@MainActor
final class AudioCapture: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var waveform = Array(repeating: Float.zero, count: 48)
    @Published private(set) var errorMessage: String?

    private var engine: AVAudioEngine?
    private var sink: AudioFileSink?
    private var recordingURL: URL?
    private let meter = AudioMeter()
    private var timer: Timer?
    private var startedAt: Date?

    func start() async throws {
        errorMessage = nil
        let authorized = await requestPermissionIfNeeded()
        guard authorized else { throw AudioCaptureError.microphonePermission }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.noInput
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Talkies-Monterey", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("recording-\(UUID().uuidString).wav")
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        let sink = AudioFileSink(file: file)
        let meter = self.meter

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            sink.append(buffer)
            guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
                meter.append(0)
                return
            }
            var power: Float = 0
            for index in 0..<Int(buffer.frameLength) {
                power += channel[index] * channel[index]
            }
            let rms = sqrt(power / Float(buffer.frameLength))
            meter.append(min(1, max(0.06, rms * 8)))
        }

        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            sink.close()
            try? FileManager.default.removeItem(at: url)
            throw error
        }

        self.engine = engine
        self.sink = sink
        recordingURL = url
        startedAt = Date()
        elapsed = 0
        waveform = Array(repeating: 0, count: waveform.count)
        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.waveform = self.meter.snapshot()
                self.elapsed = Date().timeIntervalSince(self.startedAt ?? Date())
            }
        }
    }

    func stop() throws -> URL {
        guard let engine, isRecording else { throw AudioCaptureError.notRecording }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        sink?.close()
        self.engine = nil
        sink = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        waveform = meter.snapshot()
        guard let url = recordingURL else {
            throw AudioCaptureError.recordingUnavailable
        }
        recordingURL = nil
        return url
    }

    private func requestPermissionIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
        default:
            return false
        }
    }

}

private enum AudioCaptureError: LocalizedError {
    case microphonePermission
    case noInput
    case notRecording
    case recordingUnavailable

    var errorDescription: String? {
        switch self {
        case .microphonePermission: return "Allow microphone access for Talkies in System Settings, then try again."
        case .noInput: return "No microphone input is available."
        case .notRecording: return "Talkies is not recording."
        case .recordingUnavailable: return "The recording file could not be found."
        }
    }
}
