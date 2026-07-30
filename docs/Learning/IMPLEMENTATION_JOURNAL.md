# Implementation Journal

A technical record of each phase: what was wrong, what changed, why, and
what it demonstrated — not a terminal transcript. No secret values, local
paths, or recovery information appear here (see `../../SECURITY.md` for the
sanitized incident record).

---

## CC0–CC4 (pre-dates this real-time documentation process)

**Commits:** `1ece177`…`0e0e4ed` (pre-rewrite SHAs; see
`../ARCHITECTURE_REFACTOR_PLAN.md` §0b for why these numbers changed after
the security history rewrite).

**Problem found:** the original app had every architectural problem listed
in `../ARCHITECTURE_REFACTOR_PLAN.md` §1 — no coordinators, `AuthManager`
combining storage/state/navigation, `RemoteService.shared` reached from
everywhere, navigation decisions inside `MoviesListView`.

**New design:** introduced a `Coordinator` protocol, `AppCoordinator`,
`AuthCoordinator`, `MoviesCoordinator`, and a simple file-backed
`MovieCache`.

**Why it's audited here rather than redone:** the coordinator work was
correct in shape (see the retain/refactor/rename table in
`../ARCHITECTURE_REFACTOR_PLAN.md` §1c) — this migration builds on it
instead of discarding it.

**Remaining debt at this point:** everything Phase 1 onward addresses —
singleton defaults on every coordinator init, no DI container, no typed
routes, ViewModels self-constructing their API services.

---

## Security remediation (2026-07-29)

**Problem found:** `Assignment/Services/Remote/Constants.swift` hardcoded a
real authentication token with an embedded personal-data payload, public
since the repository's first commit.

**What changed:** removed the file from active source; rewrote git history
across all four branches with `git-filter-repo`; added
`scripts/check-secrets.sh` + `.github/workflows/secret-scan.yml`; documented
in `SECURITY.md`.

**Build/test:** unaffected (the constant was dead code) — verified with a
full build both before and after the history rewrite.

**Interview concept demonstrated:** the difference between "fixing the
current commit" and "the value is already compromised regardless of history
rewriting" — see `SECURITY.md`'s explicit limitation note.

---

## CC5 — Phase 0 baseline audit (commit `9be4286`)

**Problem found:** no audit trail existed distinguishing what CC0–CC4 had
actually verified versus assumed.

**What changed:** added `docs/ARCHITECTURE_REFACTOR_PLAN.md` with a
claim-by-claim audit against real source (file:line evidence for each of
the 20 "problems to verify" from the migration brief), plus a working
baseline build command.

**Alternatives considered:** trusting the CC0 baseline doc as still
accurate — rejected, because it predates the coordinator work it describes
as missing (CC0 says "no coordinator layer," which CC1–CC4 then added; the
new audit re-verifies against the actual current tree instead of an older
doc).

---

## CC6 — unit and UI test targets (commit `ae220c9`)

**Problem found:** zero test targets existed; `xcodebuild -list` showed one
target, one scheme.

**What changed:** added `AssignmentTests` (Swift Testing) and
`AssignmentUITests` (XCTest/`XCUIApplication`) as native targets via a
minimal, targeted `project.pbxproj` edit — new `PBXNativeTarget`/
`PBXTargetDependency`/`XCConfigurationList` entries only.

**Files changed:** `Assignment.xcodeproj/project.pbxproj`,
`AssignmentTests/AssignmentTests.swift`,
`AssignmentUITests/AssignmentUITests.swift`.

**Build result:** `plutil -lint` clean, `xcodebuild -list` shows all three
targets, `xcodebuild build` succeeds, `xcodebuild test` runs both new
targets' smoke tests successfully — with **no explicit `.xcscheme` file
needed**: Xcode's autocreated scheme already included the dependent test
targets in its Test action once they existed in the project.

**Alternative considered:** using the CocoaPods `xcodeproj` Ruby gem to
author the targets programmatically — rejected because this project's
`objectVersion` is 77 (Xcode 16+'s file-system-synchronized groups), and a
full parse/reserialize round-trip through a gem risked mangling that very
new format more than a small, targeted textual diff would.

**Interview concept demonstrated:** modern Xcode project format
(`PBXFileSystemSynchronizedRootGroup`) needs far less manual wiring per file
than the classic `PBXFileReference`/`PBXBuildFile` approach — adding a
target is now mostly "declare the target and its one synchronized root
group," not "enumerate every source file."

---

## CC7 — Phase 1: composition root (commit `a1abfdd`)

**Previous design:** `AppCoordinator()`, `AuthCoordinator(authManager: AuthManager = .shared)`,
`MoviesCoordinator(authManager: AuthManager = .shared)` — every coordinator
defaulted to the global singleton itself.

**New design:** `AppDependencyContainer` is the one place that resolves
`AuthManager.shared`; every coordinator's initializer now *requires*
`authManager` with no default, so nothing downstream can silently reach for
the singleton. `AssignmentApp.init()` builds the container, then asks it for
the coordinator.

**Runtime behavior:** unchanged for the user — same login/movies root
switching as before.

**Files changed:** new `Assignment/App/AppDependencyContainer.swift`;
modified `AssignmentApp.swift`, `AppCoordinator.swift`, `MoviesCoordinator.swift`;
renamed `AuthCoordinator.swift` → `AuthenticationCoordinator.swift`.

**Tests added:** `AssignmentTests/AppCoordinatorTests.swift` (6 tests) —
root-switching on auth state, the `onAuthenticated`/`onLogout` closures
bubbling correctly, and the container's factory method.

**A real, disclosed gap:** those tests exercise the actual
`AuthManager.shared` singleton (marked `@Suite(.serialized)` so they don't
race each other), not a fake — because `AuthManager.init` is still
`private`. That's tracked as Phase 5 work, not silently left ambiguous.

**Build/test result:** clean build, 0 warnings (one actor-isolation warning
introduced by the container's own default-argument expression was caught
and fixed in the same commit — see the file-level note in
`AppDependencyContainer.swift`).

---

## CC8 — Phase 2: typed navigation + injected MVVM (commit `95af1c4`)

**Previous design:** `MoviesCoordinator` pushed the bare `Movie` model via
`.navigationDestination(for: Movie.self)`, relying on `NavigationStack`'s
implicit path; `MoviesListView`/`MovieDetailView` each self-constructed
their ViewModel via a `convenience init()` that itself default-constructed
a concrete API service.

**New design:** added `MoviesRoute` (currently one case, `.detail(Movie)`);
`MoviesCoordinator` now owns an explicit `@Published var path =
NavigationPath()`; both Views take their ViewModel through a required
initializer parameter, and `MoviesCoordinator` constructs
`MovieSearchViewModel`/`MovieDetailViewModel` (still wrapping the concrete
`MovieSearchAPIService`/`MovieDetailAPIService` directly — that's Phase 3's
job to change, not this one's).

**Files changed:** new `MoviesRoute.swift`; modified `MoviesCoordinator.swift`,
`MoviesListView.swift`, `MovieDetailView.swift`, `MovieSearchViewModel.swift`,
`MovieDetailViewModel.swift` (deleted the now-dead `convenience init()` on
both ViewModels rather than leaving unused code behind).

**Tests added:** `AssignmentTests/MoviesCoordinatorTests.swift` (2 tests) —
path starts empty, appending a route grows it.

**Alternative considered:** carrying only `movieID`/`slug` in the route
(matching the originally sketched `MoviesRoute` shape) — rejected for now
because `MovieDetailView` renders `movie.posterURL` immediately while the
real detail network call is in flight; a slug-only route would need an
extra "look up the Movie for this id" step that doesn't otherwise exist.
Documented as a to-revisit point once deep linking needs a route
constructible without an in-memory `Movie`.

**Build/test result:** clean build; one missing `import Combine` caught
(same class of issue as an earlier pre-existing fix to `AppCoordinator`) and
fixed before commit; 10/10 tests passing.

**Interview concepts demonstrated:** typed, `Hashable` navigation values
versus raw domain models as nav values; `@Published NavigationPath` as an
explicit, coordinator-owned piece of state versus `NavigationStack`'s
default implicit path; constructor injection replacing convenience-init
self-construction, and *deleting* the now-dead convenience initializers
rather than leaving them as unused surface area.

---

## Phase 3 — Domain, repository, DTO/mapper boundaries

**Previous design:** ViewModels called API services directly; each API
service did request-building, decoding, mapping, *and* cache-fallback in
one method, with the fallback policy duplicated identically between the
two services.

**New design:** `Movie`/`MovieDetail` moved to `Domain/Models/`; a
`MovieRepository` protocol added; `DefaultMovieRepository` owns the
cache-fallback policy once; `SearchMoviesUseCase` owns query normalization
(real logic); `GetMovieDetailUseCase` is a documented, deliberate
pass-through; DTOs (`Data/DTOs/`) and their mapping extensions
(`Data/Mappers/`) split into separate files; `MovieSearchAPIService`/
`MovieDetailAPIService` simplified to remote-data-source-only.

**Files changed:** see `Architecture/Phase-03-Domain-and-Repository.md` §4-6
for the full list.

**Runtime behavior:** unchanged for the user — same search/detail behavior,
same cache-fallback-on-failure policy. One real behavior *fix*: a cancelled
request no longer falls back to stale cached data (previously it did,
because the cache-fallback catch block didn't distinguish
`CancellationError` from a genuine failure).

**Tests added:** 29 new tests — `MovieSearchMapperTests` (5),
`MovieDetailMapperTests` (4), `DefaultMovieRepositoryTests` (5),
`SearchMoviesUseCaseTests` (5), `GetMovieDetailUseCaseTests` (2),
`MovieSearchViewModelTests` (5, including the "search race" stale-response
scenario), `MovieDetailViewModelTests` (3) — plus two new fakes,
`FakeMovieRepository` and `FakeMovieSearchAPIService`/`FakeMovieDetailAPIService`.

**Build result:** clean build, 0 warnings — after fixing a batch of
actor-isolation warnings the new test suites introduced (see the phase
doc's §10 for the exact cause and fix: `@MainActor` on each new `@Suite`).

**Alternatives considered:** ViewModel→repository directly (skipping use
cases), full Clean-Architecture-style fine-grained use cases — both
documented with reasoning in the phase doc's §12, alongside why this
project picked "one use case per screen operation, even where one is
currently thin."

**Why the final approach was selected:** consistency of dependency shape
across ViewModels, plus a repository boundary that's already earning its
keep (it's what let this phase find and fix the cancellation/cache bug in
one place instead of two).

**New interview concepts demonstrated:** repository-as-cache-fallback-owner
(not just a forwarding layer), the honest "when do use cases become
unnecessary" question answered with a real pass-through example from this
exact codebase, `Sendable`/actor-readiness deferred deliberately rather than
declared prematurely.

**Remaining debt:** `MovieCache` still not actor-isolated; no `CachePolicy`
parameter; `MoviesCoordinator` still constructs concrete API services
directly (Phase 4); the known `isSuccess`/double-encoding bugs untouched
(Phase 4).

---

## Phase 4 — Networking bug fixes, retry, injected interceptor

**Previous design:** `isSuccess` only accepted exactly HTTP 200; search
queries were percent-encoded twice; no retry policy existed;
`AuthenticationInterceptor` read `AuthManager.shared` directly;
`RemoteErrorResponse` was decoded by nothing; `BaseAPIService` still
defaulted `remoteService` to `.shared`; `Remote.Request` had two dead,
unused private methods duplicating `RemoteService`'s own request-building.

**New design:** `isSuccess` fixed to `(200..<300).contains(statusCode)`;
double-encoding removed (the pre-encoding call, not `RemoteService`'s own
`URLQueryItem` encoding, was the bug); added `RetryPolicy` (bounded
exponential backoff, method-gated to GET only, injectable sleep for fast
tests); `RemoteService.execute` now attempts `RemoteErrorResponse`
decoding on failure before falling back to `.general`; added
`AuthHeaderProviding`, which `AuthManager` conforms to, so
`AuthenticationInterceptor` takes an injected provider instead of reading
the singleton; removed `RemoteService.shared` entirely, building the one
instance in `AppDependencyContainer` and threading it through
`AppCoordinator` -> `MoviesCoordinator` -> both API services; deleted the
two dead `Remote.Request` methods.

**Files changed:** see `Architecture/Phase-04-Networking.md` §4-6.

**Runtime behavior:** unchanged for the user under normal conditions.
Behavior *fixed*: a 201/204 response no longer reports as a failure; a
search query with special characters is no longer double-encoded; a
transient failure now gets up to 2 automatic retries with backoff before
falling through to Phase 3's cache fallback.

**Tests added:** 20 new tests - `RemoteServiceTests` (9, via
`StubURLProtocol` - query encoding, status-code handling, structured/
unstructured server errors, retry success/exhaustion, POST-never-retried,
header injection), `RetryPolicyTests` (7, pure decision logic, no
networking), `RemoteErrorTests` (4, `.from(_:)` mapping including
`RemoteError` passthrough).

**Build result:** clean, 0 warnings - after fixing two more instances of
the same default-argument actor-isolation warning class seen in Phase 3,
and a real test-flakiness bug: `RemoteServiceTests` initially failed under
parallel execution because `StubURLProtocol`'s handler/request-log are
shared static state; fixed with `.serialized`, the same treatment already
applied to `AppCoordinatorTests` for a different shared-singleton reason.

**Alternatives considered:** a full `APIClient`/`APIRequest<Response>`
rename/redesign (rejected - `RemoteService`/`Remote.Request` already
provide adequate typed generics; the real problems were two bugs and two
missing seams, not the wrong shape); retrying every HTTP method
(rejected - non-idempotent risk); building the full Phase 5 credentials
store now instead of just the interceptor's injection seam (rejected -
out of this phase's scope).

**Why the final approach was selected:** fix what's actually broken and
missing, in the files that actually need it, without a cosmetic rename of
things that already worked.

**New interview concepts demonstrated:** the exact boundary-condition bug
in the original `isSuccess` (`<= 200 && <= 299` collapsing to `<= 200`);
double-encoding as a category of URL-construction bug; retry policy as a
pure, independently-testable decision function separate from the loop that
consults it; `StubURLProtocol` as the standard technique for networking
tests with no live server; test suites needing `.serialized` when they
share static/global state, a second real example of this after
`AppCoordinatorTests`.

**Remaining debt:** `AuthHeaderProviding` is implemented by the same
plaintext-`UserDefaults` `AuthManager` (Phase 5 replaces the *storage*, not
just the interceptor's dependency shape); no redacted structured logging
yet (Phase 9); `RetryPolicy.default`'s tuning is a reasonable guess, not
measured against real failure data.

---

## Phase 5 — Credentials store and UIKit auth bridge

**Previous design:** `AuthManager` did storage (plaintext `UserDefaults`),
state, WebKit clearing, and dead navigation code all in one class, and
printed credential prefixes on every save. `LoginViewController` read
`AuthManager.shared` directly. Cookie extraction was ~30 lines inline
inside a WebKit completion closure.

**New design:** `CredentialsStore` (actor, Keychain-backed via
`KeychainStore`) replaces `UserDefaults`; `AuthManager` becomes a thin
`@MainActor` wrapper with no storage of its own and no credential logging;
`LoginViewController` takes an injected `AuthManager`; cookie extraction
moved to the pure, testable `HotstarCredentialExtractor`; WebKit
data-clearing consolidated into `WebDataClearingService` (previously
duplicated in two places).

**The real finding of this phase:** the naive Keychain-backed design
(`CredentialsStore` depending on the concrete `KeychainStore` actor
directly) turned out to be completely untestable in this project's build
environment - `SecItemAdd`/`SecItemUpdate` return `errSecMissingEntitlement`
(-34018) when called from an unsigned app, which is exactly what
`CODE_SIGNING_ALLOWED=NO` (used throughout this session, since no valid
signing identity exists here) produces. Diagnosed by instrumenting
`KeychainStore` to report the raw `OSStatus` in a temporary test, then
confirming a bare `swift` script on the Mac host (outside any app sandbox)
could write to the Keychain fine - isolating the constraint to the
signed-app-sandbox context specifically. Fixed architecturally: introduced
`SecureKeyValueStoring`, so `CredentialsStore`'s own logic is now tested
against `InMemoryKeyValueStore`, while `KeychainStore` remains real
Keychain code, honestly documented as unverified by this environment's
automated tests (see `docs/Learning/Architecture/Phase-05-Authentication.md`
§10 for the full account - it's worth reading in full).

**A second, related fix:** `AppCoordinatorTests` had been driving the real
`AuthManager.shared` singleton since Phase 1 (an acknowledged testability
gap in every prior phase's docs). Phase 5's constructor injection made it
possible to finally construct isolated `AuthManager` instances per test -
closing that gap as a side effect of fixing the Keychain-testability
problem, not as separate work.

**Files changed:** see `Architecture/Phase-05-Authentication.md` §4-6.

**Runtime behavior:** login/logout behavior is unchanged for the user.
`AppCoordinator.start()` becoming `async` (root now starts at `.auth` and
corrects itself once real Keychain state is known, rather than blocking
`init` on a synchronous check) is a real, intentional behavior change,
necessary because Keychain reads are asynchronous.

**Tests added:** 16 new tests - `CredentialsStoreTests` (5),
`AuthManagerTests` (5), `HotstarCredentialExtractorTests` (6). `AppCoordinatorTests`
(6) rewritten, not added to, for the isolation fix above.

**Build result:** clean, 0 warnings - after fixing two more instances of
the recurring default-argument actor-isolation warning class (this time
also requiring `CredentialsStore.init` to drop its default parameter
entirely, since constructing an actor from inside another actor's own
initializer body hit the same restriction a default-argument expression
would).

**Alternatives considered:** keep `UserDefaults`, only remove the
prefix-printing (rejected - treats the symptom, not the plaintext-storage
problem); skip the protocol boundary and mark Keychain tests as
environment-dependent/skipped (rejected - would leave `CredentialsStore`'s
actual decision logic completely unverified for a problem a small
protocol solves cleanly); biometric/passcode-gated Keychain access
(considered, not adopted - not clearly justified by this app's threat
model, revisit if reused for higher-sensitivity data).

**Why the final approach was selected:** the protocol boundary is the
textbook-correct answer to "a real dependency is unreachable in this test
environment," and it was arrived at because the naive approach failed
loudly and reproducibly enough to force the better design, not chosen
speculatively upfront.

**New interview concepts demonstrated:** diagnosing a real
`OSStatus`/`errSecMissingEntitlement` failure through instrumentation
rather than guessing; a protocol boundary as the fix for "real dependency
unreachable in this test environment," directly parallel to
`URLProtocol`/`StubURLProtocol` in Phase 4; an actor whose real value is
"one async, testable interface" rather than race protection, stated
honestly rather than oversold; closing a testability gap (the
`AppCoordinatorTests` singleton problem) as a side effect of fixing a
different, more urgent problem.

**Remaining debt:** `KeychainStore`'s real Keychain calls remain
unverified by automated tests in this environment (needs a properly
signed build to check manually); no dedicated test for "logout during an
active detail request" (behavior believed correct via SwiftUI's own view
lifecycle, untested); `AuthManager` is still a singleton type, just with
swappable storage now.

---

## Phase 6 — Actor-based caches and request coalescing

**Previous design:** `MovieCache` was a plain class - one flat disk cache,
no TTL, no eviction, no request coalescing. `MoviesCoordinator` also
(a bug found during this phase's own design work, not inherited) built a
*fresh* repository instance per screen, which would have made per-instance
cache actors pointless.

**New design:** `MemoryCache<Key,Value>` (TTL, LRU, hit/miss tracking),
`DiskCache<Value>` (detail only - search stays memory-only, see
`MovieRepository`'s doc comment for why), and
`InFlightRequestStore<Key,Value>` (coalescing), all actors.
`CachePolicy` (`.networkFirst`/`.cacheFirst`/`.reloadIgnoringCache`) drives
`DefaultMovieRepository`. `MoviesCoordinator` now builds one repository
per coordinator lifetime, fixing the bug above. Caches clear on logout via
`MoviesCoordinator.performLogout()`.

**Files changed:** see `Architecture/Phase-06-Caching.md` §4-6.

**Runtime behavior:** unchanged for the user under normal conditions.
Real behavior improvements: revisiting a movie's detail screen within its
TTL now hits cache instead of the network (fixed alongside introducing
the caches, since the per-screen-repository bug would have silently
defeated them); ten simultaneous identical detail requests now trigger
one network call, not ten; caches are cleared on logout.

**The compiler-inference pattern from Phases 1/3/4/5 hit hardest here:**
`MemoryCache<String, MovieDetail>` failed to *compile* (not just warn)
with "main actor-isolated conformance of 'MovieDetail' to 'Decodable'
cannot satisfy... 'Sendable'" - the project's default-actor-isolation
setting infers even a plain data model's own protocol conformances as
`@MainActor`-isolated unless told otherwise. Fixed by marking `Movie` and
`MovieDetail` `nonisolated struct`. Three related fixes: `DiskCache`'s
`FileManager` reference needed `nonisolated(unsafe)` (`FileManager` itself
isn't `Sendable` in the SDK, though `.default` is documented safe for
concurrent use); the API service protocols needed `: Sendable` added
(captured in `@Sendable` closures now); their test fakes needed
`@unchecked Sendable` (configured once before concurrent use, an already-
established pattern in this codebase).

**A real test bug, also found and fixed:** an early version of
`MemoryCacheTests.staleValueIsReturnedEvenAfterExpiry` checked the fresh
(evicting) read before the stale (non-evicting) read, so the stale check
found nothing - fixed by reordering, which also strengthened what the
test actually proves.

**Tests added:** 26 new tests - `MemoryCacheTests` (8), `DiskCacheTests`
(5), `InFlightRequestStoreTests` (4, including the actor-reentrancy
scenario the migration brief specifically asked for), and
`DefaultMovieRepositoryTests` expanded from 5 to 14.

**Build result:** clean, 0 warnings, 102/102 tests passing.

**Alternatives considered:** one generic cache actor covering both memory
and disk (rejected - different failure modes deserve different types); a
fourth `CachePolicy` case (`.returnCacheElseLoad`, rejected as redundant
with `.cacheFirst`); an app-wide single repository instance instead of
per-coordinator (considered, kept feature-scoped since it's functionally
equivalent today given `MoviesCoordinator`'s own app-session lifetime).

**Why the final approach was selected:** three focused, generic actor
types map directly onto three distinct real needs (bounded fast memory,
durable detail storage, deduplication), each independently testable and
each with one clear job.

**New interview concepts demonstrated:** the sharpest example yet of this
project's recurring default-actor-isolation-inference gotcha, this time
blocking compilation rather than just warning; `nonisolated`/
`nonisolated(unsafe)` as the two different tools for two different
reasons (a type with no isolation need at all, vs. a specific SDK type
documented safe for concurrent use despite not being formally `Sendable`);
a concrete, tested actor-reentrancy scenario with a matching "break it on
purpose" exercise.

**Remaining debt:** `clearCaches()` doesn't cancel in-flight requests; no
memory-warning-driven eviction; `.reloadIgnoringCache` has no UI trigger
yet (Phase 9).

---

## Phase 7 onward

Not started. See `docs/ARCHITECTURE_REFACTOR_PLAN.md` for the full phase
list and `docs/Learning/README.md` for current status labels.
