import Foundation

/// Validates that an inference server is running on this machine.
public enum LocalModelEndpoint {
    /// Returns a URL only when its host resolves syntactically to a loopback address.
    /// DNS names other than `localhost` are rejected to avoid sending transcripts remotely.
    public static func url(_ value: String) -> URL? {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              isLoopback(host),
              let url = components.url else {
            return nil
        }
        return url
    }

    private static func isLoopback(_ host: String) -> Bool {
        let unbracketedHost = host.hasPrefix("[") && host.hasSuffix("]")
            ? String(host.dropFirst().dropLast())
            : host
        let normalizedHost = unbracketedHost.hasSuffix(".") ? String(unbracketedHost.dropLast()) : unbracketedHost
        if normalizedHost == "localhost" || normalizedHost == "::1" || normalizedHost == "0:0:0:0:0:0:0:1" {
            return true
        }

        let octets = normalizedHost.split(separator: ".")
        guard octets.count == 4,
              let first = UInt8(octets[0]),
              first == 127,
              octets.dropFirst().allSatisfy({ UInt8($0) != nil }) else {
            return false
        }
        return true
    }
}
