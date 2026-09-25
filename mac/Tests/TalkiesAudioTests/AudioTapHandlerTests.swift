import AVFoundation
import XCTest
@testable import TalkiesAudio

final class AudioTapHandlerTests: XCTestCase {
    func testSilenceProducesZeroAudioLevel() throws {
        let handler = AudioTapHandler(audioFile: nil)
        let buffer = try makeBuffer(samples: [0, 0, 0, 0])

        handler.handleTap(buffer: buffer, time: AVAudioTime(hostTime: 0))

        XCTAssertEqual(handler.level, 0, accuracy: 0.0001)
    }

    func testFullScaleSignalProducesMaximumAudioLevel() throws {
        let handler = AudioTapHandler(audioFile: nil)
        let buffer = try makeBuffer(samples: [1, -1, 1, -1])

        handler.handleTap(buffer: buffer, time: AVAudioTime(hostTime: 0))

        XCTAssertEqual(handler.level, 1, accuracy: 0.0001)
    }

    func testWaveformHistoryPreservesRecentEnvelopeInOrder() throws {
        let handler = AudioTapHandler(audioFile: nil)
        handler.handleTap(buffer: try makeBuffer(samples: [0, 0, 0, 0]), time: AVAudioTime(hostTime: 0))
        handler.handleTap(buffer: try makeBuffer(samples: [0.5, 0.5, 0.5, 0.5]), time: AVAudioTime(hostTime: 0))
        handler.handleTap(buffer: try makeBuffer(samples: [1, 1, 1, 1]), time: AVAudioTime(hostTime: 0))

        let history = handler.waveformHistory(count: 4)

        XCTAssertEqual(history.count, 4)
        XCTAssertEqual(history[0], 0, accuracy: 0.0001)
        XCTAssertEqual(history[1], 0, accuracy: 0.0001)
        XCTAssertLessThan(history[2], history[3])
        XCTAssertEqual(history[3], 1, accuracy: 0.0001)
    }

    func testWaveformHistoryIsBoundedAndCanBeReset() throws {
        let handler = AudioTapHandler(audioFile: nil)
        for _ in 0..<520 {
            handler.handleTap(buffer: try makeBuffer(samples: [1]), time: AVAudioTime(hostTime: 0))
        }

        let history = handler.waveformHistory(count: 512)
        XCTAssertEqual(history.count, 512)
        XCTAssertTrue(history.allSatisfy { $0 == 1 })

        handler.resetWaveformHistory()
        XCTAssertEqual(handler.waveformHistory(count: 4), [0, 0, 0, 0])
        XCTAssertEqual(handler.level, 0, accuracy: 0.0001)
    }

    func testEmptyBufferResetsAudioLevelToZero() throws {
        let handler = AudioTapHandler(audioFile: nil)
        handler.level = 0.75
        let buffer = try makeBuffer(samples: [])

        handler.handleTap(buffer: buffer, time: AVAudioTime(hostTime: 0))

        XCTAssertEqual(handler.level, 0, accuracy: 0.0001)
        XCTAssertEqual(handler.waveformHistory(count: 1), [0])
    }

    func testUnsupportedSampleFormatResetsAudioLevelToZero() throws {
        let handler = AudioTapHandler(audioFile: nil)
        handler.level = 0.75
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )
        )
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4))
        buffer.frameLength = 4

        handler.handleTap(buffer: buffer, time: AVAudioTime(hostTime: 0))

        XCTAssertEqual(handler.level, 0, accuracy: 0.0001)
    }

    private func makeBuffer(samples: [Float]) throws -> AVAudioPCMBuffer {
        let format = try XCTUnwrap(
            AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )
        )
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(samples.count, 1)))
        )
        buffer.frameLength = AVAudioFrameCount(samples.count)

        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        for (index, sample) in samples.enumerated() {
            channel[index] = sample
        }

        return buffer
    }
}
