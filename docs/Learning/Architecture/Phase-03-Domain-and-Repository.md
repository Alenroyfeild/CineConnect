# Phase 3 — Domain, Repository, DTO and Mapper Boundaries

Status: **Implemented and verified**.

## 1. Previous implementation

`MovieSearchViewModel`/`MovieDetailViewModel` called
`MovieSearchAPIServiceProtocol`/`MovieDetailAPIServiceProtocol` directly.
Those API service classes did four jobs in one method: build the request,
call `RemoteService`, map the decoded DTO to a domain model, *and*
read/write `MovieCache` as a fallback on failure. Domain models (`Movie`,
`MovieDetail`) already lived free of DTO leakage, but under
`Assignment/Models/`, organizationally mixed with the DTOs themselves
(`Assignment/Models/DTOs/`). Mapping (`toMovies()`/`toMovieDetail()`)
was already explicit, as extensions on the DTOs, just not filed separately
from the DTOs' decoding shape.

## 2. Problem

No `MovieRepository` boundary existed, so a ViewModel test wanting to
substitute fake search results had to fake the entire
`MovieSearchAPIServiceProtocol` (including its cache-fallback behavior) at
every call site. The cache-fallback *policy* ("network is truth, fall back
to cache on failure") was duplicated identically in both API services
instead of owned once. And there was a live correctness question nobody had
checked: did that duplicated fallback logic distinguish a genuinely failed
request from a *cancelled* one? (It didn't - see §14.)

## 3. Target responsibility

- `Domain/Models/` - `Movie`/`MovieDetail`, unchanged in content, moved for organization.
- `Domain/MovieRepository.swift` - the data-access boundary use cases depend on.
- `Domain/UseCases/` - `SearchMoviesUseCase` (real query-normalization logic), `GetMovieDetailUseCase` (a deliberately thin pass-through).
- `Data/DefaultMovieRepository.swift` - owns the cache-fallback policy, once.
- `Data/DTOs/`, `Data/Mappers/` - decoding shape and domain-mapping logic, in separate files.
- `MovieSearchAPIService`/`MovieDetailAPIService` - simplified to remote-data-source-only (build request, decode, map; no cache).

## 4. Files introduced

- `Assignment/Domain/Models/Movie.swift`, `MovieDetail.swift` (moved, not new content)
- `Assignment/Domain/MovieRepository.swift`
- `Assignment/Domain/UseCases/SearchMoviesUseCase.swift`
- `Assignment/Domain/UseCases/GetMovieDetailUseCase.swift`
- `Assignment/Data/DTOs/MovieSearchDTO.swift`, `MovieDetailDTO.swift` (moved, decoding-only)
- `Assignment/Data/Mappers/MovieSearchMapper.swift`, `MovieDetailMapper.swift` (moved out of the DTO files)
- `Assignment/Data/DefaultMovieRepository.swift`
- Tests: `AssignmentTests/Fakes/FakeMovieRepository.swift`, `FakeMovieAPIServices.swift`,
  `MovieSearchMapperTests.swift`, `MovieDetailMapperTests.swift`,
  `DefaultMovieRepositoryTests.swift`, `SearchMoviesUseCaseTests.swift`,
  `GetMovieDetailUseCaseTests.swift`, `MovieSearchViewModelTests.swift`,
  `MovieDetailViewModelTests.swift`

## 5. Files modified

- `Assignment/Services/MovieSearchAPIService.swift`, `MovieDetailAPIService.swift` (cache logic removed)
- `Assignment/ViewModels/MovieSearchViewModel.swift` (depends on `SearchMoviesUseCase`, not `MovieSearchAPIServiceProtocol`; `SearchError` now `Equatable`)
- `Assignment/ViewModels/MovieDetailViewModel.swift` (depends on `GetMovieDetailUseCase`; `DetailError` now `Equatable`)
- `Assignment/Coordinators/MoviesCoordinator.swift` (builds repository -> use case -> ViewModel chain)
- `Assignment/Views/MoviesListView.swift`, `MovieDetailView.swift` (preview call sites updated)

## 6. Files removed

`Assignment/Models/` and `Assignment/Models/DTOs/` (emptied by the moves above, then removed as directories).

## 7. Runtime flow before

```
MovieSearchViewModel --apiService--> MovieSearchAPIService
                                        -> build request -> RemoteService -> decode DTO
                                        -> toMovies() (map)
                                        -> cache.saveSearch() on success
                                        -> catch: cache.loadSearch() fallback on ANY error,
                                           including CancellationError (bug - see §14)
```

## 8. Runtime flow after

```
MovieSearchViewModel
  --searchMovies (SearchMoviesUseCase)-->
    trims query, returns nil if empty
    --repository (MovieRepository protocol)-->
      DefaultMovieRepository.searchMovies(query:)
        try remote: searchAPIService.searchVideos(query:)
          -> build request -> RemoteService -> decode MovieSearchDTO
          -> MovieSearchMapper's toMovies()
        on success: cache.saveSearch(...), return movies
        on CancellationError: rethrow immediately, no cache fallback
        on any other error: cache.loadSearch(query:) fallback, else rethrow
```

Numbered, with file/type/method/context:

1. **File:** `MovieSearchViewModel.swift` · **Method:** `search(query:)` ·
   `@MainActor`, inside the already-running `searchTask`.
2. **File:** `SearchMoviesUseCase.swift` · **Method:** `callAsFunction(query:)`
   · normalizes, may return `nil` here (no suspension yet).
3. **File:** `DefaultMovieRepository.swift` · **Method:** `searchMovies(query:)`
   · suspension point: `await searchAPIService.searchVideos(query:)`.
4. **File:** `MovieSearchAPIService.swift` · **Method:** `searchVideos(query:)`
   · suspension point: `await remoteService.execute(request:)` (network I/O).
5. **File:** `MovieSearchMapper.swift` · **Method:** `toMovies()` · synchronous,
   no suspension - pure mapping.
6. Back in `DefaultMovieRepository`: on success, `cache.saveSearch(...)`
   (synchronous, file I/O today - not yet actor-isolated, see §18); on
   failure, checks `is CancellationError` before considering the cache.

**Test covering this full chain:** `MovieSearchViewModelTests` (ViewModel
level, via `FakeMovieRepository`), `DefaultMovieRepositoryTests`
(repository level, via fake API services), `SearchMoviesUseCaseTests`
(use-case level).

## 9. Code excerpts

**Exact production code** (`Assignment/Domain/UseCases/SearchMoviesUseCase.swift`):

```swift
struct SearchMoviesUseCase {
    private let repository: MovieRepository

    init(repository: MovieRepository) {
        self.repository = repository
    }

    func callAsFunction(query: String) async throws -> [Movie]? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return try await repository.searchMovies(query: normalized)
    }
}
```

**Exact production code** (`Assignment/Data/DefaultMovieRepository.swift`,
the cancellation-vs-failure distinction):

```swift
func searchMovies(query: String) async throws -> [Movie] {
    do {
        let movies = try await searchAPIService.searchVideos(query: query)
        cache.saveSearch(movies, query: query)
        return movies
    } catch is CancellationError {
        throw CancellationError()
    } catch {
        if let cached = cache.loadSearch(query: query) {
            return cached
        }
        throw error
    }
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

One real warning batch was hit and fixed during this phase: the project's
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` setting means `Movie`,
`MovieSearchDTO`, `DefaultMovieRepository`, etc. are all implicitly
`@MainActor`-isolated; new test `struct`s that weren't themselves marked
`@MainActor` produced "main actor-isolated ... cannot be called from
outside the actor; this is an error in the Swift 6 language mode" warnings
across six new test files. Fixed by adding `@MainActor` to each affected
`@Suite`, matching the pattern already used by `AppCoordinatorTests`/
`MoviesCoordinatorTests` from Phase 1/2.

## 11. Test evidence

40 tests total, all passing. New in this phase: `MovieSearchMapperTests`
(5), `MovieDetailMapperTests` (4), `DefaultMovieRepositoryTests` (5),
`SearchMoviesUseCaseTests` (5), `GetMovieDetailUseCaseTests` (2),
`MovieSearchViewModelTests` (5), `MovieDetailViewModelTests` (3) — 29 new
tests on top of the 10 existing ones (was 10, is 40 — one existing test,
`AssignmentTests.movieModelIsHashableAndCodable`, plus the smoke test,
account for the remaining count alongside the previous phases' 8).

## 12. Alternatives

Required comparison, from simplest to most elaborate:

1. **ViewModel calls the API service directly** (the pre-Phase-3 state).
   Simplest; appropriate for a prototype or a single-screen app with no
   caching/testing needs. Breaks down the moment you want to fake network
   behavior in a test without also faking cache fallback.
2. **ViewModel calls the repository directly** (skip use cases entirely).
   A reasonable middle ground for `MovieDetailViewModel`, honestly — see
   §15's discussion of `GetMovieDetailUseCase` being thin. Chosen *not* to
   do this, so every ViewModel has a consistent dependency shape
   (use case), even where today's use case is a pass-through.
3. **ViewModel calls a use case** (chosen for this project). Gives
   `SearchMoviesUseCase` a real home for query normalization, and gives
   every ViewModel the same shape regardless of whether a given use case
   is currently "thick" (search) or "thin" (detail).
4. **Full Clean Architecture with many fine-grained use cases** (e.g.
   separate `ValidateSearchQueryUseCase`, `FormatSearchResultsUseCase`,
   etc.). Rejected: for a two-screen app, this fragments simple logic
   across many one-method types with no real substitution or testing
   benefit over keeping it in one use case per screen — exactly the
   "wrapping every method in a use case" antipattern the project's own
   rules warn against.
5. **This project's actual choice**: one use case per screen-level
   operation, a single repository protocol with one implementation, and no
   deeper Clean Architecture layering than that - pragmatic, feature-first.

## 13. Trade-offs

Moving cache-fallback ownership into `DefaultMovieRepository` means the
API services no longer need a `cache: MovieCache` dependency at all — a net
simplification — but it also means `DefaultMovieRepository` now has two
real responsibilities (data-source coordination *and* cache-fallback
policy) rather than one. Accepted because those two responsibilities are
exactly what "repository" is supposed to mean here; splitting them further
would be premature before Phase 6's actor-based cache exists to justify a
third collaborator.

## 14. Failure scenarios

**Found and fixed during this phase, not merely inherited:** the pre-Phase-3
cache-fallback code (`catch { if let cached = cache.loadSearch(...) { return
cached } }`) would have treated a *cancelled* request the same as a
*failed* one - returning stale cached data instead of letting the
cancellation propagate. `DefaultMovieRepositoryTests.searchPropagatesCancellationWithoutFallingBackToCache`
proves the fixed behavior: a `CancellationError` is rethrown immediately,
never consulting the cache.

**Search race** (`MovieSearchViewModelTests.newQueryCancelsStaleInFlightSearch`):
user types "Batman" (debounce fires, a 3-second artificially-delayed fake
request starts), then types "Avatar" before Batman's request completes.
Avatar's debounce firing cancels `MovieSearchViewModel.searchTask`, which
cancels Batman's in-flight `Task` — and even if cancellation were somehow
not honored promptly, `search(query:)`'s `guard latest == query` staleness
check would still reject a late Batman response, since `searchText` no
longer equals `"batman"` by then. The test asserts the final state is
Avatar's results, never Batman's.

## 15. Interview Q&A

### Why did you introduce a repository?

**Strong answer:** Two API service classes were each doing request
building, decoding, mapping, *and* cache-fallback — the same fallback
policy duplicated twice. `MovieRepository`/`DefaultMovieRepository` gives
that policy one home, and gives ViewModels a boundary they can fake in
tests without also faking caching behavior.

**Code evidence:**
- `Assignment/Domain/MovieRepository.swift`
- `Assignment/Data/DefaultMovieRepository.swift`
- Tests: `DefaultMovieRepositoryTests` (5 tests)

**Follow-up question:** Why not call the API service directly from the ViewModel?

**Follow-up answer:** That's exactly the pre-Phase-3 state — it worked, but
meant `MovieSearchViewModelTests` (had they existed then) would need a
fake conforming to `MovieSearchAPIServiceProtocol` that *also* correctly
implements cache-fallback semantics, duplicating the repository's own job
inside a test double.

**Senior counter-question:** Isn't the repository just forwarding methods?

**Counter-answer:** For `movieDetail(slug:)`, today, almost — but it does
own one real thing: the network-vs-cache decision, plus (as of this phase)
correctly *not* falling back to cache on cancellation. For
`searchMovies(query:)`, same plus it's the seam
`SearchMoviesUseCase` depends on instead of a concrete API service.
It's a fair challenge, and the honest answer is "today it's thin *plus* one
real correctness fix," not "it does a ton."

**Trade-off:** A repository with only one implementation and modest current
logic is more ceremony than a direct API-service call — justified here by
the testing seam it creates and the correctness bug it let me find and fix
in one place instead of two.

**Failure scenario:** Without the repository, fixing the
cancellation-vs-cache bug found in this phase would have meant editing (and
testing) it twice — once in `MovieSearchAPIService`, once in
`MovieDetailAPIService` — with a real chance of fixing one and missing the
other, as duplicated logic almost always eventually does.

**Weak answer:** "A repository separates the API code."

**Improved answer:** Names the actual duplicated policy it removed
(cache-fallback), the actual bug fixed while doing so (cancellation
mishandling), and the actual test it enabled
(`DefaultMovieRepositoryTests` faking the API service layer without
faking the cache-decision layer too).

### When do use cases become unnecessary pass-through wrappers?

**Strong answer:** `GetMovieDetailUseCase` in this exact codebase is the
honest example: it does nothing but call
`repository.movieDetail(slug:)`. It's kept anyway, for consistency (every
ViewModel depends on a use case, not a repository, so the pattern doesn't
have exceptions a reader has to remember) — but it's explicitly documented
in its own file as a deliberate pass-through, not presented as if it were
doing real work.

**Code evidence:**
- `Assignment/Domain/UseCases/GetMovieDetailUseCase.swift` (its own doc comment says exactly this)
- Contrast: `Assignment/Domain/UseCases/SearchMoviesUseCase.swift`, which owns real query-normalization logic

**Follow-up question:** So why not just delete `GetMovieDetailUseCase` and
have `MovieDetailViewModel` depend on `MovieRepository` directly?

**Follow-up answer:** A legitimate alternative (see §12, option 2) — not
done here purely for dependency-shape consistency across ViewModels, which
is a real but modest benefit, honestly weighed against the extra
indirection.

**Senior counter-question:** Isn't "consistency" a weak justification for
an abstraction with zero current behavior?

**Counter-answer:** It's the weakest of the reasons documented anywhere in
this codebase for an abstraction, and it's labeled that way rather than
dressed up — a good test of whether this migration's documentation is
honest is exactly whether it admits this instead of inventing false value
for `GetMovieDetailUseCase`.

**Trade-off:** One extra type and one extra layer of indirection to read
through, for a consistency benefit that's real but small.

**Failure scenario:** If someone deleted `GetMovieDetailUseCase` believing
it justified its existence purely by "Clean Architecture requires a use
case here," they'd be removing dead weight for a bad reason (dogma) that
happens to be a defensible outcome anyway — the point being: know *why*
you're keeping or removing it.

## 16. Counter-questions

- "Could `SearchMoviesUseCase`'s trim/empty-check just live in the
  ViewModel instead, with no use case at all?" Yes, mechanically — see
  the `MovieSearchViewModel.setupSearchObserver` doc comment for why
  there's *also* a check in the ViewModel (loading-spinner timing), which
  is a distinct, presentation-specific reason to have its own check even
  if the use case does too.
- "Why does `DefaultMovieRepository` take `cache: MovieCache = .shared` as
  a default parameter — isn't that the same singleton-default problem
  Phase 1 fixed?" A fair challenge: unlike the coordinator defaults (which
  hid *which type* was authoritative), `MovieCache` here is still the
  literal, unreplaced Phase-0 cache implementation - Phase 6 replaces it
  with actor-based caches, at which point this default gets removed the
  same way the coordinators' did.

## 17. Exercises

**Observe:** Set a breakpoint in `DefaultMovieRepository.searchMovies`.
Search for a movie in the running app, confirm it's hit once per debounced
query, and step through the cache write on success.

**Modify:** Add a new field to `Movie` (e.g., `let releaseYear: String?`)
without touching `MovieSearchDTO`'s decoding shape at all — only
`MovieSearchMapper.toMovies()` should need to change to populate it (from
existing decoded data if available, or a stub). This is the concrete
exercise behind "why domain models must not depend on API response
structure."

**Break intentionally:** Comment out the `catch is CancellationError` block
in `DefaultMovieRepository.searchMovies` and re-run
`DefaultMovieRepositoryTests.searchPropagatesCancellationWithoutFallingBackToCache`
— watch it fail, confirming the test actually exercises the fix. Restore
the fix afterward.

**Extend:** Replace `DefaultMovieRepository` with a fake in
`MoviesCoordinator.makeMovieRepository()` (temporarily) to make the whole
app run against canned data with no network at all — a good way to feel
out how cleanly the DI seam actually separates production and fake data.

**Interview:** Without re-reading this document, explain why
`GetMovieDetailUseCase` exists even though it does nothing but forward to
the repository.

## 18. Remaining limitations

`MovieCache` is still a plain class, not an actor (Phase 6). No
`CachePolicy` parameter exists on `MovieRepository` yet — only one implicit
policy (network-first, cache-on-failure) is possible (documented in
`MovieRepository`'s own doc comment). `MovieSearchAPIService`'s
double-percent-encoding bug and `RemoteService`'s `isSuccess` bug are
unchanged (Phase 4). `MoviesCoordinator` still constructs
`MovieSearchAPIService()`/`MovieDetailAPIService()` concretely inside
`makeMovieRepository()` — an injected, protocol-backed networking layer is
Phase 4's job.

---

# Before/after: ViewModel-to-network coupling

## Before

```swift
final class MovieSearchViewModel: ObservableObject {
    private let apiService: MovieSearchAPIServiceProtocol
    init(apiService: MovieSearchAPIServiceProtocol) { self.apiService = apiService }

    private func search(query: String) async {
        let response = try await apiService.searchVideos(query: query)
        ...
    }
}

class MovieSearchAPIService: BaseAPIService, MovieSearchAPIServiceProtocol {
    private let cache: MovieCache
    func searchVideos(query: String) async throws -> [Movie] {
        do {
            let dto: MovieSearchDTO = try await remoteService.execute(...)
            let movies = dto.toMovies()
            cache.saveSearch(movies, query: query)
            return movies
        } catch {
            if let cached = cache.loadSearch(query: query) { return cached }  // also catches CancellationError!
            throw error
        }
    }
}
```

Problems:
- Cache-fallback policy duplicated identically in `MovieDetailAPIService`.
- A test faking `MovieSearchAPIServiceProtocol` has to also correctly fake
  cache-fallback behavior to be realistic.
- A cancelled request and a genuinely failed one were handled identically
  - a real, unnoticed correctness bug until this phase's tests found it.

## After

```swift
final class MovieSearchViewModel: ObservableObject {
    private let searchMovies: SearchMoviesUseCase
    init(searchMovies: SearchMoviesUseCase) { self.searchMovies = searchMovies }

    private func search(query: String) async {
        guard let response = try await searchMovies(query: query) else { return }
        ...
    }
}

struct SearchMoviesUseCase {
    private let repository: MovieRepository
    func callAsFunction(query: String) async throws -> [Movie]? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return try await repository.searchMovies(query: normalized)
    }
}

final class DefaultMovieRepository: MovieRepository {
    func searchMovies(query: String) async throws -> [Movie] {
        do {
            let movies = try await searchAPIService.searchVideos(query: query)
            cache.saveSearch(movies, query: query)
            return movies
        } catch is CancellationError {
            throw CancellationError()   // fixed: no longer masked by the cache fallback
        } catch {
            if let cached = cache.loadSearch(query: query) { return cached }
            throw error
        }
    }
}
```

- Who now creates each piece: `MoviesCoordinator.makeMovieRepository()`
  builds the repository; `makeSearchViewModel()`/`makeDetailViewModel()`
  wrap it in the appropriate use case.
- How tests substitute behavior: `FakeMovieRepository` for use-case/
  ViewModel tests; `FakeMovieSearchAPIService`/`FakeMovieDetailAPIService`
  for repository-level tests — two distinct substitution points instead of
  one entangled one.
