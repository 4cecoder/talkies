import XCTest
@testable import TalkiesCore

final class MenuBarIconStateTests: XCTestCase {
    func testActivitiesHaveDistinctSymbolsAndAccessibleLabels() {
        let states: [MenuBarIconState] = [
            .init(isRecording: false, activity: .ready),
            .init(isRecording: false, activity: .loading),
            .init(isRecording: false, activity: .recording),
            .init(isRecording: false, activity: .recognizing),
            .init(isRecording: false, activity: .polishing),
            .init(isRecording: false, activity: .inserting),
            .init(isRecording: false, activity: .completed),
            .init(isRecording: false, activity: .needsAttention)
        ]

        XCTAssertEqual(Set(states.map(\.symbolName)).count, states.count)
        XCTAssertEqual(Set(states.map(\.accessibilityLabel)).count, states.count)
        XCTAssertEqual(states[0].symbolName, "waveform")
        XCTAssertEqual(states[1].symbolName, "arrow.down.circle")
        XCTAssertEqual(states[1].accessibilityLabel, "Talkies is loading the speech model")
    }

    func testLiveRecordingOverridesOtherActivity() {
        let state = MenuBarIconState(isRecording: true, activity: .recognizing)

        XCTAssertEqual(state, .recording)
        XCTAssertEqual(state.symbolName, "waveform.circle.fill")
        XCTAssertEqual(state.accessibilityLabel, "Talkies is recording")
    }
}
