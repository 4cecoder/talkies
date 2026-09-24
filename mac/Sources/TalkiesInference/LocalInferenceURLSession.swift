import Foundation

/// URLSession for local inference APIs. Redirects are rejected so a loopback
/// server cannot forward transcript content to a remote host.
public enum LocalInferenceURLSession {
    public static let shared = URLSession(
        configuration: .ephemeral,
        delegate: LocalInferenceRedirectBlocker(),
        delegateQueue: nil
    )
}

private final class LocalInferenceRedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
