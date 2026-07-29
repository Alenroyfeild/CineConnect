# Phase 4 — Networking: Bug Fixes, Retry, Injected Interceptor

Status: **Implemented and verified**.

## 1. Previous implementation

`RemoteService` had two live correctness bugs: `HTTPURLResponse.isSuccess`
only accepted exactly HTTP 200 (`statusCode <= 200 && statusCode <= 299`
can only both be true when `statusCode <= 200`), and
`MovieSearchAPIService` percent-encoded its query/referrer values *before*
handing them to `RemoteService`, which then percent-encoded them *again*
via `URLQueryItem`. `Remote.Request` had two private methods
(`getURLRequest(from:)`, `getURL()`) that duplicated `RemoteService`'s own
request-building logic and were never called by anything. No retry policy
existed. `AuthenticationInterceptor` read `AuthManager.shared` directly.
`RemoteErrorResponse` existed but nothing ever tried to decode it.
`BaseAPIService.init(remoteService: RemoteService = .shared)` was the last
scattered singleton-default in the codebase.

## 2. Problem

Any real HTTP success other than exactly 200 (a 201, 204, or 299) was
treated as a failure. A search query containing a character requiring
encoding (e.g. a space) would be sent to Hotstar double-encoded, which
depending on the endpoint's leniency could return wrong or no results. No
transient failure (a dropped connection, a 503) ever got retried. The
interceptor's direct singleton access meant the same untestable pattern
Phase 1 removed from the coordinators still existed in networking.

## 3. Target responsibility

Fix both bugs. Add a bounded, method-gated retry policy. Decode structured
server errors when present. Give `AuthenticationInterceptor` an injectable
credentials-provider seam. Remove the last `RemoteService.shared` default,
threading one instance from `AppDependencyContainer` through
`MoviesCoordinator` to both API services - the same pattern Phase 1
established for `AuthManager`.

## 4. Files introduced

- `Assignment/Services/Remote/RetryPolicy.swift`
- Tests: `AssignmentTests/RemoteServiceTests.swift`,
  `AssignmentTests/RetryPolicyTests.swift`, `AssignmentTests/RemoteErrorTests.swift`,
  `AssignmentTests/Fakes/StubURLProtocol.swift`

## 5. Files modified

- `Assignment/Services/Remote/Request.swift` (`isSuccess` fix; removed the two dead private methods; `HTTPMethod: Equatable`)
- `Assignment/Services/Remote/RemoteError.swift` (`.server(RemoteErrorResponse)` case; `.from(_:)` now passes `RemoteError` through unchanged; `RemoteErrorResponse: Codable`)
- `Assignment/Services/Remote/RemoteService.swift` (retry loop, structured-error decoding, no more `.shared` static)
- `Assignment/Services/Remote/Interceptors.swift` (`AuthHeaderProviding` protocol; `AuthenticationInterceptor` takes an injected provider)
- `Assignment/Services/BaseAPIService.swift` (`remoteService` no longer defaults to `.shared`)
- `Assignment/Services/MovieSearchAPIService.swift` (double-encoding removed; force-unwrapped `URL(string:)!` removed - passes the string directly via `URLConvertable`; simplified `catch` using `RemoteError.from`)
- `Assignment/Services/MovieDetailAPIService.swift` (same `catch` simplification)
- `Assignment/Utils/AuthManager.swift` (`: AuthHeaderProviding` conformance)
- `Assignment/App/AppDependencyContainer.swift` (builds the one `RemoteService`, wires the interceptor)
- `Assignment/Coordinators/AppCoordinator.swift`, `MoviesCoordinator.swift` (thread `remoteService` through, no default)
- `Assignment/Views/MoviesListView.swift`, `MovieDetailView.swift` (preview call sites updated)
- `AssignmentTests/AppCoordinatorTests.swift`, `MoviesCoordinatorTests.swift` (updated call sites)

## 6. Files removed

None.

## 7. Runtime flow before

```
MovieSearchAPIService.searchVideos(query:)
  query.addingPercentEncoding(...)             // encode #1
  RemoteService.execute(...)
    getURL(from:): URLQueryItem(name:value:)   // encode #2 - double-encoded
    urlSession.data(for:)
    !httpResponse.isSuccess                     // only true for status == 200
      throw .general(...)                       // even on a real 201/204 success
    (no retry; failure is final)
AuthenticationInterceptor.intercept
  AuthManager.shared.getHeaders()                // singleton reached directly
```

## 8. Runtime flow after

```
MovieSearchAPIService.searchVideos(query:)
  RemoteService.execute(request: .init(url: baseURL, parameters: [.. raw query ..]))
    getURL(from:): URLQueryItem(name:value:)     // encodes exactly once
    preInterceptors.reduce: AuthenticationInterceptor.intercept
      headerProvider.getHeaders()                 // injected AuthHeaderProviding, not .shared
    loop (only for .get requests):
      performRequest -> urlSession.data(for:)
      isSuccess: (200..<300).contains(statusCode)  // fixed
      on failure: retryPolicy.shouldRetry(error:, attempt:)?
        yes -> waitBeforeRetrying(attempt:) -> retry
        no  -> if body decodes as RemoteErrorResponse -> throw .server(...)
               else -> throw .general(...)
  catch is CancellationError -> rethrow as-is (not mapped through RemoteError.from)
  catch -> RemoteError.from(error)
```

Numbered, with file/type/method/context:

1. **File:** `MoviesCoordinator.swift` · **Method:** `makeMovieRepository()`
   · constructs both API services with the coordinator's injected
   `remoteService`, not a default.
2. **File:** `MovieSearchAPIService.swift` · **Method:** `searchVideos(query:)`
   · builds the raw (unencoded) parameters, calls `remoteService.execute`.
3. **File:** `RemoteService.swift` · **Method:** `execute<T>(request:)` ·
   builds the URL/request, runs pre-interceptors (suspension point: each
   interceptor's `intercept` is `async`), enters the retry loop.
4. **File:** `RemoteService.swift` · **Method:** `performRequest<T>(_:)` ·
   suspension point: `await urlSession.data(for:)` (network I/O). On
   failure, checks `isSuccess`, attempts `RemoteErrorResponse` decoding.
5. **File:** `RetryPolicy.swift` · **Method:** `shouldRetry(error:attempt:)`
   / `waitBeforeRetrying(attempt:)` · synchronous decision, then a
   suspension point at the injected `sleep` closure (real `Task.sleep` in
   production, instant in tests) - cancellation during this suspension
   propagates immediately, no further retries attempted.
6. **File:** `MovieSearchAPIService.swift` · back in `searchVideos`'s
   `catch` · cancellation checked first and rethrown as-is; anything else
   mapped via `RemoteError.from(error)`.

**Tests covering this full chain:** `RemoteServiceTests` (9, transport
level), `RetryPolicyTests` (7, policy decisions in isolation),
`RemoteErrorTests` (4, error-mapping).

## 9. Code excerpts

**Exact production code** (`Assignment/Services/Remote/Request.swift`, the fix):

```swift
extension HTTPURLResponse {
    var isSuccess: Bool { (200..<300).contains(statusCode) }
}
```

**Exact production code** (`Assignment/Services/Remote/RemoteService.swift`,
the retry loop):

```swift
func execute<T: Decodable>(request: Remote.Request) async throws -> T {
    let url = try getURL(from: request)
    let urlRequest = try buildURLRequest(from: request, url: url)
    let interceptedRequest = try await preInterceptors.reduce(urlRequest) { result, interceptor in
        try await interceptor.intercept(result)
    }

    let policy = request.method == .get ? retryPolicy : .none
    var attempt = 0
    while true {
        do {
            return try await performRequest(interceptedRequest)
        } catch {
            guard policy.shouldRetry(error: error, attempt: attempt) else { throw error }
            try await policy.waitBeforeRetrying(attempt: attempt)
            attempt += 1
        }
    }
}
```

**Exact production code** (`Assignment/Services/Remote/Interceptors.swift`,
the injected seam):

```swift
protocol AuthHeaderProviding {
    func getHeaders() -> [String: String]
}

final class AuthenticationInterceptor: RequestInterceptor {
    private let headerProvider: AuthHeaderProviding
    init(headerProvider: AuthHeaderProviding) { self.headerProvider = headerProvider }
    func intercept(_ request: URLRequest) async throws -> URLRequest { ... }
}
```

## 10. Build evidence

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Assignment.xcodeproj -scheme Assignment \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean test
```
Result: **BUILD SUCCEEDED**, **TEST SUCCEEDED**, 0 warnings.

Two warning batches were hit and fixed during this phase, both the same
class of issue as Phase 1/3: default-argument expressions referencing a
`@MainActor`-isolated static/initializer (`RetryPolicy.none` as a default
parameter value; `RetryPolicy(...)` constructed from a non-`@MainActor`
test struct). Fixed the same two ways used before: resolve in the function
body instead of a default-argument expression, and mark the affected test
`@Suite`s `@MainActor`.

One real test-flakiness bug was also found and fixed in-phase: the first
version of `RemoteServiceTests` (not `.serialized`) failed en masse under
Swift Testing's default parallel execution, because `StubURLProtocol`'s
handler/request-log are shared static state - concurrent tests were
resetting and reconfiguring the same statics out from under each other.
Fixed by marking the suite `.serialized`, the same fix Phase 1 already
established for `AppCoordinatorTests` (shared singleton state) - this is
the second time in this migration a test suite touching shared global
state needed serialization, and probably not the last.

## 11. Test evidence

60 tests total (was 40), all passing. New this phase: `RemoteServiceTests`
(9 - query encoding, `200..<300` handling incl. 201/204, structured and
unstructured server errors, retry success/exhaustion, POST never retried,
header injection), `RetryPolicyTests` (7 - pure decision-logic tests, no
networking), `RemoteErrorTests` (4 - `.from(_:)` mapping, including
`RemoteError` passthrough).

## 12. Alternatives

1. **Leave `RemoteService.shared` as the single production instance,
   inject only in tests.** Rejected: this is exactly the pattern Phase 1
   removed from the coordinators (a scattered default that *can* be
   bypassed but usually isn't) - consistency mattered more than the
   modest convenience of a global default.
2. **A generic `APIClient`/`APIRequest<Response>` redesign, matching the
   originally sketched target shape more literally.** Rejected for this
   phase: `RemoteService`/`Remote.Request` already provide typed,
   generic-`execute<T: Decodable>` request execution; a full rename/
   redesign would touch every call site for no behavioral gain over fixing
   the two real bugs and adding retry/injection where they were actually
   missing.
3. **Retry every HTTP method, or none at all.** Rejected in favor of
   method-gating: retrying a `.post` automatically risks repeating a
   non-idempotent side effect. This app has no POST calls today, but the
   gate exists so adding one later doesn't silently inherit retry-on-failure
   behavior it shouldn't have.
4. **A full Keychain-backed `CredentialsStore` for `AuthenticationInterceptor`
   right now.** Rejected: that's Phase 5's actual security work.
   `AuthHeaderProviding` is the minimal seam needed to stop the interceptor
   from reaching `AuthManager.shared` directly, without pretending the
   underlying storage is any more secure than it was before this phase.

## 13. Trade-offs

`RetryPolicy`'s injectable `sleep` closure is one more parameter to reason
about, in exchange for the retry tests running in milliseconds instead of
multi-second real backoff delays - a deliberate, worthwhile trade for test
speed and determinism.

## 14. Failure scenarios

**A 201/204 response was silently treated as a failure** before this
phase's `isSuccess` fix - `RemoteServiceTests.statusCode201And204AreTreatedAsSuccess`
proves the fix (this app's actual endpoints return 200 in practice, so
this bug was latent rather than currently user-visible, but it was real).

**Retry exhaustion**: `RemoteServiceTests.exhaustsRetriesAndThrowsAfterMaxAttempts`
- a search that fails 3 times (matching `RetryPolicy.default.maxAttempts`)
throws the underlying error rather than retrying forever; `MoviesCoordinator`'s
`DefaultMovieRepository` then falls back to cache exactly as it did before
this phase (retry exhaustion and cache-fallback are two independent,
composable layers, not a wired-together special case).

**Cancellation during a retry delay**: `RetryPolicyTests.waitBeforeRetryingPropagatesCancellationFromInjectedSleep`
proves a cancelled backoff delay propagates `CancellationError` immediately
rather than the loop swallowing it and trying again.

## 15. Interview Q&A

### Why fix `isSuccess` and the double-encoding bug in the same phase as adding retry/injection, instead of a dedicated bug-fix commit?

**Strong answer:** All four changes touch the same small set of files
(`Request.swift`, `RemoteService.swift`, the two API services) for the same
underlying reason - this phase's job was "make the networking layer
correct and testable," and splitting genuinely related fixes across
separate commits/phases would fragment one coherent change for no reader
benefit.

**Code evidence:**
- `Assignment/Services/Remote/Request.swift` (`isSuccess`)
- `Assignment/Services/MovieSearchAPIService.swift` (encoding fix)
- Tests: `RemoteServiceTests.statusCode201And204AreTreatedAsSuccess`, `.queryParametersAreEncodedExactlyOnce`

**Follow-up question:** How did you verify the double-encoding fix actually
fixes the bug, rather than just removing code that happened to look
suspicious?

**Follow-up answer:** `RemoteServiceTests.queryParametersAreEncodedExactlyOnce`
asserts the sent URL contains `%20` (single-encoded space) and explicitly
asserts it does *not* contain `%2520` (what a double-encode of an
already-`%20`-encoded space would produce) - a test that would have failed
against the old code.

**Senior counter-question:** Your retry policy retries on `URLError.timedOut`
- but so does a request that's just slow because the *user's own device*
lost connectivity, not because the server is struggling. Should you back
off more aggressively, or notify the user sooner?

**Counter-answer:** Fair pressure - today's `RetryPolicy.default` (3
attempts, 0.5s base, 4s cap) is a reasonable generic default, not tuned
against this specific app's real-world failure distribution (no telemetry
exists yet to tune it against). Documented as a "revisit with real data"
item, not presented as a finished, measured choice.

**Trade-off:** A fixed, untuned retry policy risks retrying situations
(genuine offline state) where retrying wastes time before the user sees
any feedback - accepted for now given there's no usage data yet to tune
against.

**Failure scenario:** If Hotstar's search endpoint returned 429 under real
load, `RetryPolicy.default` would retry up to twice more with backoff
before falling through to `DefaultMovieRepository`'s cache fallback -
composing correctly with Phase 3's cache-fallback layer without either
layer needing to know about the other.

**Weak answer:** "I fixed a status code bug and added retries."

**Improved answer:** Names the exact incorrect boundary condition
(`statusCode <= 200 && statusCode <= 299` collapsing to just `<= 200`),
the exact double-encoding mechanism (pre-encoding plus `URLQueryItem`'s own
encoding), and the exact test that would have caught each one earlier.

## 16. Counter-questions

- "Why is `RemoteError.from(_:)` needed at all if `RemoteService.execute`
  already throws typed errors in most cases?" Because `RemoteService`
  itself doesn't wrap the raw `DecodingError` from `jsonDecoder.decode`,
  or an `AuthenticationInterceptor` failure, into a `RemoteError` - that
  mapping is deliberately the API-service layer's job (see
  `RemoteServiceTests.swift`'s header comment for why), and doing it in one
  shared static function instead of duplicated per-service catch chains is
  exactly what removed the pre-existing duplication between
  `MovieSearchAPIService` and `MovieDetailAPIService`.
- "Could the retry loop retry forever by mistake?" No -
  `RetryPolicy.shouldRetry`'s `guard attempt + 1 < maxAttempts else {
  return false }` is checked on every iteration before another retry is
  allowed, and it's a pure, directly-tested function (`RetryPolicyTests`),
  not logic embedded in the loop itself.

## 17. Exercises

**Observe:** Set a breakpoint in `RetryPolicy.shouldRetry`. Trigger a search
with the simulator offline (Network Link Conditioner or airplane mode) and
watch which `URLError.Code` actually arrives and whether it matches the
retryable set.

**Modify:** Change `RetryPolicy.default`'s `maxAttempts` from 3 to 1 and
re-run `RemoteServiceTests.retriesTransientFailuresUpToMaxAttemptsThenSucceeds`
- predict whether it still passes before running it (it shouldn't - the
test's fake handler needs 3 calls to succeed).

**Break intentionally:** Re-add the old `query.addingPercentEncoding(...)`
line to `MovieSearchAPIService.searchVideos` without removing the fix
elsewhere, and re-run `RemoteServiceTests.queryParametersAreEncodedExactlyOnce`
- it should still pass (it tests `RemoteService` in isolation, not this
specific API service) - a good lesson in why a test's scope matters: this
would need a *second*, API-service-level test to actually catch the
regression. Restore the fix afterward.

**Extend:** Add a new retryable `URLError.Code` (e.g. `.networkConnectionLost`
is already there - try `.cannotConnectToHost`) to `RetryPolicy.shouldRetry`,
and add a matching case to `RetryPolicyTests.retriesSelectedTransientURLErrors`'s
list.

**Interview:** Without re-reading this document, explain why
`AuthenticationInterceptor` takes an `AuthHeaderProviding` parameter instead
of reading `AuthManager.shared` directly, and why that's not yet the full
Phase 5 credentials-store fix.

## 18. Remaining limitations

`AuthHeaderProviding` is implemented by `AuthManager` (still the
plaintext-`UserDefaults`, singleton-backed type) - the interceptor no
longer *reaches for* the singleton itself, but the underlying storage
mechanism is unchanged (Phase 5). No structured-request/response logging
with redaction exists yet (Phase 9 touches logging broadly). `RetryPolicy.default`
is untuned against real failure data. `LoginViewController` still reads
`AuthManager.shared` directly (unchanged, Phase 5 scope).

---

# Before/after: the two networking bugs

## Before

```swift
extension HTTPURLResponse {
    var isSuccess: Bool { statusCode <= 200 && statusCode <= 299 }  // only true for <= 200
}

// MovieSearchAPIService.swift
guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { ... }
let parameters: [String: String] = ["search_query": encodedQuery, ...]
// -> RemoteService.getURL: URLQueryItem(name: "search_query", value: encodedQuery)  // encoded again
```

Problems:
- A 201/204 response would be treated as an error.
- A query containing a space would be sent as `%2520` instead of `%20`.

## After

```swift
extension HTTPURLResponse {
    var isSuccess: Bool { (200..<300).contains(statusCode) }
}

// MovieSearchAPIService.swift
let parameters: [String: String] = ["search_query": query, ...]  // raw, unencoded
// -> RemoteService.getURL: URLQueryItem(name: "search_query", value: query)  // encoded exactly once
```

- Who verifies this now: `RemoteServiceTests.statusCode201And204AreTreatedAsSuccess`
  and `.queryParametersAreEncodedExactlyOnce`, both against a
  `StubURLProtocol`-backed `URLSession` - no live server involved.
