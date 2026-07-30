# Phase 5 — Credentials Store and UIKit Auth Bridge

Status: **Implemented and verified** (with one honestly-scoped exception -
see §18).

## 1. Previous implementation

`AuthManager` was a single `class` doing five things at once: plaintext
`UserDefaults` storage, published login state, WebKit/cookie/URL-cache
clearing, header assembly, and (dead code) `UIWindow` root-controller
navigation. It printed credential prefixes
(`userToken.prefix(20)`, `cookie.prefix(50)`) on every save - real,
disclosed logging risk, not a style nit (see `SECURITY.md` for what
happens when a credential like this actually leaks). `LoginViewController`
read `AuthManager.shared` directly in two places. Cookie-extraction logic
(~30 lines) was embedded inside a `WKHTTPCookieStore` completion closure,
untestable without a live `WKWebView`. WebKit data-clearing was duplicated
verbatim between `AuthManager.logout` and `LoginViewController.clearAllWebData`.

## 2. Problem

Credentials in plaintext `UserDefaults` are trivially readable by anything
with file-system access to the app container. Printed prefixes leak
partial secret material into every build configuration's logs, including
Release. `AuthManager.shared` reached from `LoginViewController` and the
(pre-Phase-4) interceptor meant the "one composition root" story from
Phase 1 didn't actually hold for authentication. Untestable cookie
extraction meant a change to Hotstar's cookie contract could only be
caught by manually testing a real login.

## 3. Target responsibility

Move credential storage to the Keychain via a new `CredentialsStore` actor.
Give `LoginViewController` an injected `AuthManager` instead of `.shared`.
Extract cookie parsing into a pure, testable function. Consolidate WebKit
data-clearing into one service. Remove all credential-value logging.

## 4. Files introduced

- `CineConnect/Storage/KeychainStore.swift` (actor + `SecureKeyValueStoring` protocol)
- `CineConnect/Storage/CredentialsStore.swift`
- `CineConnect/Storage/WebDataClearingService.swift`
- `CineConnect/Views/Login/HotstarCredentialExtractor.swift`
- `docs/SWIFTUI_UIKIT_INTEROPERABILITY.md`
- Tests: `CineConnectTests/CredentialsStoreTests.swift`, `AuthManagerTests.swift`,
  `HotstarCredentialExtractorTests.swift`,
  `CineConnectTests/Fakes/InMemoryKeyValueStore.swift`

## 5. Files modified

- `CineConnect/Utils/AuthManager.swift` (rewritten - thin `@MainActor` wrapper over `CredentialsStore`/`WebDataClearingService`; dead `navigateToLogin` removed; no more `UserDefaults`, no more prefix-printing)
- `CineConnect/Views/Login/LoginViewController.swift` (injected `AuthManager`; uses `HotstarCredentialExtractor` and `WebDataClearingService`; removed the now-redundant "already authenticated" check)
- `CineConnect/Views/Login/LoginView.swift` (threads `authManager` through)
- `CineConnect/Coordinators/AuthenticationCoordinator.swift` (passes `authManager` to `LoginView`)
- `CineConnect/Coordinators/AppCoordinator.swift` (`start()` is now `async`; `root` starts at `.auth` and is corrected once real state is known)
- `CineConnect/CineConnectApp.swift` (`.task` instead of `.onAppear`)
- `CineConnect/Views/MoviesListView.swift` (`logout()` wrapped in a `Task`)
- `CineConnect/Services/Remote/Interceptors.swift` (`AuthHeaderProviding.getHeaders()` is now `async`)
- `CineConnectTests/AppCoordinatorTests.swift` (rewritten - see §15/§18, this is the interesting part)
- `CineConnectTests/RemoteServiceTests.swift` (fake provider updated for the async protocol)

## 6. Files removed

None (dead code was removed *within* `AuthManager.swift`, not as a whole file).

## 7. Runtime flow before

```
LoginViewController.viewDidLoad
  AuthManager.shared.isAuthenticated()          // UserDefaults read, sync
  clearAllWebData { ... }                        // duplicated WebKit-clearing logic
proceedButtonTapped -> extractAndSaveHeaders
  dataStore.httpCookieStore.getAllCookies { cookies in
    // ~30 lines of cookie-parsing logic, inline, untestable
    AuthManager.shared.saveCredentials(...)      // UserDefaults write, prints prefixes
  }
```

## 8. Runtime flow after

```
CineConnectApp.body: .task { await appCoordinator.start() }
  AppCoordinator.start()
    await authManager.refreshAuthenticationState()
      await credentialsStore.isAuthenticated()    // Keychain-backed, async
    root = authManager.isLoggedIn ? .movies : .auth

LoginViewController.viewDidLoad
  Task { await webDataClearingService.clearAllWebData() }   // one owner, async
proceedButtonTapped -> Task { await extractAndSaveHeaders() }
  cookies = await withCheckedContinuation { ... }            // bridges WebKit's callback API
  HotstarCredentialExtractor.extract(from: cookies)           // pure, testable
  await authManager.saveCredentials(...)                      // Keychain-backed, no logging
```

Numbered, with file/type/method/context:

1. **File:** `CineConnectApp.swift` · `.task` modifier · runs once per view
   appearance, `@MainActor` (SwiftUI task modifiers run on the main actor
   by default).
2. **File:** `AppCoordinator.swift` · `start()` · suspension point: `await
   authManager.refreshAuthenticationState()`.
3. **File:** `AuthManager.swift` · `refreshAuthenticationState()` ·
   suspension point: `await credentialsStore.isAuthenticated()` - crosses
   from `@MainActor` into the `CredentialsStore` actor's isolation domain.
4. **File:** `CredentialsStore.swift` · `isAuthenticated()` ·
   `currentCredentials()` · suspension points: three `await keychain.data(forKey:)`
   calls, each crossing into `KeychainStore`'s actor isolation domain.
5. Back on `@MainActor`: `AppCoordinator.start()` sets `root` from the
   now-known real value.

**Login flow**, numbered:

1. **File:** `LoginViewController.swift` · `proceedButtonTapped` · starts a
   `Task`, main thread (UIKit callback).
2. **File:** `LoginViewController.swift` · `extractAndSaveHeaders()` ·
   suspension point: `withCheckedContinuation` wrapping
   `WKHTTPCookieStore.getAllCookies` - the continuation resumes on
   whatever thread WebKit calls the completion handler on, then hops back
   per Swift's continuation machinery.
3. **File:** `HotstarCredentialExtractor.swift` · `extract(from:)` · pure,
   synchronous, no actor involved.
4. **File:** `AuthManager.swift` · `saveCredentials(...)` · suspension
   points: three `await credentialsStore.save`-related calls into the
   Keychain-backed actor.

**Tests covering these flows:** `AuthManagerTests` (5), `CredentialsStoreTests`
(5), `HotstarCredentialExtractorTests` (6), `AppCoordinatorTests` (6, updated).

## 9. Code excerpts

**Exact production code** (`CineConnect/Coordinators/AppCoordinator.swift`,
the async `start()` redesign):

```swift
init(authManager: AuthManager, remoteService: RemoteService) {
    self.authManager = authManager
    self.root = .auth   // safe default; corrected once real state is known
    ...
}

func start() async {
    await authManager.refreshAuthenticationState()
    root = authManager.isLoggedIn ? .movies : .auth
}
```

**Exact production code** (`CineConnect/Storage/KeychainStore.swift`, the
protocol that made this phase's tests possible at all):

```swift
protocol SecureKeyValueStoring: Sendable {
    func set(_ data: Data, forKey key: String) async
    func data(forKey key: String) async -> Data?
    func removeAll() async
}

actor KeychainStore: SecureKeyValueStoring { ... }
```

## 10. Build evidence

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CineConnect.xcodeproj -scheme CineConnect \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean test
```
Result: **BUILD SUCCEEDED**, **TEST SUCCEEDED**, 0 warnings, 76/76 tests
passing.

**The real story of this phase's verification** (worth reading in full -
this is the most instructive part of Phase 5): the first version of
`CredentialsStore`/`KeychainStore` had no protocol boundary -
`CredentialsStore` depended on the concrete `KeychainStore` actor
directly, and `AppCoordinatorTests` drove real credential saves through
`AuthManager.shared`. Running the suite, `AppCoordinatorTests.startsAtMoviesRootWhenAuthenticated`
failed - not flakily, but consistently, including in a dedicated isolated
diagnostic test that saved then immediately re-read a value with no other
test running at all. Instrumenting `KeychainStore.set` to report its raw
`OSStatus` (via a temporary test, since removed) showed: **`-34018`,
`errSecMissingEntitlement`**. This project's build environment has no
valid code-signing identity (`security find-identity -v -p codesigning`
reports zero identities), and every build in this environment runs with
`CODE_SIGNING_ALLOWED=NO`. The iOS Simulator's Keychain requires an
entitled, signed binary for `SecItemAdd`/`SecItemUpdate` to succeed - an
unsigned test-host app cannot write to it at all. (A standalone `swift`
script run directly on the Mac host, outside any app sandbox, could write
to the Keychain fine - confirming the constraint is about the
signed-app-sandbox context specifically, not Keychain Services in
general.)

**The fix was architectural, not a workaround**: `SecureKeyValueStoring`
was introduced so `CredentialsStore`'s own logic - credential composition,
the authenticated/not-authenticated decision, header assembly - could be
tested against `InMemoryKeyValueStore` (a plain in-memory fake), while
`KeychainStore` itself remains real Keychain code, honestly marked as not
covered by this environment's automated tests. `AppCoordinatorTests` was
then rewritten to construct isolated `AuthManager` instances (each with
its own `InMemoryKeyValueStore`-backed `CredentialsStore`) instead of
driving the real `AuthManager.shared` - which, as a side benefit, finally
resolved the "these are integration tests against a singleton, not real
unit tests" honesty note that had been carried since Phase 1.

Two more warning batches (the same default-argument-expression class seen
in Phases 1/3/4) were hit and fixed during this phase: one in
`AuthManager.init`, one requiring `CredentialsStore.init`'s `keychain`
parameter to have no default at all (constructing an actor from inside
another actor's own initializer body triggered the same isolation
restriction as a default-argument expression would - documented in that
initializer's doc comment).

## 11. Test evidence

76 tests total (was 60), all passing. New this phase: `CredentialsStoreTests`
(5 - authenticated/not, header assembly, clearing), `AuthManagerTests` (5 -
isolated `AuthManager` instances with injected fakes), `HotstarCredentialExtractorTests`
(6 - token extraction, `loc`-cookie fallback, domain filtering, essential-name
filtering, empty input). `AppCoordinatorTests` (6) rewritten to use isolated
`AuthManager` instances instead of the shared singleton.

## 12. Alternatives

1. **Keep `UserDefaults`, just stop printing prefixes.** Rejected: fixes
   the logging symptom, not the actual plaintext-storage problem.
2. **Skip the `SecureKeyValueStoring` protocol; mark `CredentialsStoreTests`
   as requiring a signed build to run.** Rejected: this would leave
   `CredentialsStore`'s own decision logic completely unverified by any
   automated test in this environment, for a problem a small protocol
   boundary solves cleanly.
3. **Make `KeychainStore` itself fake-friendly by adding a "test mode"
   flag.** Rejected: a protocol boundary at the actual dependency edge is
   simpler and doesn't put test-only branching inside production Keychain
   code.
4. **Full biometric/passcode-gated Keychain access
   (`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` + `SecAccessControl`).**
   Considered, not adopted: this app's threat model (protecting a
   reverse-engineered streaming-service session token, not a payment
   credential or health record) doesn't obviously justify the added
   friction of biometric gating on every use; `kSecAttrAccessibleAfterFirstUnlock`
   is a reasonable, common default. Worth revisiting if this pattern were
   reused for a higher-sensitivity credential.

## 13. Trade-offs

The `SecureKeyValueStoring` boundary means `CredentialsStore`'s tests
verify its own logic thoroughly but never exercise the real
`SecItemAdd`/`SecItemCopyMatching` code paths - a genuine, stated gap (see
§18), not a false sense of full coverage.

## 14. Failure scenarios

**The `errSecMissingEntitlement` discovery itself is the primary failure
scenario this phase surfaced** - see §10 for the full account. It's an
unusually good interview story precisely because it wasn't anticipated
going in; the fix (a protocol boundary) is also the textbook-correct
answer, arrived at because the naive approach failed loudly enough to
force it.

**Logout during an active detail request** (a scenario named in the
original migration brief): today, `MoviesListView.logout()` calls `await
authManager.logout()` then `onLogout?()`. `AppCoordinator.showAuth()`
switches `root`, which tears down the movies `NavigationStack` and its
hosted `MovieDetailView`/`MovieDetailViewModel` - SwiftUI's own view
lifecycle cancels any `.task(id:)`-driven in-flight detail load
automatically when the view disappears (same mechanism documented in
Phase 2/3). No explicit "cancel all in-flight requests on logout" code
exists because SwiftUI's structural teardown already produces that effect
here - **not yet backed by a dedicated test**, tracked as a real gap (§18).

## 15. Interview Q&A

### Why did you introduce a `CredentialsStore` actor instead of just moving `UserDefaults` calls into a class?

**Strong answer:** Two independent reasons. First, security: `UserDefaults`
is plaintext, readable by anything with app-container file access; the
Keychain is the platform's actual secure-storage primitive. Second,
testability: wrapping it as an actor behind a `SecureKeyValueStoring`
protocol is what let `CredentialsStore`'s real decision logic (what counts
as authenticated, how headers are built) get unit-tested at all - discovered
the hard way, when the real Keychain turned out to be unreachable from this
project's unsigned test-host environment (`errSecMissingEntitlement`).

**Code evidence:**
- `CineConnect/Storage/CredentialsStore.swift`
- `CineConnect/Storage/KeychainStore.swift` (the `SecureKeyValueStoring` protocol and its doc comment)
- Tests: `CredentialsStoreTests` (5), using `InMemoryKeyValueStore`

**Follow-up question:** Is an actor here protecting against a real data
race, the way a future `MemoryCache` actor would?

**Follow-up answer:** Honestly, not really - the Keychain Services C API
is already synchronous and thread-safe at the OS level. The actor's real
value here is a single async, testable interface, not race protection.
This is explicitly called out in `KeychainStore`'s own doc comment rather
than implied.

**Senior counter-question:** If the Keychain is already thread-safe, isn't
wrapping it in an actor just for the async interface overkill - could a
plain class work?

**Counter-answer:** A plain class works too, and would need its own
manual `async` wrapper functions to present the same interface anyway (or
callers would have to deal with the callback-free-but-still-synchronous,
main-thread-blocking nature of Keychain calls directly). The actor gets
"async by construction" for free and matches the isolation vocabulary the
rest of this codebase (`MoviesCoordinator`, `AppCoordinator`, future
caches) already uses - a real but modest win, not a load-bearing one.

**Trade-off:** An actor here is "useful extensibility"/"educational but
genuinely exercised" rather than strictly "production-essential" - a fair
characterization to give in an interview rather than overselling it as
solving a race condition that doesn't exist.

**Failure scenario:** The literal failure scenario this phase hit:
`errSecMissingEntitlement` (-34018) when writing to the Keychain from this
project's unsigned build - see §10.

**Weak answer:** "I used the Keychain because it's more secure than
UserDefaults."

**Improved answer:** Names the actual OSStatus code hit, the actual
environment constraint that caused it, and the actual architectural fix
(a protocol boundary) that resulted - not just "Keychain is more secure,"
which is true but doesn't demonstrate anything about how this
specific codebase got there.

## 16. Counter-questions

- "Why does `AppCoordinator.start()` need to exist at all now, versus
  `AppCoordinator.init` just doing everything synchronously?" Because
  Keychain reads are asynchronous by construction (`CredentialsStore.isAuthenticated()`
  is `async`), and a SwiftUI `@StateObject`'s `init` can't `await` -
  `start()`, run via `.task`, is where that async work actually happens.
  This also finally gives `start()` the real job Phase 1's doc flagged it
  as *not* having yet.
- "What would break if `HotstarCredentialExtractor` were deleted and its
  logic inlined back into `LoginViewController`?" Every test in
  `HotstarCredentialExtractorTests.swift` would have no non-UIKit way to
  run - the exact reason it was pulled out.

## 17. Exercises

**Observe:** Set a breakpoint in `CredentialsStore.currentCredentials()`.
Log in via the real app (needs a properly signed run, given §18/§10's
environment constraint) and confirm it's called once per
`refreshAuthenticationState()`/`headers()` invocation.

**Modify:** Add a `deviceId` field to `CredentialsStore.Credentials` and
thread it through `save`/`currentCredentials`/`headers`. Predict which
test file needs new assertions before running (`CredentialsStoreTests.swift`).

**Break intentionally:** Temporarily make `CredentialsStore.init` default
its `keychain` parameter back to a live `KeychainStore()`. Re-run
`AppCoordinatorTests` and watch `startsAtMoviesRootWhenAuthenticated` fail
with the same `errSecMissingEntitlement` symptom this phase found -
concrete proof the fix in §10 is what makes the suite green. Restore the
required parameter afterward.

**Extend:** Add a `SecureKeyValueStoring`-conforming fake that
intermittently returns `nil` (simulating a corrupt/missing Keychain
read) and write a test proving `CredentialsStore.isAuthenticated()`
degrades to `false` rather than crashing.

**Interview:** Without re-reading this document, explain what
`errSecMissingEntitlement` means, why this specific project's test
environment hits it, and how the codebase's tests still verify
`CredentialsStore`'s logic despite it.

## 18. Remaining limitations

**`KeychainStore`'s actual Keychain calls are not covered by any automated
test in this environment** (§10/§12) - verify manually on a properly
signed device or simulator run before relying on this in production; that
verification has not been performed as part of this session, and this
document does not claim it has. No dedicated test exists yet for
"logout during an active detail request" (§14) - the behavior is believed
correct by construction (SwiftUI's own view-lifecycle cancellation) but
untested. `LoginViewController` is still not `@MainActor`-annotated
explicitly (tracked since Phase 4, Phase 9 scope). `AuthManager` is still
a singleton *type* (`AuthManager.shared` exists) - Phase 5 made its
storage swappable and removed every non-composition-root reference to
`.shared`, but didn't eliminate the singleton pattern itself.
