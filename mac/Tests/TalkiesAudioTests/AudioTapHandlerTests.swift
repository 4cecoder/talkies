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

    func testEmptyBufferResetsAudioLevelToZero() throws {
        let handler = AudioTapHandler(audioFile: nil)
        handler.level = 0.75
        let buffer = try makeBuffer(samples: [])

        handler.handleTap(buffer: buffer, time: AVAudioTime(hostTime: 0))

        XCTAssertEqual(handler.level, 0, accuracy: 0.0001)
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
