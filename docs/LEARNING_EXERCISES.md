# Learning Exercises

A cross-cutting index of every exercise from every phase document, in the
order `docs/Learning/README.md`'s "Exercise order" recommends — do Phase
1's and 2's before Phase 3's, and so on, since later phases assume fluent
reading of earlier code. Each exercise is listed here with just enough
context to know what it's for; the full text (and the code it refers to)
lives in its phase document, linked below.

Every phase's exercises follow the same four-shape pattern:

- **Observe** — set a breakpoint or watch real behavior, no code changes.
- **Modify** — make a small, safe change and predict the result before running it.
- **Break intentionally** — reintroduce a fixed bug on purpose, watch a real test catch it, then restore the fix.
- **Extend** — add a small, genuinely new piece of behavior, with a reasoning prompt, not just "write more code."

Most phases also end with an **Interview** exercise: explain a specific
design decision out loud, from memory, without re-reading the doc — the
real test of whether you understood it or just read it.

## Phase 1 — Composition root and coordinators

[`Architecture/Phase-01-Composition-Root-and-Coordinators.md` §17](Learning/Architecture/Phase-01-Composition-Root-and-Coordinators.md#17-exercises)

- Observe: confirm `AppDependencyContainer.init` fires exactly once per launch, before any coordinator exists.
- Modify: add a second dependency to the container; predict which files change before running the build.
- Break intentionally: reintroduce `= .shared` on `AppCoordinator.init`; confirm the tests still pass anyway — proof that passing tests alone doesn't prove an architecture rule is being followed.
- Extend: add a `makeAuthenticationCoordinator()` factory method; decide whether that changes who *owns* the child coordinator versus who *constructs* it.
- Interview: explain why `AppDependencyContainer.init` resolves `.shared` inside the function body instead of as a default parameter value.

## Phase 2 — Typed navigation and injected MVVM

[`Architecture/Phase-02-Movies-Navigation-and-MVVM.md` §17](Learning/Architecture/Phase-02-Movies-Navigation-and-MVVM.md#17-exercises)

- Observe: confirm `MoviesCoordinator.destinationView(for:)` fires with the tapped `Movie` inside `.detail`.
- Modify: add a `source: String` field to `MoviesRoute`; predict which files need to change (fewer than you'd expect).
- Break intentionally: revert `MoviesListView`'s `NavigationLink` to push `Movie` directly without updating the destination registration — it still compiles, but the row becomes silently unrouted at runtime.
- Extend: add an unused `MoviesRoute.search(query:)` case; watch the exhaustive `switch` become a compile error until you handle it.
- Interview: explain why `MovieDetailView` takes its ViewModel as a required parameter instead of constructing one itself.

## Phase 3 — Domain, repository, DTO/mapper boundaries

[`Architecture/Phase-03-Domain-and-Repository.md` §17](Learning/Architecture/Phase-03-Domain-and-Repository.md#17-exercises)

- Observe: breakpoint in `DefaultMovieRepository.searchMovies`; confirm it fires once per debounced query and step through the cache write.
- Modify: add `Movie.releaseYear: String?` without touching `MovieSearchDTO`'s decoding shape — only the mapper should need to change.
- Break intentionally: comment out the `catch is CancellationError` block; watch `searchPropagatesCancellationWithoutFallingBackToCache` fail, confirming the test actually exercises the fix.
- Extend: swap in a fake `DefaultMovieRepository` at the coordinator's construction point; feel out how cleanly the DI seam separates production and fake data.
- Interview: explain why `GetMovieDetailUseCase` exists even though it does nothing but forward to the repository.

## Phase 4 — Networking bug fixes, retry, injected interceptor

[`Architecture/Phase-04-Networking.md` §17](Learning/Architecture/Phase-04-Networking.md#17-exercises)

- Observe: breakpoint in `RetryPolicy.shouldRetry`; trigger a search with the simulator offline and see which `URLError.Code` actually arrives.
- Modify: change `RetryPolicy.default.maxAttempts` from 3 to 1; predict whether `retriesTransientFailuresUpToMaxAttemptsThenSucceeds` still passes before running it (it shouldn't).
- Break intentionally: reintroduce the old double-encoding line; confirm `queryParametersAreEncodedExactlyOnce` *still passes* — proof that a test's scope matters, since this one tests `RemoteService` in isolation, not this specific API service.
- Extend: add a new retryable `URLError.Code` and a matching test case.
- Interview: explain why `AuthenticationInterceptor` takes an `AuthHeaderProviding` parameter instead of reading `.shared`, and why that isn't yet Phase 5's full fix.

## Phase 5 — Credentials store and UIKit auth bridge

[`Architecture/Phase-05-Authentication.md` §17](Learning/Architecture/Phase-05-Authentication.md#17-exercises)

- Observe: breakpoint in `CredentialsStore.currentCredentials()`; log in via a properly signed run and confirm the call count.
- Modify: add a `deviceId` field to `CredentialsStore.Credentials`; predict which test file needs new assertions.
- Break intentionally: default `CredentialsStore.init`'s `keychain` parameter back to a live `KeychainStore()`; watch `AppCoordinatorTests` fail with the same `errSecMissingEntitlement` this phase found — concrete proof of what the fix actually buys.
- Extend: write an intermittently-`nil`-returning `SecureKeyValueStoring` fake and prove `isAuthenticated()` degrades to `false` rather than crashing.
- Interview: explain what `errSecMissingEntitlement` means, why this project hits it, and how its tests still verify `CredentialsStore`'s logic despite it.

## Phase 6 — Actor-based caches and request coalescing

[`Architecture/Phase-06-Caching.md` §17](Learning/Architecture/Phase-06-Caching.md#17-exercises)

- Observe: breakpoint in `InFlightRequestStore.value(forKey:operation:)`; rapidly re-request the same detail and confirm the "existing task" branch fires.
- Modify: change `detailMemoryCache`'s TTL from 900s to 5s; predict which test needs its own TTL parameter adjusted.
- Break intentionally: insert `try? await Task.sleep(nanoseconds: 1)` between the check and the register in `InFlightRequestStore`; watch `tenSimultaneousCallsForTheSameKeyShareOneOperationCall`'s counter exceed 1 — the concrete reentrancy bug, reproduced on purpose.
- Extend: add a `CachePolicy.cacheOnly` case; decide, and write down your reasoning, whether it belongs on the fresh or stale read path.
- Interview: explain why `InFlightRequestStore`'s check-and-register logic is safe despite the actor having only one suspension point, and what specifically would break that safety.

## Phase 7 — Combine and cancellation hardening

[`Architecture/Phase-07-Combine-and-Cancellation.md` §17](Learning/Architecture/Phase-07-Combine-and-Cancellation.md#17-exercises)

- Observe: breakpoint inside `setupSearchObserver()`'s `.sink`; type character-by-character and count hits versus characters typed.
- Modify: change the production debounce default from 500ms to 250ms; judge whether search feels more responsive or just noisier — a real product trade-off with no single correct answer.
- Break intentionally: change the "search race" test's Batman delay from 2s to 0s (same speed as Avatar); watch it become flaky — direct evidence of why the delay must comfortably outlast the settle margins.
- Extend: prove that typing a query, clearing it, then typing it again produces two separate calls (not deduplicated across the clear).
- Interview: explain why `Future` was considered and rejected for wrapping the network call in this pipeline.

## Phase 8 — Cached image pipeline

[`Architecture/Phase-08-Image-Pipeline.md` §17](Learning/Architecture/Phase-08-Image-Pipeline.md#17-exercises)

- Observe: breakpoint in `ImageLoader.image(for:)`; scroll a results list up and down and confirm the memory-cache branch is hit for posters already seen.
- Modify: shrink `ImageLoader`'s default `MemoryCache` to `maxEntries: 5`; watch LRU eviction kick in much sooner while scrolling.
- Break intentionally: move `CachedImagePhase` back to being nested inside `CachedAsyncImage<Content>`; reproduce the exact "generic parameter 'Content' could not be inferred" error, then move it back.
- Extend: add a disk cache layer to `ImageLoader` using Phase 6's `DiskCache<Value>`; decide a sensible TTL and write a test proving a memory-miss still avoids the network if disk has the image.
- Interview: explain why `ImageLoaderTests` needed its own `StubImageURLProtocol` instead of reusing Phase 4's `StubURLProtocol`.

## Phase 9 — Strict concurrency, accessibility, CI, and the rename

[`Architecture/Phase-09-Project-Quality.md` §17](Learning/Architecture/Phase-09-Project-Quality.md#17-exercises)

- Observe: confirm `SWIFT_STRICT_CONCURRENCY` appears in all six configuration entries in `project.pbxproj`, not just the app target.
- Modify: add an accessibility identifier to an element that doesn't have one yet; predict what an `XCUIApplication` test using it would look like.
- Break intentionally: remove `@MainActor` from `LoginViewController`; observe the exact diagnostic that returns, then restore it.
- Extend: write the first real critical-path UI test this phase's own comment promised — and reason through what's actually needed to test an authenticated app state without a live Hotstar login.
- Interview: explain why the CI workflow selects the latest available Xcode/simulator at runtime instead of pinning a version, and name the real risk that carries.

## Doing these without the running app

Several "Observe"/"Extend" exercises above assume a running app with a real
(or at least reachable) Hotstar login — not always available depending on
the third-party service's own state (see the top-level `README.md`'s
disclaimer). Where that's blocked, the matching phase's own test suite is
the fallback: every behavior these exercises ask you to observe live is
also covered by at least one passing automated test, named in that phase's
own §11 ("Test evidence").
