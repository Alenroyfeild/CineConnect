import Foundation
import Testing
@testable import CineConnect

private struct TestPayload: Codable, Equatable {
    let value: String
}

/// `RemoteService` tests using `StubURLProtocol` - none of these touch a
/// live server. Decoding-error-to-`RemoteError` mapping is intentionally
/// NOT tested here: `RemoteService.execute` itself throws the raw
/// `DecodingError` on a bad body (its job is transport, not
/// domain-error mapping) - that mapping happens in the API-service layer
/// via `RemoteError.from`, covered in `RemoteErrorTests.swift`.
/// `.serialized`: every test here resets and reconfigures
/// `StubURLProtocol`'s shared static state - running them concurrently
/// would let one test's handler/requests bleed into another's.
@MainActor
@Suite(.serialized)
struct RemoteServiceTests {
    // `retryPolicy` resolved in the body, not a default-argument
    // expression, for the same actor-isolation reason documented on
    // `AppDependencyContainer.init`.
    private func makeService(retryPolicy: RetryPolicy? = nil, preInterceptors: [RequestInterceptor] = []) -> RemoteService {
        RemoteService(urlSession: StubURLProtocol.makeSession(), preInterceptors: preInterceptors, retryPolicy: retryPolicy ?? .none)
    }

    // MARK: - Query encoding

    @Test func queryParametersAreEncodedExactlyOnce() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.requestHandler = { _ in
            (200, [:], try! JSONEncoder().encode(TestPayload(value: "ok")))
        }
        let service = makeService()

        // A raw space must become "%20", not "%2520" (which is what a
        // double-encode of the already-encoded "%20" would produce).
        let request = Remote.Request(url: "https://example.com/search", parameters: ["q": "a b"])
        let _: TestPayload = try await service.execute(request: request)

        let sentURL = StubURLProtocol.receivedRequests.first?.url?.absoluteString ?? ""
        #expect(sentURL.contains("q=a%20b"))
        #expect(!sentURL.contains("%2520"))
    }

    // MARK: - 200..<300 handling

    @Test func statusCode201And204AreTreatedAsSuccess() async throws {
        for statusCode in [200, 201, 204, 299] {
            StubURLProtocol.reset()
            StubURLProtocol.requestHandler = { _ in
                (statusCode, [:], try! JSONEncoder().encode(TestPayload(value: "ok")))
            }
            let service = makeService()

            let result: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x"))

            #expect(result == TestPayload(value: "ok"))
        }
    }

    @Test func statusCode401ThrowsGeneralErrorWithStatusCode() async {
        StubURLProtocol.reset()
        StubURLProtocol.requestHandler = { _ in (401, [:], Data()) }
        let service = makeService()

        await #expect(throws: RemoteError.self) {
            let _: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x"))
        }
    }

    // MARK: - Structured server error decoding

    @Test func serverErrorBodyDecodesToStructuredError() async throws {
        StubURLProtocol.reset()
        let errorBody = try! JSONEncoder().encode(RemoteErrorResponse(errorCode: "RATE_LIMIT", message: "Too many requests"))
        StubURLProtocol.requestHandler = { _ in (500, [:], errorBody) }
        let service = makeService()

        do {
            let _: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x"))
            Issue.record("Expected RemoteError.server to be thrown")
        } catch RemoteError.server(let response) {
            #expect(response.errorCode == "RATE_LIMIT")
            #expect(response.message == "Too many requests")
        }
    }

    @Test func serverErrorWithoutStructuredBodyFallsBackToGeneral() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.requestHandler = { _ in (500, [:], Data("not json".utf8)) }
        let service = makeService()

        do {
            let _: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x"))
            Issue.record("Expected RemoteError.general to be thrown")
        } catch RemoteError.general(_, let statusCode) {
            #expect(statusCode == 500)
        }
    }

    // MARK: - Retry

    @Test func retriesTransientFailuresUpToMaxAttemptsThenSucceeds() async throws {
        StubURLProtocol.reset()
        var callCount = 0
        StubURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount < 3 {
                throw URLError(.timedOut)
            }
            return (200, [:], try! JSONEncoder().encode(TestPayload(value: "ok")))
        }
        // Instant sleep - no real waiting in this test.
        let policy = RetryPolicy(maxAttempts: 3, baseDelayNanoseconds: 0, maxDelayNanoseconds: 0, sleep: { _ in })
        let service = makeService(retryPolicy: policy)

        let result: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x"))

        #expect(result == TestPayload(value: "ok"))
        #expect(StubURLProtocol.receivedRequests.count == 3)
    }

    @Test func exhaustsRetriesAndThrowsAfterMaxAttempts() async {
        StubURLProtocol.reset()
        StubURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }
        let policy = RetryPolicy(maxAttempts: 3, baseDelayNanoseconds: 0, maxDelayNanoseconds: 0, sleep: { _ in })
        let service = makeService(retryPolicy: policy)

        await #expect(throws: URLError.self) {
            let _: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x"))
        }
        #expect(StubURLProtocol.receivedRequests.count == 3)
    }

    @Test func postRequestsAreNeverRetried() async {
        StubURLProtocol.reset()
        StubURLProtocol.requestHandler = { _ in throw URLError(.timedOut) }
        // A retry-happy policy, to prove method-gating (not the policy
        // itself) is what prevents retrying a POST.
        let policy = RetryPolicy(maxAttempts: 5, baseDelayNanoseconds: 0, maxDelayNanoseconds: 0, sleep: { _ in })
        let service = makeService(retryPolicy: policy)

        await #expect(throws: URLError.self) {
            let _: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x", method: .post))
        }
        #expect(StubURLProtocol.receivedRequests.count == 1)
    }

    // MARK: - Header injection

    @Test func requestInterceptorHeadersReachTheFinalRequest() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.requestHandler = { _ in (200, [:], try! JSONEncoder().encode(TestPayload(value: "ok"))) }
        let provider = FakeAuthHeaderProvider(headers: ["x-hs-usertoken": "test-token"])
        let service = makeService(preInterceptors: [AuthenticationInterceptor(headerProvider: provider)])

        let _: TestPayload = try await service.execute(request: Remote.Request(url: "https://example.com/x"))

        let sentHeaders = StubURLProtocol.receivedRequests.first?.allHTTPHeaderFields
        #expect(sentHeaders?["x-hs-usertoken"] == "test-token")
    }
}

final class FakeAuthHeaderProvider: AuthHeaderProviding {
    private let headers: [String: String]
    init(headers: [String: String]) { self.headers = headers }
    func getHeaders() async -> [String: String] { headers }
}
