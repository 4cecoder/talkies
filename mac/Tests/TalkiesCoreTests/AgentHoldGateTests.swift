import XCTest
@testable import TalkiesCore

/// The agent key does nothing until the hold qualifies; shortcuts and taps are dropped.
final class AgentHoldGateTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
    private func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    func testQualifiedHoldStartsThenFinishesCapture() {
        var gate = AgentHoldGate(minimumHold: 0.35)
        XCTAssertEqual(gate.keyDown(isSolePress: true, at: at(0)), .none, "Pressing the key has no side effect")
        XCTAssertEqual(gate.tick(at: at(0.2)), .none, "Not qualified yet")
        XCTAssertEqual(gate.tick(at: at(0.35)), .startCapture)
        XCTAssertEqual(gate.state, .capturing)
        XCTAssertEqual(gate.tick(at: at(0.6)), .none, "Starts only once")
        XCTAssertEqual(gate.keyUp(at: at(2)), .finishCapture)
        XCTAssertEqual(gate.state, .idle)
    }

    func testTapNeverStartsAnything() {
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: true, at: at(0))
        XCTAssertEqual(gate.keyUp(at: at(0.1)), .none)
        XCTAssertEqual(gate.tick(at: at(0.36)), .none, "A late timer from the tap does nothing")
    }

    func testShortcutKeyBeforeQualifyingIsDroppedSilently() {
        // Right ⌘V while typing: V arrives before the hold qualifies.
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: true, at: at(0))
        XCTAssertEqual(gate.interrupted(), .none, "Nothing was started, so nothing to undo")
        XCTAssertEqual(gate.tick(at: at(1)), .none, "A rejected press never starts a capture")
        XCTAssertEqual(gate.keyUp(at: at(1.2)), .none)
        XCTAssertEqual(gate.state, .idle)
    }

    func testMouseDownDuringHoldCancelsEvenPastTheThreshold() {
        // ⌘-click held past the threshold before the timer runs.
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: true, at: at(0))
        _ = gate.interrupted()
        XCTAssertEqual(gate.tick(at: at(5)), .none)
    }

    func testShortcutAfterCaptureStartedDiscardsIt() {
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: true, at: at(0))
        XCTAssertEqual(gate.tick(at: at(0.4)), .startCapture)
        XCTAssertEqual(gate.interrupted(), .discardCapture)
        XCTAssertEqual(gate.interrupted(), .none, "Discarded once")
        XCTAssertEqual(gate.keyUp(at: at(1)), .none, "Nothing left to finish")
    }

    func testPressWithAnotherModifierAlreadyHeldIsIgnored() {
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: false, at: at(0))
        XCTAssertEqual(gate.state, .rejected)
        XCTAssertEqual(gate.tick(at: at(1)), .none)
        XCTAssertEqual(gate.keyUp(at: at(1.1)), .none)
    }

    func testStaleTimerFromEarlierPressDoesNotStartTheNextOneEarly() {
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: true, at: at(0))
        _ = gate.keyUp(at: at(0.1))
        _ = gate.keyDown(isSolePress: true, at: at(0.2))
        XCTAssertEqual(gate.tick(at: at(0.36)), .none, "First press's timer: second press held only 0.16 s")
        XCTAssertEqual(gate.tick(at: at(0.56)), .startCapture)
    }

    func testCaptureUnavailableLeavesNothingToFinish() {
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: true, at: at(0))
        _ = gate.tick(at: at(0.4))
        gate.captureUnavailable() // for example, dictation was already recording
        XCTAssertEqual(gate.keyUp(at: at(1)), .none)
        XCTAssertEqual(gate.state, .idle)
    }

    func testRepeatedKeyDownWhileHeldIsIgnored() {
        var gate = AgentHoldGate(minimumHold: 0.35)
        _ = gate.keyDown(isSolePress: true, at: at(0))
        _ = gate.keyDown(isSolePress: true, at: at(0.3))
        XCTAssertEqual(gate.tick(at: at(0.35)), .startCapture, "The hold is timed from the first press")
    }
}
