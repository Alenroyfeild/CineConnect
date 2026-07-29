# Phase 2 — Typed Navigation and Injected MVVM

Status: **Implemented and verified**. Commit `95af1c4`.

## 1. Previous implementation

`MoviesCoordinator.makeView()` used
`.navigationDestination(for: Movie.self)` — the domain model itself was the
navigation value, and `NavigationStack` managed its path implicitly (no
`@Published` path existed to inspect or drive programmatically).
`MoviesListView`/`MovieDetailView` each self-constructed their ViewModel via
a `convenience init()` that itself default-constructed a concrete API
service (`MovieSearchAPIService()`/`MovieDetailAPIService()`).

## 2. Problem

Two separate issues living in the same code: (a) using `Movie` as the
navigation value conflates "this is a piece of domain data" with "this is a
route," which stops scaling the moment a second, differently-shaped
destination is needed; (b) Views constructing their own ViewModels (via a
convenience init that itself constructs a concrete API service) means
neither the View nor its ViewModel can be handed a fake for testing/previews
without changing the View's own source.

## 3. Target responsibility

`MoviesCoordinator` owns an explicit `NavigationPath` and a typed
`MoviesRoute`; it constructs both ViewModels and injects them into the
Views via required initializer parameters.

## 4. Files introduced

- `Assignment/Coordinators/MoviesRoute.swift`
- `AssignmentTests/MoviesCoordinatorTests.swift`

## 5. Files modified

- `Assignment/Coordinators/MoviesCoordinator.swift`
- `Assignment/Views/MoviesListView.swift`
- `Assignment/Views/MovieDetailView.swift`
- `Assignment/ViewModels/MovieSearchViewModel.swift` (deleted the now-dead `convenience init()`)
- `Assignment/ViewModels/MovieDetailViewModel.swift` (same)

## 6. Files removed

None (deletions were of dead code *within* modified files, not whole files).

## 7. Runtime flow before

```
MoviesListView                              MovieDetailView
  @StateObject = MovieSearchViewModel()        @StateObject = MovieDetailViewModel()
    convenience init()                            convenience init()
      → MovieSearchAPIService()                     → MovieDetailAPIService()

NavigationLink(value: movie)   // the domain model IS the route
  → .navigationDestination(for: Movie.self) { movie in MovieDetailView(movie: movie) }
```

## 8. Runtime flow after

```
MoviesCoordinator.makeView()
  → MoviesListView(viewModel: makeSearchViewModel(), onLogout:)
  → NavigationStack(path: <bound to self.path>)
      NavigationLink(value: MoviesRoute.detail(movie))   // typed route, not the model
        → path.append(...)   // handled by SwiftUI via the binding
        → .navigationDestination(for: MoviesRoute.self) { route in
              switch route { case .detail(let movie): MovieDetailView(movie: movie, viewModel: makeDetailViewModel()) }
          }
```

Numbered, with file/type/method/context:

1. **File:** `MoviesCoordinator.swift` · **Method:** `makeSearchViewModel()`
   · `@MainActor`, synchronous, no suspension.
2. **File:** `MoviesListView.swift` · row's `NavigationLink(value:
   MoviesRoute.detail(movie))` · triggered on the main thread by a user tap.
3. SwiftUI appends the value to the `NavigationPath` bound in
   `MoviesCoordinator.makeView()`.
4. **File:** `MoviesCoordinator.swift` · **Method:** `destinationView(for:)`
   · pattern-matches `.detail(let movie)`, calls `makeDetailViewModel()`.
5. **File:** `MovieDetailView.swift` · `.task(id: movie.pageSlug)` starts
   loading — a suspension point (`await apiService.fetchMovieDetail(slug:)`)
   that SwiftUI cancels automatically if the view disappears before it
   completes.

**Test covering navigation state:** `MoviesCoordinatorTests`. **Test
covering the ViewModel injection compiling/wiring correctly:** implicitly,
every build of the app itself (no dedicated ViewModel test yet — tracked
gap, see `CURRENT_IMPLEMENTATION.md`).

## 9. Code excerpts

**Exact production code** (`Assignment/Coordinators/MoviesRoute.swift`):

```swift
enum MoviesRoute: Hashable {
    case detail(Movie)
}
```

**Exact production code** (`MoviesListView.swift`, the changed initializer):

```swift
init(viewModel: MovieSearchViewModel, onLogout: (() -> Void)? = nil) {
    _viewModel = StateObject(wrappedValue: viewModel)
    self.onLogout = onLogout
}
```

**Exact production code** (`MoviesCoordinator.swift`, destination resolution):

```swift
@ViewBuilder
private func destinationView(for route: MoviesRoute) -> some View {
    switch route {
    case .detail(let movie):
        MovieDetailView(movie: movie, viewModel: makeDetailViewModel())
    }
}
```

## 10. Build evidence

Same command as Phase 1's; result: **BUILD SUCCEEDED**. One real build
error was hit and fixed during this phase: `MoviesCoordinator.swift` used
`@Published` with only `import SwiftUI` — `@Published` is declared in
`Combine`, and SwiftUI doesn't transitively re-export it for this purpose;
adding `import Combine` fixed it (the exact same class of issue as an
earlier, separate fix to `AppCoordinator.swift`, referenced in the git log
as `fix: import Combine for app coordinator`).

## 11. Test evidence

`MoviesCoordinatorTests` — 2 tests, both passing: `pathStartsEmpty`,
`appendingDetailRouteGrowsPath`. Full suite: 10/10 passing after this phase.

## 12. Alternatives

1. **`case detail(movieID: Movie.ID, slug: String)`** (the originally
   sketched route shape) — rejected for now: `MovieDetailView` shows
   `movie.posterURL` as an immediate fallback while the network detail call
   is in flight; a slug-only route would need a "look up the `Movie` for
   this id" step that doesn't exist anywhere in the app today. Revisit once
   deep linking needs a route constructible with no in-memory `Movie`.
2. **Keep `Movie` as the nav value, add a second
   `.navigationDestination(for:)` for a future second screen** — rejected:
   SwiftUI doesn't cleanly support two destination registrations for two
   unrelated `Hashable` types sharing one `NavigationPath` without them
   fighting over path entries; one enum is the standard fix.
3. **ViewModels keep their convenience initializers "just in case
   previews need them"** — rejected: they were unused the moment production
   Views stopped calling them; unused code left "just in case" is exactly
   what the project's own engineering rules say not to do.

## 13. Trade-offs

The explicit `NavigationPath` binding in `makeView()` (`Binding(get: { self.path
}, set: { self.path = $0 })`) is slightly more code than letting
`NavigationStack` manage a path internally — bought back by the ability to
later drive `path.append`/`path.removeLast()` programmatically (deep links,
"pop to root" after logout, etc.).

## 14. Failure scenarios

**What if `destinationView(for:)` didn't handle a case?** `MoviesRoute` has
one case today; Swift's exhaustive `switch` means adding a second case
without a matching branch is a compile error, not a runtime crash — a
concrete, checkable benefit of the enum-based route over a stringly-typed
or `Any`-based alternative.

## 15. Interview Q&A

### Why did you introduce a typed `MoviesRoute` instead of navigating with the `Movie` model directly?

**Strong answer:** Using the domain model as the navigation value conflates
two different concerns — "this is a piece of data the app knows about" and
"this is a place the app can navigate to." `MoviesRoute` separates them: a
single `Hashable` enum is what `NavigationPath`/`.navigationDestination(for:)`
actually need, and it's the type that will absorb a second destination
later without touching how the search row declares its intent.

**Code evidence:**
- `Assignment/Coordinators/MoviesRoute.swift`
- `Assignment/Views/MoviesListView.swift` (`NavigationLink(value: MoviesRoute.detail(movie))`)
- Test: `MoviesCoordinatorTests.appendingDetailRouteGrowsPath`

**Follow-up question:** With only one case, isn't this over-engineering?

**Follow-up answer:** The type-safety win is modest with one case, but the
*ownership* win already exists: `MoviesCoordinator`, not the row view,
decides what "detail" resolves to.

**Senior counter-question:** Doesn't carrying the whole `Movie` in the
route (instead of just an id) violate "routes should be lightweight, url
-like values" for future deep linking?

**Counter-answer:** It's a real, named trade-off (see §12, alternative 1),
not an oversight — the app doesn't have deep linking yet, and
`MovieDetailView` currently relies on having the full model in hand for
its immediate poster fallback. This is flagged in the code's own doc
comment as the thing to revisit when deep linking actually arrives.

**Trade-off:** Simplicity and immediate poster rendering today, versus a
route that isn't yet deep-link-friendly.

**Failure scenario:** If a URL scheme handler tried to construct a
`MoviesRoute.detail` today without an in-memory `Movie`, it couldn't — it
would need to fetch the movie first, then construct the route, an extra
step this design doesn't yet support directly.

**Weak answer:** "Typed routes are just best practice."

**Improved answer:** Ties the choice to this app's actual constraint
(immediate poster rendering from an in-memory model) and names the
alternative it deliberately isn't using yet.

### Why do Views no longer construct their own ViewModels?

**Strong answer:** `MoviesListView`'s and `MovieDetailView`'s previous
`convenience init()` chain (View → ViewModel's convenience init → concrete
API service) meant no test or preview could substitute different behavior
without changing the View's declaration itself. Now `MoviesCoordinator`
constructs both ViewModels and passes them in as required parameters — the
View only knows "I receive a `MovieSearchViewModel`," not how one gets
built.

**Code evidence:**
- `MoviesCoordinator.makeSearchViewModel()`/`makeDetailViewModel()`
- `MoviesListView.init(viewModel:onLogout:)`
- `MovieDetailView.init(movie:viewModel:)`

**Follow-up question:** Doesn't the coordinator still construct the
concrete `MovieSearchAPIService`/`MovieDetailAPIService` directly?

**Follow-up answer:** Yes — that's this phase's honest limit. The
dependency-construction responsibility moved from the View to the
coordinator; replacing the *concrete API service* with an injected
`MovieRepository` protocol is Phase 3's job, in progress now.

**Senior counter-question:** So what did Phase 2 actually buy, if the
coordinator still hardcodes concrete types?

**Counter-answer:** It moved dependency construction out of SwiftUI View
bodies (where it's awkward to test or override) and into a single
coordinator method per ViewModel — a smaller, more testable surface than
before, and the exact surface Phase 3 will change next, without touching
the Views again.

**Trade-off:** The coordinator now knows about concrete API service types
it arguably shouldn't need to (repository-boundary territory) — accepted
temporarily, tracked explicitly as Phase 3 work rather than left unstated.

**Failure scenario:** A preview or test wanting a fake search result set
still can't get one today without also faking the whole
`MovieSearchAPIServiceProtocol` chain manually at the call site — Phase 3's
repository/mock work is what fixes this properly.

**Weak answer:** "We added dependency injection."

**Improved answer:** Names exactly which dependency-construction step moved
(View → Coordinator) and which one didn't yet (concrete service → protocol
-backed repository), instead of claiming the whole DI story is finished.

## 16. Counter-questions

- "If two rows navigated to the same movie, would the path contain two
  equal entries?" Yes — `NavigationPath` doesn't deduplicate; each
  `.append` is a distinct entry even if `Hashable`-equal to another.
- "What breaks if `MoviesRoute` stopped being `Hashable`?" The project
  wouldn't compile — both `NavigationPath.append` and
  `.navigationDestination(for:)` require it.

## 17. Exercises

**Observe:** Set a breakpoint in `MoviesCoordinator.destinationView(for:)`.
Search for a movie, tap a result, confirm the breakpoint fires with the
tapped `Movie` inside the `.detail` case.

**Modify:** Change `MoviesRoute` to also carry a `source: String` (e.g.,
`"search"`) alongside the movie, purely to observe how a route grows.
Predict, before running, which files need to change (hint: fewer than you
might expect — `MoviesListView`'s call site and the `destinationView`
switch, not `MovieDetailView` itself unless you also thread the new field
through).

**Break intentionally:** Temporarily revert `MoviesListView`'s
`NavigationLink` to `NavigationLink(value: movie)` (the pre-Phase-2 form)
without updating `MoviesCoordinator`'s destination registration. Observe:
does it still compile? (It will, but the row becomes unreachable/unrouted
in practice at runtime, silently — no crash, no error, worth seeing
firsthand.) Restore it afterward.

**Extend:** Add a `MoviesRoute.search(query: String)` case that isn't
pushed from anywhere yet — observe the exhaustive `switch` in
`destinationView(for:)` become a compile error until you handle it. This is
the concrete mechanism behind "typed routes make it a compile error to
forget a destination."

**Interview:** Without re-reading this document, explain why
`MovieDetailView`'s initializer takes `viewModel: MovieDetailViewModel` as
a required parameter instead of the view constructing one itself.

## 18. Remaining limitations

`MoviesCoordinator` still constructs `MovieSearchAPIService()`/
`MovieDetailAPIService()` concretely (Phase 3 replaces this with an injected
repository). Neither `MovieSearchViewModel` nor `MovieDetailViewModel` has
a dedicated unit test yet.

---

# Before/after: View-constructed vs. coordinator-injected ViewModels

## Before

```swift
struct MovieDetailView: View {
    let movie: Movie
    @StateObject private var viewModel = MovieDetailViewModel()
    ...
}

class MovieDetailViewModel: ObservableObject {
    convenience init() {
        self.init(apiService: MovieDetailAPIService())
    }
}
```

Problems:
- The View creates a concrete production dependency chain three levels
  deep (View → ViewModel's convenience init → concrete API service).
- Preview and test substitution require either accepting the real network
  service or editing the View's own source.
- The coordinator has no say in how this screen's feature is constructed.
- Navigation (pushing to this screen) and dependency creation
  (constructing its ViewModel) are both implicitly the View's problem.

## After

```swift
struct MovieDetailView: View {
    let movie: Movie
    @StateObject private var viewModel: MovieDetailViewModel

    init(movie: Movie, viewModel: MovieDetailViewModel) {
        self.movie = movie
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}

// MoviesCoordinator.swift
private func makeDetailViewModel() -> MovieDetailViewModel {
    MovieDetailViewModel(apiService: MovieDetailAPIService())
}
```

- Who now creates the ViewModel: `MoviesCoordinator`, at the moment it
  resolves a `.detail` route.
- How its dependencies are supplied: as a required constructor parameter,
  wrapped in `StateObject(wrappedValue:)` so SwiftUI still manages its
  lifetime correctly across view updates.
- How the View retains it: same `@StateObject` mechanism as before — only
  *where the instance comes from* changed, not how SwiftUI owns it.
- How previews construct mocks: not yet solved cleanly (the current preview
  still passes a real `MovieDetailAPIService()`) — real fakes arrive with
  Phase 3's repository protocol.
- How tests substitute behavior: same current limitation — tracked, not
  hidden.
