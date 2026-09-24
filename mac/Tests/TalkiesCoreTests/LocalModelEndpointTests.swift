import XCTest
@testable import TalkiesCore

final class LocalModelEndpointTests: XCTestCase {
    func testAcceptsLocalhostAndLoopbackAddresses() {
        XCTAssertEqual(LocalModelEndpoint.url("http://localhost:11434")?.host, "localhost")
        XCTAssertEqual(LocalModelEndpoint.url("http://localhost.:11434")?.host, "localhost.")
        XCTAssertEqual(LocalModelEndpoint.url("http://127.0.0.1:11434")?.host, "127.0.0.1")
        XCTAssertEqual(LocalModelEndpoint.url("http://127.42.1.9:11434")?.host, "127.42.1.9")
        XCTAssertEqual(LocalModelEndpoint.url("http://[::1]:1234")?.host, "::1")
    }

    func testRejectsRemoteHostsAndUnsupportedSchemes() {
        XCTAssertNil(LocalModelEndpoint.url("https://example.com/api"))
        XCTAssertNil(LocalModelEndpoint.url("http://192.168.1.12:11434"))
        XCTAssertNil(LocalModelEndpoint.url("http://localhost.evil.test"))
        XCTAssertNil(LocalModelEndpoint.url("ftp://localhost:11434"))
    }

    func testRejectsCredentialsInEndpoint() {
        XCTAssertNil(LocalModelEndpoint.url("http://user:password@localhost:11434"))
    }
}
