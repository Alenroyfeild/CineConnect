# Phase 6 — Actor-Based Caches and Request Coalescing

Status: **Implemented and verified**.

## 1. Previous implementation

`MovieCache` (`CineConnect/Services/Cache/MovieCache.swift`) was a plain
`class`, not an actor: one flat disk cache, no TTL, no eviction, no
in-flight request deduplication, consulted only as a fallback when the
network call failed (Phase 3's `DefaultMovieRepository` orchestrated this).
`DefaultMovieRepository.makeMovieRepository()` was called separately for
the search and detail ViewModels inside `MoviesCoordinator`, meaning each
screen got its *own* repository instance.

## 2. Problem

No TTL meant a cached entry never expired - stale data could be returned
indefinitely under `.networkFirst`'s failure path. No eviction meant
unbounded growth. No request coalescing meant ten near-simultaneous
identical requests (e.g., a list row and a preloaded detail both wanting
the same movie) would each trigger their own network call. And a problem
*this phase's own design work surfaced*, not inherited: building
per-instance cache actors would have been pointless if
`MoviesCoordinator` kept building a fresh `DefaultMovieRepository` (and
therefore fresh, empty caches) every time `makeDetailViewModel()` ran -
which it did, once per navigation to any detail screen.

## 3. Target responsibility

`MemoryCache<Key, Value>` (TTL, LRU eviction, hit/miss tracking).
`DiskCache<Value>` (TTL, atomic writes, corrupt-file recovery) for movie
detail only. `InFlightRequestStore<Key, Value>` (request coalescing) for
both search and detail. `CachePolicy` (three genuinely distinct
behaviors). `MoviesCoordinator` now builds one `DefaultMovieRepository`
per coordinator lifetime, not per screen.

## 4. Files introduced

- `CineConnect/Caching/CachePolicy.swift`
- `CineConnect/Caching/MemoryCache.swift`
- `CineConnect/Caching/DiskCache.swift`
- `CineConnect/Caching/InFlightRequestStore.swift`
- Tests: `CineConnectTests/MemoryCacheTests.swift`, `DiskCacheTests.swift`,
  `InFlightRequestStoreTests.swift`, `CineConnectTests/Fakes/MutableClock.swift`

## 5. Files modified

- `CineConnect/Domain/MovieRepository.swift` (`policy` parameter, default-implementing extension, `clearCaches()`)
- `CineConnect/Data/DefaultMovieRepository.swift` (rewritten around the L0-L2 cache stack)
- `CineConnect/Domain/Models/Movie.swift`, `MovieDetail.swift` (`Sendable`, `nonisolated` - see §10)
- `CineConnect/Services/MovieSearchAPIService.swift`, `MovieDetailAPIService.swift` (protocols now `Sendable`)
- `CineConnect/Coordinators/MoviesCoordinator.swift` (one repository instance per coordinator; `performLogout()` clears caches)
- `CineConnectTests/Fakes/FakeMovieRepository.swift`, `FakeMovieAPIServices.swift` (updated for the new protocol shape)
- `CineConnectTests/DefaultMovieRepositoryTests.swift` (rewritten for the new architecture)

## 6. Files removed

`CineConnect/Services/Cache/MovieCache.swift` (fully replaced).

## 7. Runtime flow before

```
MoviesCoordinator.makeDetailViewModel()
  -> makeMovieRepository()                    // NEW repository, NEW cache, every navigation
       DefaultMovieRepository(cache: MovieCache.self-managed-instance)
         .movieDetail(slug:)
           try detailAPIService.fetchMovieDetail(slug:)   // no coalescing
           catch { cache.loadDetail(slug:) }               // flat disk cache, no TTL
```

## 8. Runtime flow after

```
MoviesCoordinator.init                         // ONE repository built here, lives for the coordinator's lifetime
  movieRepository = DefaultMovieRepository(...)

...later, any number of navigations to any detail screen...
MoviesCoordinator.makeDetailViewModel()
  -> GetMovieDetailUseCase(repository: movieRepository)    // same instance, same caches

DefaultMovieRepository.movieDetail(slug:, policy: .networkFirst)
  do {
    fetchAndCacheDetail(slug:)
      detailInFlight.value(forKey: slug) { ... }            // L0: coalesce concurrent identical requests
        detailAPIService.fetchMovieDetail(slug:)             // network
        detailMemoryCache.setValue(...)                      // L1 write-through
        detailDiskCache.setValue(...)                        // L2 write-through
  } catch is CancellationError { throw CancellationError() }
  } catch {
    detailMemoryCache.staleValue(forKey: slug) ?? detailDiskCache.value(forKey: slug)  // fallback, in that order
  }
```

Numbered, with file/type/method/context:

1. **File:** `MoviesCoordinator.swift` · `init` · `@MainActor`, synchronous
   construction - the repository and its cache actors exist for the whole
   app session (via `AppCoordinator`'s ownership).
2. **File:** `DefaultMovieRepository.swift` · `movieDetail(slug:policy:)` ·
   dispatches on `policy`, no suspension yet.
3. **File:** `InFlightRequestStore.swift` · `value(forKey:operation:)` ·
   suspension point: `await task.value` - see §9/§15 for the reentrancy
   walkthrough.
4. **File:** `MovieDetailAPIService.swift` · `fetchMovieDetail(slug:)` ·
   suspension point: the actual network call.
5. **File:** `MemoryCache.swift` / `DiskCache.swift` · `setValue(_:forKey:)`
   · suspension points crossing into each actor's isolation domain -
   write-through happens on success before returning.

**Tests covering this full chain:** `DefaultMovieRepositoryTests` (14),
`MemoryCacheTests` (8), `DiskCacheTests` (5), `InFlightRequestStoreTests` (4).

## 9. Code excerpts

**Exact production code** (`CineConnect/Caching/InFlightRequestStore.swift`,
the coalescing logic itself):

```swift
func value(forKey key: Key, operation: @Sendable @escaping () async throws -> Value) async throws -> Value {
    if let existingTask = tasksByKey[key] {
        return try await existingTask.value
    }
    let task = Task { try await operation() }
    tasksByKey[key] = task
    defer { tasksByKey[key] = nil }
    return try await task.value
}
```

**Exact production code** (`CineConnect/Caching/CachePolicy.swift`):

```swift
enum CachePolicy: Sendable {
    case networkFirst
    case cacheFirst
    case reloadIgnoringCache
}
```

## 10. Build evidence

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CineConnect.xcodeproj -scheme CineConnect \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean test
```
Result: **BUILD SUCCEEDED**, **TEST SUCCEEDED**, 0 warnings, 102/102 tests
passing.

**The recurring compiler-inference pattern hit again, more sharply this
time:** `MemoryCache<String, MovieDetail>` failed to compile with *"main
actor-isolated conformance of 'MovieDetail' to 'Decodable' cannot satisfy
conformance requirement for a 'Sendable' type parameter."* This is the
same `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `InferIsolatedConformances`
interaction seen as smaller warnings in Phases 1/3/4/5, but here it
blocked compilation outright: the project's default isolation setting
infers even a plain data model's own protocol conformances
(`Decodable`, in this case) as `@MainActor`-isolated unless told
otherwise, which then can't satisfy a generic actor's `Sendable`
constraint from outside the main actor. Fixed by marking `Movie` and
`MovieDetail` `nonisolated struct` - a plain data model has no reason to
be actor-isolated at all, and this is the clearest, most direct case yet
for why: two of this app's core domain models literally could not be
stored in a generic cache actor without it.

Three smaller issues in the same family, also fixed in this phase:
- `DiskCache.fileManager`: `FileManager` isn't `Sendable` in the SDK's own
  annotations, so a plain `nonisolated let` didn't work either -
  `nonisolated(unsafe)` was used instead, justified by Apple's own
  documentation that `FileManager.default` is safe for concurrent use.
- `MovieSearchAPIServiceProtocol`/`MovieDetailAPIServiceProtocol` needed
  `: Sendable` added, since `DefaultMovieRepository` now captures values of
  these types inside `@Sendable` closures passed to `InFlightRequestStore`.
- `FakeMovieSearchAPIService`/`FakeMovieDetailAPIService` (test fakes)
  needed `@unchecked Sendable`, justified by the "configured once before
  concurrent use, never mutated during it" pattern already established for
  other fakes in this codebase.

One real test bug was also found and fixed during this phase: an early
version of `MemoryCacheTests.staleValueIsReturnedEvenAfterExpiry` checked
the *fresh* read (`value(forKey:)`, which evicts on expiry) before the
*stale* read (`staleValue(forKey:)`) - by the time the stale check ran,
the fresh check had already deleted the entry, so the test failed for a
reason unrelated to what it was trying to prove. Fixed by reordering: the
non-evicting stale check first, then the evicting fresh check - which
also incidentally strengthens the test (it now proves a stale read
doesn't *prevent* a later fresh read from correctly detecting expiry).

## 11. Test evidence

102 tests total (was 76), all passing. New this phase: `MemoryCacheTests`
(8 - miss, hit, expiry+eviction, stale-vs-fresh, hit/miss counting, LRU
eviction, touch-protects-from-eviction, clear-all), `DiskCacheTests` (5 -
miss, hit, expiry+file-removal, corrupt-file recovery, clear-all),
`InFlightRequestStoreTests` (4 - ten-concurrent-callers coalescing,
different-keys-proceed-concurrently, failed-task-removed-so-next-call-retries,
completed-task-removed-so-second-call-runs-fresh). `DefaultMovieRepositoryTests`
expanded from 5 to 14 tests covering all three `CachePolicy` cases,
memory/disk fallback ordering, cancellation-vs-cache (still protected),
ten-concurrent-identical-detail-requests-one-network-call, and
`clearCaches()`.

## 12. Alternatives

1. **A single generic `Cache<Key, Value>` actor doing both memory and
   disk.** Rejected: memory and disk have genuinely different failure
   modes (disk can be corrupt; memory can't) and different appropriate
   TTLs for this app's two use cases - two focused types are clearer than
   one type with a "useDisk: Bool" flag.
2. **`.returnCacheElseLoad` as a fourth `CachePolicy` case.** Rejected -
   see `CachePolicy`'s own doc comment: it would behave almost identically
   to `.cacheFirst`, and the migration's own rules warn against adding
   policies without a clearly different behavior.
3. **A single repository instance shared across the *entire app*
   (composition-root-owned) instead of per-`MoviesCoordinator`.**
   Considered - functionally similar today since `MoviesCoordinator`
   itself lives for the whole app session via `AppCoordinator`. Kept at
   the coordinator level because the movies feature's data layer belongs
   to the movies feature, not the app-wide composition root; moving it up
   would blur that boundary for no current benefit.
4. **Array-based LRU tracking in `MemoryCache` vs. a proper doubly-linked
   list.** The array (`accessOrder: [Key]`, `removeAll { $0 == key }` on
   every touch) is O(n) per access - fine at this app's actual scale
   (tens of cached queries/details, not millions), called out explicitly
   in the type's own doc comment as a real trade-off, not hidden.

## 13. Trade-offs

`MemoryCache`/`DiskCache`/`InFlightRequestStore` are generic, which adds a
small amount of type-parameter ceremony (`MemoryCache<String, [Movie]>`)
in exchange for one implementation shared across search and detail instead
of two near-duplicate concrete caches.

## 14. Failure scenarios

**Duplicate detail request** (a scenario named in the original migration
brief): `InFlightRequestStoreTests.tenSimultaneousCallsForTheSameKeyShareOneOperationCall`
and `DefaultMovieRepositoryTests.tenConcurrentIdenticalDetailRequestsResultInOneRemoteCall`
both prove this directly - ten concurrent callers for the same slug
produce exactly one network call and one `CallCounter` increment.

**Actor reentrancy** (required by the migration brief to have a concrete
example - this is it): `InFlightRequestStore.value(forKey:operation:)` has
exactly one suspension point (`await task.value`), which happens *after*
the new task is already registered in `tasksByKey`. Because the
check-existing/register-new logic has no `await` in between, it's atomic
from the actor's perspective - no interleaved call can ever see a
"half-registered" state. A **broken** version, for contrast (this is the
"break intentionally" exercise in §17): inserting `await Task.yield()`
between the `if let existingTask` check and `tasksByKey[key] = task` would
let two concurrent callers for the same key both observe "no task yet"
and each register their own - defeating coalescing entirely, silently
(no crash, just two network calls instead of one).

**Logout during an active detail request**: `MoviesCoordinator.performLogout()`
calls `movieRepository.clearCaches()` - if a detail request is still
in-flight when this runs, `InFlightRequestStore` isn't touched by
`clearCaches()` (only the memory/disk caches are cleared), so the
in-flight `Task` completes normally and write-through happens as usual
into the now-empty caches, immediately re-populating one entry post-logout.
This is a real, minor gap: `clearCaches()` doesn't cancel in-flight
requests, only clears already-stored data - tracked in §18, not
silently accepted as correct.

## 15. Interview Q&A

### Why does `InFlightRequestStore` need to be an actor, and what's the reentrancy risk if it weren't done carefully?

**Strong answer:** Two concurrent callers must never both decide "no
request is in flight for this key" and each start their own - that's
exactly what request coalescing exists to prevent. An actor's serial
execution model makes the check-and-register step atomic, *provided*
there's no `await` between the check and the register - which this
implementation deliberately has none of.

**Code evidence:**
- `CineConnect/Caching/InFlightRequestStore.swift`
- Test: `InFlightRequestStoreTests.tenSimultaneousCallsForTheSameKeyShareOneOperationCall`

**Follow-up question:** What would break if you inserted an `await`
between the check and the register?

**Follow-up answer:** Every concurrent caller could interleave in that gap,
each seeing "no task yet," each registering and starting its own -
coalescing would silently stop working (no error, no crash, just N
network calls instead of 1). This is exactly §14's "break intentionally"
exercise.

**Senior counter-question:** Your `defer { tasksByKey[key] = nil }` runs
when the *original* caller's function returns - what happens to the other
nine callers that got `existingTask` and are still awaiting it when that
defer fires?

**Counter-answer:** Nothing happens to them - they hold a direct reference
to the `Task` object itself (captured in their own local `existingTask`
variable), not a live lookup into `tasksByKey`. Removing the dictionary
entry only affects the *next* caller for that key, who will correctly
start a fresh request instead of awaiting a task that's already finished.

**Trade-off:** The dictionary only ever holds *in-flight* tasks - a
deliberate choice (see `defer`'s own comment) so a failed request doesn't
keep returning the same cached failure to every future caller forever.

**Failure scenario:** Named explicitly in the migration brief and tested
directly - `DefaultMovieRepositoryTests.tenConcurrentIdenticalDetailRequestsResultInOneRemoteCall`.

**Weak answer:** "Actors prevent race conditions."

**Improved answer:** Names the exact race being prevented (duplicate task
registration), the exact code shape that prevents it (no `await` between
check and register), and the exact test that would catch a regression.

### Why do search results get memory-only caching while movie details get memory *and* disk?

**Strong answer:** Search results are cheap and fast to re-fetch, and
change with almost every keystroke - persisting them across app launches
buys little. A movie's detail page is comparatively stable and more
expensive to lose - worth surviving a memory warning or a relaunch.

**Code evidence:**
- `CineConnect/Domain/MovieRepository.swift`'s doc comment (states this reasoning directly)
- `CineConnect/Data/DefaultMovieRepository.swift` - `searchMemoryCache` only vs. `detailMemoryCache` + `detailDiskCache`

**Follow-up question:** Could this cause a visible inconsistency - e.g.,
a cached detail screen surviving a relaunch while its originating search
results don't?

**Follow-up answer:** Yes, and that's an accepted, minor UX trade-off, not
an oversight - navigating back to search after a relaunch just re-searches
(fast, cheap), while a previously-viewed detail screen loads instantly
from disk.

**Senior counter-question:** Why not just give both the same TTL and same
layers for consistency, even if search doesn't strictly need disk?

**Counter-answer:** That would add disk I/O and file management for data
that's rarely worth persisting, for the sake of a symmetry with no real
user-facing benefit - the migration's own rules warn against uniform
abstraction for its own sake.

**Trade-off:** Documented above.

**Failure scenario:** None distinct from normal cache-miss behavior - a
relaunch with no persisted search results just means the first search
after launch is a normal network call, same as ever.

## 16. Counter-questions

- "Why is `MemoryCache`'s LRU list a plain array instead of a real linked
  list?" See §12, alternative 4 - correct trade-off at this app's actual
  scale, called out explicitly rather than silently accepted as optimal.
- "What would break if `MoviesCoordinator` went back to building a new
  repository per screen?" Caching would still *work* per-screen-visit, but
  every new detail screen would start with cold, empty caches - exactly
  the bug this phase's own design work found and fixed before it shipped
  (see §2).

## 17. Exercises

**Observe:** Set a breakpoint in `InFlightRequestStore.value(forKey:operation:)`.
Rapidly tap the same search result twice before its detail screen loads
(if the UI allows it) and confirm the breakpoint's "existing task" branch
fires for the second tap.

**Modify:** Change `detailMemoryCache`'s TTL from 900 seconds to 5 seconds
in `DefaultMovieRepository.init`'s default. Predict which existing test
would need its own TTL adjusted to keep passing (`DefaultMovieRepositoryTests`'s
`makeRepository` helper already takes `detailTTL` as a parameter for
exactly this reason).

**Break intentionally:** In `InFlightRequestStore.value(forKey:operation:)`,
insert `try? await Task.sleep(nanoseconds: 1)` between the `if let
existingTask` check and `tasksByKey[key] = task`. Re-run
`InFlightRequestStoreTests.tenSimultaneousCallsForTheSameKeyShareOneOperationCall`
and watch `counter.count` become greater than 1 - concrete proof of the
reentrancy bug described in §14. Remove the sleep afterward.

**Extend:** Add a `CachePolicy.cacheOnly` case that returns a cached value
or throws (never touches the network) - useful for an "offline mode"
toggle. Decide, and write down your reasoning, whether it belongs in
`MemoryCache`/`DiskCache`'s fresh (`value`) or stale (`staleValue`) read.

**Interview:** Without re-reading this document, explain why
`InFlightRequestStore`'s check-and-register logic is safe from a race
condition despite being an actor with only "one suspension point," and
what specifically would break that safety.

## 18. Remaining limitations

`clearCaches()` doesn't cancel in-flight requests (§14) - a request that
started before logout can still write into the freshly-cleared cache
after logout completes. `MemoryCache`'s LRU implementation is O(n) per
access (§12) - fine at this app's scale, would need a real linked-list
structure at a much larger one. No memory-warning observer exists yet to
proactively clear `MemoryCache` under system pressure (relies on normal
TTL/LRU eviction only). `CachePolicy.reloadIgnoringCache` has no UI
trigger yet (Phase 9's pull-to-refresh is the intended consumer).
