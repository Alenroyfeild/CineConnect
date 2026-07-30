# File Index

Every meaningful source and test file, eventually. Files appear here once
they're touched by the real-time documentation workflow — this is not a
complete inventory of the whole repository yet (see
`CURRENT_IMPLEMENTATION.md` for what's still pending). Renamed/removed files
are never left referenced here under their old name.

## Summary table

| File | Layer | Type | Responsibility | Created by | Dependencies | Used by | Tests | Interview concepts |
|---|---|---|---|---|---|---|---|---|
| `Assignment/App/AppDependencyContainer.swift` | App/Composition | `final class` | Composition root; owns `AuthManager`, builds `AppCoordinator` | CC7 | `AuthManager` | `AssignmentApp` | `AppCoordinatorTests.dependencyContainerWiresACoordinator` | DI, composition root, default-argument actor isolation |
| `Assignment/Coordinators/Coordinator.swift` | App/Navigation | `protocol` | Common `makeView()` contract for coordinators | CC1 | — | `AppCoordinator`, `AuthenticationCoordinator`, `MoviesCoordinator` | Indirectly, via conforming types | `associatedtype`, `@MainActor` protocols |
| `Assignment/Coordinators/AppCoordinator.swift` | App/Navigation | `final class`, `@MainActor`, `ObservableObject` | Chooses `.auth`/`.movies` root, owns both child coordinators | CC1, refactored CC7 | `AuthManager`, `AuthenticationCoordinator`, `MoviesCoordinator` | `AssignmentApp` | `AppCoordinatorTests` (5 of 6) | State-driven root switching, `@Published private(set)` |
| `Assignment/Coordinators/AuthenticationCoordinator.swift` | Authentication | `final class`, `@MainActor` | Creates the login flow, forwards completion | CC1 as `AuthCoordinator`, renamed+refactored CC7 | `AuthManager`, `LoginView` | `AppCoordinator` | `AppCoordinatorTests.authCoordinatorCompletionBubblesToAppCoordinator` | Closures as a SwiftUI↔coordinator bridge |
| `Assignment/Coordinators/MoviesCoordinator.swift` | Movies/Navigation | `final class`, `@MainActor`, `ObservableObject` | Owns `NavigationPath`, resolves `MoviesRoute`, constructs feature ViewModels | CC1, refactored CC2/CC8 | `AuthManager`, `MoviesRoute`, `MovieSearchViewModel`, `MovieDetailViewModel`, API services | `AppCoordinator` | `MoviesCoordinatorTests`, `AppCoordinatorTests.moviesCoordinatorLogoutBubblesToAppCoordinator` | Typed routes, explicit `NavigationPath`, coordinator-as-factory |
| `Assignment/Coordinators/MoviesRoute.swift` | Movies/Navigation | `enum: Hashable` | Typed navigation destination for the movies feature | CC8 | `Movie` | `MoviesCoordinator`, `MoviesListView` | `MoviesCoordinatorTests.appendingDetailRouteGrowsPath` | `Hashable` routes vs. raw model as nav value |
| `Assignment/ViewModels/MovieSearchViewModel.swift` | Presentation | `final class`, `@MainActor`, `ObservableObject` | Search text pipeline, results/loading/error state | Pre-existing, injection added CC8 | `MovieSearchAPIServiceProtocol` | `MoviesListView`, `MoviesCoordinator` | None dedicated yet (Phase 3 gap) | Combine debounce, `Task` cancel-on-new-query, stale-result guard |
| `Assignment/ViewModels/MovieDetailViewModel.swift` | Presentation | `final class`, `@MainActor`, `ObservableObject` | Detail load/loading/error state | Pre-existing, injection added CC8 | `MovieDetailAPIServiceProtocol` | `MovieDetailView`, `MoviesCoordinator` | None dedicated yet (Phase 3 gap) | `Task` cancellation via `.task(id:)`, `CancellationError` handling |
| `Assignment/Views/Login/LoginViewController.swift` | Authentication/UIKit | `class: UIViewController` | WebKit login flow, credential extraction | Pre-existing, injected-`AuthManager` + pure-extraction rework Phase 5 | `AuthManager` (injected), `HotstarCredentialExtractor`, `WebDataClearingService` | `LoginView` | `HotstarCredentialExtractorTests` (indirectly, its extracted logic) | SwiftUI↔UIKit bridge, `WKNavigationDelegate`, no more `.shared` reference |
| `Assignment/Views/Login/LoginView.swift` | Authentication/UIKit | `struct: UIViewControllerRepresentable` | Bridges `LoginViewController` into SwiftUI | Pre-existing, threads `authManager` Phase 5 | `LoginViewController`, `AuthManager` | `AuthenticationCoordinator` | None | `makeUIViewController`/`updateUIViewController`, closure-based event bridge |
| `AssignmentTests/AppCoordinatorTests.swift` | Tests | `@Suite(.serialized) struct` | Coordinator routing tests | CC7 | `AppCoordinator`, `AuthManager.shared` | — | (is the test) | Integration test against a real singleton; `.serialized` to prevent races |
| `AssignmentTests/MoviesCoordinatorTests.swift` | Tests | `struct` | Navigation path tests | CC8 | `MoviesCoordinator`, `MoviesRoute` | — | (is the test) | `NavigationPath.count`/`isEmpty` as the only inspectable state |
| `Assignment/Domain/MovieRepository.swift` | Domain | `protocol` | Data-access boundary for the movies feature | Phase 3 | — | `DefaultMovieRepository`, both use cases | `DefaultMovieRepositoryTests` (via the concrete type) | Protocol as a substitution boundary, no `Sendable` yet (deliberately) |
| `Assignment/Domain/UseCases/SearchMoviesUseCase.swift` | Domain | `struct` (`callAsFunction`) | Query normalization + "is there anything to search" decision | Phase 3 | `MovieRepository` | `MoviesCoordinator`, `MovieSearchViewModel` | `SearchMoviesUseCaseTests` (5) | Use case owning real application policy; `nil` as a third outcome distinct from empty/error |
| `Assignment/Domain/UseCases/GetMovieDetailUseCase.swift` | Domain | `struct` (`callAsFunction`) | Forwards to `MovieRepository.movieDetail(slug:)` | Phase 3 | `MovieRepository` | `MoviesCoordinator`, `MovieDetailViewModel` | `GetMovieDetailUseCaseTests` (2) | Honest example of a use case that's currently a pass-through |
| `Assignment/Data/DefaultMovieRepository.swift` | Data | `final class` | Coordinates remote data source + cache-fallback policy | Phase 3 | `MovieSearchAPIServiceProtocol`, `MovieDetailAPIServiceProtocol`, `MovieCache` | Both use cases (via `MovieRepository`) | `DefaultMovieRepositoryTests` (5) | Repository-owned cache policy, cancellation-vs-failure distinction |
| `Assignment/Data/DTOs/MovieSearchDTO.swift`, `MovieDetailDTO.swift` | Data | `struct: Decodable` | Decode Hotstar's response shape | Pre-existing, moved Phase 3 | `Foundation` | `MovieSearchMapper`/`MovieDetailMapper` extensions, `MovieSearchAPIService`/`MovieDetailAPIService` | `MovieSearchMapperTests`, `MovieDetailMapperTests` | DTOs kept out of Domain entirely |
| `Assignment/Data/Mappers/MovieSearchMapper.swift`, `MovieDetailMapper.swift` | Data | `extension` on the DTOs | Explicit DTO→domain mapping | Pre-existing logic, split into own files Phase 3 | `Movie`/`MovieDetail`, the DTOs | `MovieSearchAPIService`/`MovieDetailAPIService` | `MovieSearchMapperTests` (5), `MovieDetailMapperTests` (4) | Explicit mapping, missing-field/invalid-response handling |
| `AssignmentTests/Fakes/FakeMovieRepository.swift` | Test doubles | `final class` | Configurable fake `MovieRepository` | Phase 3 | `MovieRepository` | Use-case and ViewModel tests | (is a fake, not a test) | Result-based configuration, per-query delay for race tests |
| `AssignmentTests/Fakes/FakeMovieAPIServices.swift` | Test doubles | `final class` (x2) | Configurable fakes for the remote-data-source protocols | Phase 3 | `MovieSearchAPIServiceProtocol`, `MovieDetailAPIServiceProtocol` | `DefaultMovieRepositoryTests` | (is a fake, not a test) | Testing the repository's own logic without faking a whole `MovieRepository` |
| `AssignmentTests/DefaultMovieRepositoryTests.swift` | Tests | `@MainActor struct` | Verifies cache-fallback + cancellation policy | Phase 3 | `DefaultMovieRepository`, both fake API services | — | (is the test) | Real `MovieCache` pointed at a temp directory, not mocked |
| `Assignment/Services/Remote/RetryPolicy.swift` | Networking | `struct` | Bounded exponential-backoff retry decision, GET-only | Phase 4 | — | `RemoteService` | `RetryPolicyTests` (7) | Pure decision function, injectable sleep for fast tests |
| `Assignment/Services/Remote/Interceptors.swift` (`AuthHeaderProviding`) | Networking | `protocol` | Credentials-provider seam for `AuthenticationInterceptor` | Phase 4 | — | `AuthenticationInterceptor`; implemented by `AuthManager` | `RemoteServiceTests.requestInterceptorHeadersReachTheFinalRequest` | Protocol replacing a direct singleton reference |
| `AssignmentTests/Fakes/StubURLProtocol.swift` | Test doubles | `final class: URLProtocol` | Intercepts `URLSession` traffic for deterministic networking tests | Phase 4 | — | `RemoteServiceTests` | (is a fake, not a test) | Shared static state - requires `.serialized` in its consuming suite |
| `Assignment/Storage/KeychainStore.swift` (`SecureKeyValueStoring`, `KeychainStore`) | Storage | `protocol` + `actor` | Keychain-backed secure key/value storage | Phase 5 | Security framework | `CredentialsStore` | Not testable in this environment (`errSecMissingEntitlement`) - see Phase 5 doc §10 | Actor for one async interface, not race protection; a discovered environment constraint fixed by a protocol boundary |
| `Assignment/Storage/CredentialsStore.swift` | Storage | `actor` | Owns credential composition and the authenticated/not decision | Phase 5 | `SecureKeyValueStoring` | `AuthManager` | `CredentialsStoreTests` (5, via `InMemoryKeyValueStore`) | Protocol-backed dependency for testability |
| `Assignment/Storage/WebDataClearingService.swift` | Storage | `@MainActor final class` | Consolidates WebKit/cookie/URL-cache clearing (was duplicated in two places) | Phase 5 | `WKWebsiteDataStore`, `HTTPCookieStorage`, `URLCache` | `AuthManager`, `LoginViewController` | None dedicated (exercised indirectly via `AuthManagerTests.logoutClearsCredentialsAndIsLoggedIn`) | `withCheckedContinuation` bridging a completion-handler API |
| `Assignment/Views/Login/HotstarCredentialExtractor.swift` | Authentication | `enum` (pure functions) | Extracts a usable session token/cookie string from raw `HTTPCookie`s | Phase 5 | — | `LoginViewController` | `HotstarCredentialExtractorTests` (6) | Pure logic pulled out of a UIKit/WebKit callback specifically for testability |
| `Assignment/Caching/MemoryCache.swift` | Caching | generic `actor` | TTL + LRU in-memory cache, hit/miss tracking | Phase 6 | — | `DefaultMovieRepository` | `MemoryCacheTests` (8) | Actor protecting genuine shared mutable state (unlike `KeychainStore`) |
| `Assignment/Caching/DiskCache.swift` | Caching | generic `actor` | TTL disk cache, corrupt-file recovery | Phase 6 | — | `DefaultMovieRepository` (detail only) | `DiskCacheTests` (5) | `nonisolated(unsafe)` on a documented-safe SDK singleton reference |
| `Assignment/Caching/InFlightRequestStore.swift` | Caching | generic `actor` | Request coalescing | Phase 6 | — | `DefaultMovieRepository` | `InFlightRequestStoreTests` (4) | The project's clearest concrete actor-reentrancy example |
| `Assignment/Caching/CachePolicy.swift` | Caching | `enum` | Three distinct cache-access behaviors | Phase 6 | — | `MovieRepository`, `DefaultMovieRepository` | Exercised by all `DefaultMovieRepositoryTests` | Deliberately excludes a fourth, redundant case |
| `Assignment/Caching/ImageLoader.swift` | Caching | `actor` | Fetches/decodes/caches images, reusing `MemoryCache`+`InFlightRequestStore` | Phase 8 | `MemoryCache`, `InFlightRequestStore` | `CachedAsyncImage` | `ImageLoaderTests` (5) | Decoding happens off the main actor "for free" |
| `Assignment/Views/Components/CachedAsyncImage.swift` | UI | `struct: View` (generic) + `EnvironmentKey` | `AsyncImage`-shaped view backed by `ImageLoader` | Phase 8 | `ImageLoader` (environment-injected) | `MoviesListView`, `MovieDetailView` | Indirectly via `ImageLoaderTests` | Nested `Phase` type caused circular generic inference - moved to file scope |

## Detailed entries

Phase 3's new files (`MovieRepository`, `DefaultMovieRepository`,
`SearchMoviesUseCase`, `GetMovieDetailUseCase`, the DTO/mapper split) have
their full "why it exists / type choice / alternatives / interview Q&A"
treatment inside `Architecture/Phase-03-Domain-and-Repository.md` rather
than repeated here verbatim — the summary table above links each one to
that document. Full per-file entries in this file's own format are kept for
Phase 1/2's files below; future phases will follow whichever placement
avoids duplicating the same explanation twice.

## `Assignment/App/AppDependencyContainer.swift`

### Why this file exists
Before this, every coordinator defaulted its `authManager` parameter to
`AuthManager.shared`, meaning the "one place the singleton is touched"
claim wasn't true — it was touched in three places. This file makes that
claim literally true: it's the single point that resolves `AuthManager.shared`.

### Responsibility
Own the app's shared, long-lived dependency (`AuthManager`, today) and hand
out fully-wired coordinators via factory methods.

### What it must not do
Contain navigation logic, networking, or UI. It only constructs and wires.

### Type choice
`final class`, not a struct: it needs identity (one container instance for
the app's lifetime) and will eventually own reference-type dependencies
(future repositories, an eventual credentials-store actor reference) where
value semantics wouldn't fit. `@MainActor` because coordinator construction
touches `@MainActor`-isolated types.

### Created by
`AssignmentApp.init()`.

### Dependencies
`AuthManager` (still the pre-refactor singleton type).

### Used by
`AssignmentApp` (the only call site so far).

### Runtime flow
1. `AssignmentApp.init()` runs.
2. `AppDependencyContainer()` is constructed with `authManager: nil`.
3. Its `init` body resolves `authManager ?? AuthManager.shared` (see
   Isolation, below, for why this happens in the body and not a default
   argument).
4. `container.makeAppCoordinator()` constructs `AppCoordinator(authManager:)`.
5. The result is stored via `StateObject(wrappedValue:)`.

### Isolation
`@MainActor`. The first version of this file defaulted the initializer
parameter to `AuthManager.shared` directly in the signature
(`authManager: AuthManager = AuthManager.shared`) — that produced a real
compiler warning: *"main actor-isolated static property 'shared' can not be
referenced from a nonisolated context."* Default-argument expressions are
evaluated in a context Swift doesn't treat as inheriting the initializer's
own actor isolation. The fix: take `authManager: AuthManager? = nil` and
resolve `?? AuthManager.shared` inside the init *body*, which does run with
the type's `@MainActor` isolation.

### Error and cancellation behavior
None — pure construction, no async work, nothing to cancel.

### Tests
`AppCoordinatorTests.dependencyContainerWiresACoordinator` — constructs a
container and asserts the coordinator it produces has a valid root.

### Alternative approaches
A value-based container (a `struct` of factory closures) was considered —
rejected for now because it adds indirection with no current benefit; the
container has one dependency and one factory method. Revisit if the
container grows enough that closures aid testability (e.g., swapping in a
fake network layer for a whole subtree at once).

### Interview explanation
"Why a class-based composition root instead of a service locator?" — a
service locator lets any type reach into a global registry at will; this
container only *hands out* dependencies to whoever explicitly asks for one
via a constructor parameter (`AppDependencyContainer` → `AppCoordinator` →
its children) — nothing reaches back into the container itself.

### Counter-question
"Isn't `AuthManager.shared` still a singleton underneath, so what did this
actually buy you?" — Correct, and worth being honest about: the *singleton
type* hasn't been removed yet (Phase 5). What changed is that no
*consumer* (coordinator) contains an implicit default that silently
resolves it — every consumer now requires the dependency explicitly, so a
future swap to an injectable, protocol-backed credentials store only
touches this one container, not four coordinator files.

### What would break if this file disappeared?
`AssignmentApp` would have to go back to constructing `AppCoordinator`
(and transitively `AuthenticationCoordinator`/`MoviesCoordinator`) itself,
and since those types no longer have default parameters, the app literally
wouldn't compile without *some* single place resolving `AuthManager`.

---

## `Assignment/Coordinators/AppCoordinator.swift`

### Why this file exists
Something has to decide, at the top of the app, whether the user sees the
login flow or the movies flow — and react when that changes.

### Responsibility
Own `Root` (`.auth`/`.movies`), the two child coordinators, and the
completion wiring between them.

### What it must not do
Networking, business logic, or constructing concrete API/network types
(confirmed absent — it only touches `AuthManager`, `AuthenticationCoordinator`,
`MoviesCoordinator`).

### Type choice
`final class` conforming to `ObservableObject`: SwiftUI needs a reference
type here so `@Published private(set) var root` can drive view updates
across the `@StateObject` it's held in.

### Created by
`AppDependencyContainer.makeAppCoordinator()`.

### Dependencies
`AuthManager`, `AuthenticationCoordinator`, `MoviesCoordinator`.

### Used by
`AssignmentApp` (via `makeRootView()` and `start()`).

### Runtime flow
1. `init(authManager:)` sets `root` from `authManager.isAuthenticated()`.
2. Builds `authCoordinator`/`moviesCoordinator`, wiring `onAuthenticated` →
   `showMovies()` and `onLogout` → `showAuth()`.
3. `AssignmentApp` calls `start()` in `.onAppear`, which re-derives `root`
   (currently redundant with the init-time computation — see the Counter-
   question below).
4. `makeRootView()` switches on `root` to produce the SwiftUI view tree.

### Isolation
`@MainActor` — all state here (`root`) drives SwiftUI directly.

### Error and cancellation behavior
None — synchronous state transitions only.

### Tests
`AppCoordinatorTests`: `startsAtAuthRootWhenNotAuthenticated`,
`startsAtMoviesRootWhenAuthenticated`, `showMoviesAndShowAuthUpdateRoot`,
`authCoordinatorCompletionBubblesToAppCoordinator`,
`moviesCoordinatorLogoutBubblesToAppCoordinator`.

### Alternative approaches
Reacting to a live `Publisher`/`AsyncSequence` of authentication state
instead of a one-shot `isAuthenticated()` call plus closures — deferred to
Phase 5, once `AuthManager` is replaced by something that actually exposes
a state stream worth subscribing to (today's `@Published var isLoggedIn` on
`AuthManager` exists but `AppCoordinator` doesn't subscribe to it yet).

### Interview explanation
"Why is root switching state-driven instead of imperative navigation
(replacing a window's root view controller)?" — because `@Published root`
plus a `switch` in `makeRootView()` means SwiftUI owns the transition
animation and view lifecycle; nothing has to manually tear down and rebuild
a view controller hierarchy.

### Counter-question
"`start()` and `init` both compute the same thing — is that a bug?" — Not
currently harmful (both read the same synchronous `isAuthenticated()`), but
it *is* redundant, and it's the reason `AppCoordinator` is listed above as
not yet reactive to auth-state *changes* that happen after launch (e.g., a
token expiring mid-session wouldn't flip `root` without an explicit
`start()`/`showAuth()` call). Real gap, tracked for Phase 5.

### What would break if this file disappeared?
There would be no single owner deciding which SwiftUI root to show —
`AssignmentApp` would have to embed that decision itself, re-introducing
exactly the coupling this coordinator exists to avoid.

---

## `Assignment/Coordinators/AuthenticationCoordinator.swift`

### Why this file exists
To isolate "how do we get from not-logged-in to logged-in" from
`AppCoordinator`'s broader root-switching responsibility.

### Responsibility
Construct `LoginView`, forward its `onAuthenticated` event upward.

### What it must not do
Decide what happens *after* authentication (that's `AppCoordinator`'s job)
or touch `UIWindow`/root-view-controller directly (it doesn't — `LoginView`
and `LoginViewController` are the UIKit bridge; this type only builds a
SwiftUI value).

### Type choice
`final class`, `@MainActor`, conforming to `Coordinator`. A class because it
holds a mutable `onAuthenticated` closure property that `AppCoordinator`
assigns after construction.

### Created by
`AppCoordinator.init`.

### Dependencies
`AuthManager`, `LoginView`.

### Used by
`AppCoordinator` (via `makeView()` when `root == .auth`).

### Runtime flow
1. `AppCoordinator` constructs it with the shared `AuthManager`.
2. `AppCoordinator` sets `onAuthenticated = { self?.showMovies() }`.
3. `makeView()` returns a `LoginView` whose own `onAuthenticated` closure
   calls `self?.onAuthenticated?()` — one level of indirection so
   `AuthenticationCoordinator`, not the View, is what `AppCoordinator` talks to.

### Isolation
`@MainActor`.

### Error and cancellation behavior
None at this layer — errors during the actual WebKit login flow are
`LoginViewController`'s concern (Phase 5 territory).

### Tests
`AppCoordinatorTests.authCoordinatorCompletionBubblesToAppCoordinator`.

### Alternative approaches
A delegate protocol instead of a closure — considered and rejected for the
same reason the original migration brief gives: for a single, one-shot
completion event, a closure is simpler than a protocol with one method, and
`docs/SWIFTUI_UIKIT_INTEROPERABILITY.md` (Phase 5) will cover the tradeoff
in more depth once the deeper UIKit bridge work happens.

### Interview explanation
"Why rename `AuthCoordinator` to `AuthenticationCoordinator`?" — purely for
documentation/naming consistency with the rest of this migration's vocabulary
(the type's responsibility didn't change) — a good example of a
zero-risk, mechanical refactor done alongside a real behavioral change
(the singleton-default removal) rather than as its own disruptive pass.

### Counter-question
"This coordinator does almost nothing — why does it need to exist at all?"
— Fair pressure-test. Today it's thin, but it's the seam Phase 5 will use:
when `LoginViewController` needs an injected credentials-provider instead
of `AuthManager.shared`, this coordinator is where that dependency gets
threaded through, without `AppCoordinator` needing to know about it.

### What would break if this file disappeared?
`AppCoordinator` would have to construct `LoginView` and manage its
completion closure directly, mixing "which root to show" with "how the
login flow completes."

---

## `Assignment/Coordinators/MoviesCoordinator.swift`

### Why this file exists
Search and detail navigation needs one owner for the `NavigationPath` and
for constructing each screen's dependencies — otherwise that logic ends up
scattered across the Views themselves (the exact problem the original
architecture audit found in `MoviesListView`).

### Responsibility
Own `@Published var path: NavigationPath`, resolve `MoviesRoute` to a
destination View, and construct `MovieSearchViewModel`/`MovieDetailViewModel`.

### What it must not do
Perform networking directly (it constructs API services but never calls
them itself) or duplicate view composition logic that belongs in
`MoviesListView`/`MovieDetailView`.

### Type choice
`final class`, `@MainActor`, `ObservableObject` (implied by `@Published`) —
same reasoning as `AppCoordinator`: SwiftUI needs the reference semantics
and observable-state machinery.

### Created by
`AppCoordinator.init`.

### Dependencies
`AuthManager`, `MoviesRoute`, `MovieSearchViewModel`, `MovieDetailViewModel`,
`MovieSearchAPIService`, `MovieDetailAPIService`.

### Used by
`AppCoordinator` (via `makeView()` when `root == .movies`).

### Runtime flow
1. `makeView()` builds a `NavigationStack` bound to `path` via a
   `Binding` wrapping `self.path`.
2. Constructs `MoviesListView(viewModel: makeSearchViewModel(), onLogout:)`.
3. Registers `.navigationDestination(for: MoviesRoute.self)`, dispatching to
   `destinationView(for:)`.
4. When a row's `NavigationLink(value: MoviesRoute.detail(movie))` fires,
   SwiftUI appends to `path`, and the registered destination closure builds
   `MovieDetailView(movie:, viewModel: makeDetailViewModel())`.

### Isolation
`@MainActor`.

### Error and cancellation behavior
None at this layer — delegated to the ViewModels it constructs.

### Tests
`MoviesCoordinatorTests` (path starts empty; appending grows it),
`AppCoordinatorTests.moviesCoordinatorLogoutBubblesToAppCoordinator`.

### Alternative approaches
See `MoviesRoute.swift`'s own entry for the id/slug-only route alternative.
A `NavigationLink(destination:)` closure directly in `MoviesListView`
(no typed route at all) was the pre-Phase-2 state — rejected going forward
because it means the View decides *what* the destination is, not just
*that* one exists.

### Interview explanation
"Why not just use `NavigationLink(destination:)` everywhere?" — that
couples the row view to knowing how to construct `MovieDetailView` and its
ViewModel; with a typed route, the row only declares *intent*
(`MoviesRoute.detail(movie)`), and the coordinator centralizes destination
construction, which is what lets `MoviesCoordinator` (not the View) own
future deep-link handling.

### Counter-question (updated Phase 6 — the original answer here is now stale, kept for the audit trail)
Originally: "you still construct `MovieSearchAPIService`/`MovieDetailAPIService`
directly in this coordinator — isn't that the same singleton-construction
problem, just moved?" Phase 3 answered that by introducing `MovieRepository`.
The *current* version of this question: "`movieRepository` is now a
`private let`, built once in `init` — why does that matter?" Because
Phase 6 gave `DefaultMovieRepository` real cache state
(`MemoryCache`/`DiskCache` actors); a fresh repository per screen (which
`makeDetailViewModel()` used to build, calling `makeMovieRepository()`
every time) would have meant a fresh, empty cache every time too —
revisiting the same movie's detail screen would never hit its own cache.
Storing one instance for the coordinator's lifetime (which itself spans
the whole app session, owned by `AppCoordinator`) fixes that — and is
exactly why `performLogout()` has to explicitly clear that repository's
caches, since it would otherwise persist across a logout/re-login cycle.

### Trade-off
Explicit `NavigationPath` ownership adds a small amount of boilerplate (the
manual `Binding` in `makeView()`) versus letting `NavigationStack` manage
an implicit path — bought back by programmatic control (future deep links,
pop-to-root) that an implicit path can't offer.

### What would break if this file disappeared?
There'd be no single place owning search-to-detail navigation state; each
View would need to manage its own path fragment, and the "coordinator owns
navigation" principle this whole migration is built around would be gone
for this feature specifically.

---

## `Assignment/Coordinators/MoviesRoute.swift`

### Why this file exists
Before Phase 2, `.navigationDestination(for: Movie.self)` used the domain
model itself as the navigation value — meaning "is this Hashable value a
navigable route" and "is this Hashable value a piece of domain data" were
the same question, which stops being true the moment a second, differently
shaped route is needed.

### Responsibility
Represent every navigable destination in the movies feature as one
`Hashable` enum case.

### What it must not do
Carry raw DTOs, or represent more than "where to navigate."

### Type choice
`enum: Hashable` — routes need value semantics and equality/hashing for
`NavigationPath`/`.navigationDestination(for:)` to work; a class would add
unneeded reference-identity semantics to something that's really just a
value describing intent.

### Created by
Phase 2 (CC8).

### Dependencies
`Movie`.

### Used by
`MoviesCoordinator` (registers the destination), `MoviesListView` (pushes
`.detail(movie)` from a `NavigationLink`).

### Runtime flow
Constructed at the row's `NavigationLink(value:)` call site; consumed by
`MoviesCoordinator`'s `.navigationDestination(for: MoviesRoute.self)`
closure, which pattern-matches the single `.detail` case today.

### Isolation
None needed — a plain value type, no actor isolation applies.

### Error and cancellation behavior
None — it's inert data.

### Tests
`MoviesCoordinatorTests.appendingDetailRouteGrowsPath`.

### Alternative approaches
The originally sketched shape for this exact concept was
`case detail(movieID: Movie.ID, slug: String)` rather than
`case detail(Movie)`. Rejected for now: `MovieDetailView` uses
`movie.posterURL` as an immediate fallback poster while the network detail
call is in flight, so having the full `Movie` in hand avoids a lookup step
that doesn't otherwise exist anywhere in the app. Worth revisiting once/if
deep linking needs to construct a route from just a URL, with no `Movie`
already in memory.

### Interview explanation
"Why `Hashable` specifically?" — `NavigationPath` and
`.navigationDestination(for:)` both require it: the path stores type-erased
`Hashable` values, and matching a destination back to a case requires
hashing/equality.

### Counter-question
"With only one case, isn't this enum overkill versus just pushing `Movie`
directly?" — With one case, the *type-safety* benefit is modest, but the
*ownership* benefit already matters: `MoviesCoordinator`, not
`MoviesListView`, decides what "detail" means as a navigation target. The
day a second route is needed (e.g., a cast/crew screen), the enum absorbs
it without touching how rows declare their intent.

### What would break if this file disappeared?
`MoviesCoordinator` would go back to registering
`.navigationDestination(for: Movie.self)`, and any future second
destination would have no natural home — either a second bare-model
destination registration (fragile, easy to conflict) or the same enum
reinvented under time pressure.

---

## `Assignment/ViewModels/MovieSearchViewModel.swift`

### Why this file exists
Owns the search screen's presentation state and its debounced search
pipeline — logic that doesn't belong in `MoviesListView` itself.

### Responsibility
Expose `searchText`, `searchResults`, `isLoading`, `searchError`; debounce
`searchText` changes into cancellable search `Task`s.

### What it must not do
Construct its own API service by default anymore (the convenience `init()`
that did this was deleted in Phase 2) or perform navigation.

### Type choice
`final class`, `@MainActor`, `ObservableObject` — SwiftUI-observed
presentation state, single-threaded by design (`@MainActor`).

### Created by
Pre-existing; its injection point changed in Phase 2 — now constructed by
`MoviesCoordinator.makeSearchViewModel()`.

### Dependencies
`MovieSearchAPIServiceProtocol` (currently concretely
`MovieSearchAPIService`, injected as a protocol so a fake is already
possible for tests — just not yet exercised, see `CURRENT_IMPLEMENTATION.md`).

### Used by
`MoviesListView`.

### Runtime flow
1. `$searchText` → `.debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)`
   → `.removeDuplicates()` → `.sink`.
2. On a non-empty trimmed query: cancels any in-flight `searchTask`, starts
   a new `Task` calling `search(query:)`.
3. `search(query:)` awaits `apiService.searchVideos(query:)`, checks
   `Task.checkCancellation()`, and guards `latest == query` before writing
   results — rejecting a response that arrives after a newer query has
   already been typed.

### Isolation
`@MainActor` for all published state; the actual network call happens via
`await` inside a `Task` still bound to the main actor (no background actor
hop exists yet — that's fine, since the work being awaited is I/O, not
CPU-bound work needing offloading).

### Error and cancellation behavior
`CancellationError` is caught and silently ignored (not surfaced as a user
-facing error) — correct, since a cancelled search isn't a failure. Other
errors set `searchError = .networkError`. Empty (but successful) responses
set `.noResults`.

### Tests
None dedicated yet — a real, tracked gap (see `CURRENT_IMPLEMENTATION.md`),
scheduled to close in Phase 3 alongside introducing a use case this
ViewModel can call instead of the API service directly.

### Alternative approaches
See `docs/Learning/Architecture/Phase-03-Domain-and-Repository.md` (Phase 3,
in progress) for the ViewModel→use-case→repository alternatives comparison.

### Interview explanation
"What happens if the user types a second query before the first search
completes?" — `searchTask?.cancel()` cancels the in-flight `Task`, a new one
starts; even if the old response somehow still arrives, `guard latest ==
query` rejects it because `searchText` no longer matches what that response
was for.

### Counter-question
"Why not use Combine's `switchToLatest` instead of manually cancelling a
`Task`?" — because the network call is `async`/`await`, not a `Publisher`;
bridging every request into a `Future` to use `switchToLatest` adds
Combine-cancellation-versus-`Task`-cancellation subtleties (a `Future`
doesn't cancel its underlying work just because its subscriber cancels)
without buying anything the current `Task`-cancel + stale-check approach
doesn't already provide.

### What would break if this file disappeared?
No search feature at all — this is where the entire search behavior lives.

---

## `Assignment/ViewModels/MovieDetailViewModel.swift`

### Why this file exists
Owns the detail screen's load/loading/error state, decoupled from the View.

### Responsibility
Expose `movieDetail`, `isLoading`, `detailError`; load a movie's detail by
slug.

### What it must not do
Construct its own API service by default anymore (convenience `init()`
deleted in Phase 2).

### Type choice
`class` (not `final` — the only ViewModel in the codebase not marked
`final`; worth revisiting for consistency, tracked as a small Phase 3/9
cleanup item, not a functional issue today), `@MainActor`, `ObservableObject`.

### Created by
Pre-existing; injection point changed in Phase 2 — now constructed by
`MoviesCoordinator.makeDetailViewModel()`.

### Dependencies
`MovieDetailAPIServiceProtocol`.

### Used by
`MovieDetailView`.

### Runtime flow
`MovieDetailView.task(id: movie.pageSlug)` calls
`loadMovieDetail(slug:)`, which sets `isLoading = true`, awaits
`apiService.fetchMovieDetail(slug:)`, checks `Task.checkCancellation()`,
then sets `movieDetail`/`isLoading = false`, or `detailError` on failure.

### Isolation
`@MainActor`.

### Error and cancellation behavior
`CancellationError` is caught and the function returns early without
touching `detailError` — a cancelled load (e.g., the user navigated away)
correctly doesn't flash an error state. `.task(id:)` automatically cancels
and restarts if `movie.pageSlug` changes, which is how SwiftUI ties the
View's lifecycle to this ViewModel's async work without any manual
`onDisappear` bookkeeping.

### Tests
None dedicated yet (same tracked gap as the search ViewModel).

### Alternative approaches
See Phase 3 doc for the use-case comparison.

### Interview explanation
"How does this ViewModel know to cancel when the user navigates back?" — it
doesn't, directly: `.task(id:)` in `MovieDetailView` is what SwiftUI
cancels automatically when the view disappears or `id` changes; the
ViewModel's job is just to behave correctly *when* cancelled
(`CancellationError` → silent return, not an error state).

### Counter-question
"Why `.task(id: movie.pageSlug)` instead of `.onAppear`?" — `.task(id:)`
gives automatic cancellation tied to the view's identity and the id's
value; `.onAppear` doesn't cancel anything on disappear, and using a plain
`.task` (no `id`) wouldn't restart the load if the same `MovieDetailView`
instance were reused for a different movie.

### What would break if this file disappeared?
No detail screen data loading at all.

---

## `Assignment/Views/Login/LoginViewController.swift`

### Why this file exists
Hotstar's login has no public API — it requires driving an actual web
login page and extracting session cookies/tokens from the resulting
`WKWebView`, which SwiftUI has no native mechanism for.

### Responsibility
Load the login page, extract credentials once the user has logged in via
the web view, hand them to `AuthManager`.

### What it must not do
Decide app-level navigation beyond "I'm done, here's my result" (confirmed:
`navigateToMainApp()` only calls `onAuthenticated?()`, it doesn't touch
`UIWindow`).

### Type choice
`class: UIViewController` — has to be, since `WKWebView` and its delegate
protocols are UIKit.

### Created by
Pre-existing; injected-`AuthManager` initializer and internal rework
(pure-extraction, consolidated web-data clearing) added Phase 5.

### Dependencies
`AuthManager` (injected via `init(authManager:)` — no `.shared` reference
anywhere in this file as of Phase 5), `HotstarCredentialExtractor`,
`WebDataClearingService`, `WKWebView`.

### Used by
`LoginView` (`UIViewControllerRepresentable`).

### Runtime flow
`viewDidLoad` → `Task` clears all WebKit data via `WebDataClearingService`
→ loads the login URL → on `proceedButtonTapped`, a `Task` awaits all
cookies from `WKHTTPCookieStore` (bridged via `withCheckedContinuation`),
passes them to `HotstarCredentialExtractor.extract(from:)`, and if a
usable result comes back, calls `await authManager.saveCredentials(...)`
then `onAuthenticated?()`. No "already authenticated, skip" check remains
here — `AppCoordinator` already gates whether this screen is shown at all.

### Isolation
Implicitly main-thread (UIKit), not `@MainActor`-annotated explicitly (a
Swift 6 strict-concurrency gap tracked for Phase 9's concurrency-settings
review).

### Error and cancellation behavior
No credentials found → re-enables the "proceed" button and shows a
`UIAlertController` asking the user to log in first. Async work is started
via un-awaited `Task { [weak self] in ... }` blocks from synchronous UIKit
callbacks (`viewDidLoad`, `proceedButtonTapped`) — no explicit cancellation
of those tasks exists if the controller is dismissed mid-flight, a real,
minor gap (the tasks capture `self` weakly, so they don't leak the
controller, but they do keep running).

### Tests
None directly (still UIKit-lifecycle-bound) — but its previously-untestable
cookie-parsing logic is now covered via `HotstarCredentialExtractorTests`
(6 tests), since that logic was pulled out into its own pure type.

### Alternative approaches
See `docs/Learning/Architecture/Phase-05-Authentication.md` §12 for the
full alternatives comparison (Keychain accessibility level, protocol
boundary design).

### Interview explanation
"How does the SwiftUI/UIKit boundary work here?" — `LoginView`
(`UIViewControllerRepresentable`) creates and owns this controller,
injecting `AuthManager` rather than letting it reach `.shared`; completion
flows back to SwiftUI via a plain closure (`onAuthenticated`), not a
delegate. Full detail in `docs/SWIFTUI_UIKIT_INTEROPERABILITY.md`.

### Counter-question
"Why does credential extraction live in a separate `HotstarCredentialExtractor`
type instead of staying inline here?" — Because a `WKHTTPCookieStore`
completion closure can't be unit-tested without a live `WKWebView`; pulling
the pure logic out let Phase 5 add 6 real tests for exactly the part of
this flow most likely to break silently (Hotstar changing its cookie
contract).

### What would break if this file disappeared?
No way to log in at all — this is the entire authentication mechanism.

---

## `Assignment/Views/Login/LoginView.swift`

### Why this file exists
`UIViewControllerRepresentable` conformance is the only way to host a
`UIViewController` inside SwiftUI.

### Responsibility
Bridge `LoginViewController` into the SwiftUI view tree.

### What it must not do
Contain any login logic itself (it doesn't — pure bridge).

### Type choice
`struct: UIViewControllerRepresentable` — required by the protocol.

### Created by
Pre-existing.

### Dependencies
`LoginViewController`.

### Used by
`AuthenticationCoordinator.makeView()`.

### Runtime flow
`makeUIViewController` constructs `LoginViewController` and forwards
`onAuthenticated`; `updateUIViewController` is a no-op (nothing about this
screen needs SwiftUI-driven updates pushed into the controller).

### Isolation
Implicitly main-thread (SwiftUI view construction).

### Error and cancellation behavior
None at this layer.

### Tests
None.

### Alternative approaches
None — this is the standard, only way to embed a `UIViewController`.

### Interview explanation
"What's the difference between this and `UIViewControllerRepresentable`'s
`Coordinator`?" — this file doesn't need a `Coordinator` object because it
has no delegate callbacks to bridge (it uses a plain closure instead); a
`Coordinator` becomes necessary when a `UIViewControllerRepresentable`
needs to act as a UIKit delegate (e.g., if `LoginViewController` used
`WKNavigationDelegate` methods that had to report back through the
representable rather than directly to the controller itself, which today
it doesn't need to).

### Counter-question
"Why is `updateUIViewController` empty — is that a bug?" — No: nothing in
`LoginView`'s own state ever changes after creation (`onAuthenticated` is
set once), so there's nothing for SwiftUI to push into the controller on
update.

### What would break if this file disappeared?
`AuthenticationCoordinator` would have no way to host `LoginViewController`
in SwiftUI at all.

---

## `AssignmentTests/AppCoordinatorTests.swift`

### Why this file exists
Phase 1 introduced coordinator dependency injection; this is what verifies
routing logic didn't break in the process, and locks in the
`onAuthenticated`/`onLogout` closure wiring.

### Responsibility
Verify `AppCoordinator`'s root-switching and completion-closure behavior.

### What it must not do
Depend on live networking or WebKit (it doesn't — pure state/coordinator
logic).

### Type choice
`@Suite(.serialized) @MainActor struct` — a `struct` because Swift Testing
tests don't need reference identity; `.serialized` because every test
mutates the shared, process-wide `AuthManager.shared`.

### Created by
Phase 1 (CC7).

### Dependencies
`AppCoordinator`, `AppDependencyContainer`, `AuthManager.shared`.

### Used by
Test runner only.

### Runtime flow
Each test drives `AuthManager.shared` into a known state
(`logout()`/`saveCredentials(...)`), constructs a fresh `AppCoordinator`,
and asserts on `.root` or triggers a closure and re-checks `.root`.

### Isolation
`@MainActor` (required — `AppCoordinator` itself is main-actor isolated).

### Error and cancellation behavior
N/A.

### Tests
This *is* the test suite (6 tests, see the summary table).

### Alternative approaches
A fake/mock `AuthManager` — blocked today by `AuthManager.init` being
`private`; tracked as a Phase 5 prerequisite.

### Interview explanation
"Why `.serialized`?" — Swift Testing runs tests in parallel by default;
since every test here reads/writes the same singleton's `UserDefaults`
-backed state, parallel execution would make them race and flake.
`.serialized` forces them to run one at a time.

### Counter-question
"Doesn't testing against a real singleton make these more like integration
tests than unit tests?" — Yes, and the file's own header comment says so
explicitly rather than calling them "unit tests" and hoping nobody notices.

### What would break if this file disappeared?
`AppCoordinator`'s routing logic would have zero automated regression
coverage.

---

## `AssignmentTests/MoviesCoordinatorTests.swift`

### Why this file exists
Phase 2 added real navigation-path state (`@Published var path`); this
verifies it actually behaves as a path (starts empty, grows on append).

### Responsibility
Verify `MoviesCoordinator.path` behavior.

### What it must not do
Test View rendering (out of scope for a coordinator test).

### Type choice
`@MainActor struct` — no shared mutable global state is touched here (unlike
`AppCoordinatorTests`), so no `.serialized` trait is needed.

### Created by
Phase 2 (CC8).

### Dependencies
`MoviesCoordinator`, `MoviesRoute`, `Movie`.

### Used by
Test runner only.

### Runtime flow
Constructs a `MoviesCoordinator`, asserts `path.isEmpty`, appends a
`MoviesRoute.detail(movie)`, asserts `path.count == 1`.

### Isolation
`@MainActor`.

### Error and cancellation behavior
N/A.

### Tests
This *is* the test suite (2 tests).

### Alternative approaches
Asserting on the *contents* of `path` — not possible today: `NavigationPath`
doesn't expose stored values for inspection, only `count`/`isEmpty`, which
is a real, documented limitation of the type itself, not a gap in this test.

### Interview explanation
"How do you test `NavigationPath` state if you can't read its contents?" —
you test the *effect* of operations on it (does appending change `count`,
does it start empty) rather than its internal representation — the same
principle as testing any opaque/type-erased container.

### Counter-question
"What does this test *not* prove?" — It doesn't prove
`.navigationDestination(for:)` actually renders `MovieDetailView` correctly
for a `.detail` route — that would need a UI test or a ViewInspector-style
tool, neither of which this project has yet.

### What would break if this file disappeared?
`MoviesCoordinator`'s path-management logic would have zero automated
regression coverage.
