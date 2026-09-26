import XCTest
@testable import TalkiesInference

final class S1MiniModelStoreTests: XCTestCase {
    func testUnhashedLicenseArtifactsMustBePresentAndNonEmpty() {
        XCTAssertFalse(S1MiniModelStore.isNonEmptyUnhashedArtifact(fileSize: nil))
        XCTAssertFalse(S1MiniModelStore.isNonEmptyUnhashedArtifact(fileSize: 0))
        XCTAssertTrue(S1MiniModelStore.isNonEmptyUnhashedArtifact(fileSize: 1))
    }
}
