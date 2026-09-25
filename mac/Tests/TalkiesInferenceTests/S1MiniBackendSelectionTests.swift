import XCTest
@testable import TalkiesInference

final class S1MiniBackendSelectionTests: XCTestCase {
    func testPrefersMetalOnAppleSiliconWhenDeviceIsAvailable() {
        XCTAssertEqual(
            S1MiniComputeBackend.preferred(isAppleSilicon: true, metalDeviceAvailable: true),
            .metal
        )
    }

    func testFallsBackToCPUWhenMetalDeviceIsUnavailable() {
        XCTAssertEqual(
            S1MiniComputeBackend.preferred(isAppleSilicon: true, metalDeviceAvailable: false),
            .cpu
        )
    }

    func testUsesCPUOnIntelEvenWhenMetalDeviceExists() {
        XCTAssertEqual(
            S1MiniComputeBackend.preferred(isAppleSilicon: false, metalDeviceAvailable: true),
            .cpu
        )
    }
}
