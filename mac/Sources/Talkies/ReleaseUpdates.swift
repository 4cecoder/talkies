import Foundation

struct ReleaseUpdate: Sendable {
    let version: String
    let url: URL
}

enum ReleaseUpdates {
    static let latestURL = URL(string: "https://github.com/4cecoder/talkies/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/4cecoder/talkies/releases/latest")!

    static func check(currentVersion: String) async throws -> ReleaseUpdate? {
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Talkies-macOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              let metadata = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              metadata["draft"] as? Bool != true,
              metadata["prerelease"] as? Bool != true,
              let tag = metadata["tag_name"] as? String,
              let page = metadata["html_url"] as? String,
              let url = URL(string: page), url.host == "github.com" else {
            throw URLError(.badServerResponse)
        }
        let version = String(tag.drop(while: { $0 == "v" }))
        return compare(version, currentVersion) > 0 ? ReleaseUpdate(version: version, url: url) : nil
    }

    static func compare(_ lhs: String, _ rhs: String) -> Int {
        let a = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let result = (index < a.count ? a[index] : 0).compare(index < b.count ? b[index] : 0)
            if result != 0 { return result }
        }
        return 0
    }
}

private extension Int {
    func compare(_ other: Int) -> Int { self == other ? 0 : (self < other ? -1 : 1) }
}
