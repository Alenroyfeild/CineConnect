import Foundation

/// A separate `URLProtocol` stub from `StubURLProtocol` (Phase 4), even
/// though the implementation is nearly identical - both hold shared
/// *static* state, and `RemoteServiceTests` and `ImageLoaderTests` are
/// different `@Suite`s. Swift Testing's `.serialized` trait only
/// serializes tests *within* a suite, not across suites - the first
/// version of this file reused `StubURLProtocol` directly and both suites
/// intermittently failed from racing each other's shared handler/request
/// log. A second, independent stub type gives each suite its own static
/// state with no cross-suite interference, which is simpler than building
/// a cross-suite locking mechanism for what's fundamentally a test-only
/// convenience type.
final class StubImageURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (statusCode: Int, headers: [String: String], data: Data))?
    nonisolated(unsafe) static var receivedRequests: [URLRequest] = []

    static func reset() {
        requestHandler = nil
        receivedRequests = []
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubImageURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubImageURLProtocol.receivedRequests.append(request)

        guard let handler = StubImageURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (statusCode, headers, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
