import Foundation
import Testing
@testable import CineConnect

/// `RemoteError.from(_:)` is what the API services use to map whatever
/// `RemoteService.execute` throws into a `RemoteError` - this is where
/// decoding-error-to-`.parsingError` mapping actually happens (not inside
/// `RemoteService` itself, see `RemoteServiceTests.swift`'s header comment).
@Suite
struct RemoteErrorTests {
    private struct Unmapped: Decodable { let value: String }

    @Test func decodingErrorMapsToParsingError() {
        let decodingError: Error
        do {
            _ = try JSONDecoder().decode(Unmapped.self, from: Data("not json".utf8))
            Issue.record("Expected decode to fail")
            return
        } catch {
            decodingError = error
        }

        let mapped = RemoteError.from(decodingError)

        guard case .parsingError = mapped else {
            Issue.record("Expected .parsingError, got \(mapped)")
            return
        }
    }

    @Test func urlErrorMapsToNetworkError() {
        let mapped = RemoteError.from(URLError(.timedOut))
        guard case .network(let underlying) = mapped else {
            Issue.record("Expected .network, got \(mapped)")
            return
        }
        #expect((underlying as? URLError)?.code == .timedOut)
    }

    @Test func remoteErrorPassesThroughUnchanged() {
        let original = RemoteError.general(status: "Not Found", statusCode: 404)
        let mapped = RemoteError.from(original)
        guard case .general(_, let statusCode) = mapped else {
            Issue.record("Expected .general to pass through, got \(mapped)")
            return
        }
        #expect(statusCode == 404)
    }

    @Test func unrecognizedErrorMapsToUnknown() {
        struct SomeOtherError: Error {}
        let mapped = RemoteError.from(SomeOtherError())
        guard case .unknown = mapped else {
            Issue.record("Expected .unknown, got \(mapped)")
            return
        }
    }
}
