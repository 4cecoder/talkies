import XCTest
@testable import Talkies

final class ReleaseUpdatesTests: XCTestCase {
    func testComparesNumericVersionComponents() {
        XCTAssertEqual(ReleaseUpdates.compare("0.1.10", "0.1.9"), 1)
        XCTAssertEqual(ReleaseUpdates.compare("1.0.0", "1.0.1"), -1)
        XCTAssertEqual(ReleaseUpdates.compare("1.2", "1.2.0"), 0)
    }
}
