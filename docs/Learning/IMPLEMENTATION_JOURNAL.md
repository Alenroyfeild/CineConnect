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

## Phase 4 onward

Not started. See `docs/ARCHITECTURE_REFACTOR_PLAN.md` for the full phase
list and `docs/Learning/README.md` for current status labels.
