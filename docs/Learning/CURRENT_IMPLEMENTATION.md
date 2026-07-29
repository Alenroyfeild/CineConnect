# CineConnect — Current Implementation (source of truth)

Updated after every phase. If this table and the actual code disagree, the
code is right and this file is stale — file it as a bug in the migration,
don't trust the table blindly. Last updated: end of Phase 3.

| Area | Current implementation | Key files | Tests | Build status | Remaining gaps |
|---|---|---|---|---|---|
| Application composition | `AppDependencyContainer` owns the one `AuthManager` instance and builds `AppCoordinator`; `AssignmentApp.init()` constructs the container and stores the coordinator in `@StateObject` | `Assignment/App/AppDependencyContainer.swift`, `Assignment/AssignmentApp.swift` | `AppCoordinatorTests.dependencyContainerWiresACoordinator` | Passing | Container still has exactly one dependency (`AuthManager`) — grows as repository/networking phases add more |
| Authentication (state/routing) | `AuthManager` (singleton) tracks `isAuthenticated()` via `UserDefaults`; `AppCoordinator` reads it once at init and again via explicit `showAuth()`/`showMovies()` calls, not a live subscription yet | `Assignment/Utils/AuthManager.swift`, `Assignment/Coordinators/AppCoordinator.swift` | `AppCoordinatorTests` (5 tests) | Passing | Credentials still in plaintext `UserDefaults`; `AppCoordinator` doesn't yet *observe* auth state, it's told about changes via closures — Phase 5 |
| Navigation | `AppCoordinator` chooses `.auth`/`.movies` root; `MoviesCoordinator` owns a `@Published NavigationPath` and a typed `MoviesRoute` enum | `AppCoordinator.swift`, `MoviesCoordinator.swift`, `MoviesRoute.swift` | `AppCoordinatorTests`, `MoviesCoordinatorTests` | Passing | Only one route case (`.detail`) exists — enough for what the app does today |
| Search | `MovieSearchViewModel` (Combine debounce → `Task` → `SearchMoviesUseCase` → `MovieRepository`), injected by `MoviesCoordinator` into `MoviesListView` | `Assignment/ViewModels/MovieSearchViewModel.swift`, `Assignment/Domain/UseCases/SearchMoviesUseCase.swift` | `MovieSearchViewModelTests` (5), `SearchMoviesUseCaseTests` (5) | Passing | Combine debounce timing still fixed at 500ms, not injectable (Phase 7) |
| Movie detail | `MovieDetailViewModel` → `GetMovieDetailUseCase` → `MovieRepository`, injected by `MoviesCoordinator` via the route's destination factory | `MovieDetailViewModel.swift`, `Assignment/Domain/UseCases/GetMovieDetailUseCase.swift` | `MovieDetailViewModelTests` (3), `GetMovieDetailUseCaseTests` (2) | Passing | `GetMovieDetailUseCase` is a deliberate pass-through (documented, not hidden) |
| Domain layer | `Movie`/`MovieDetail` moved to `Assignment/Domain/Models/`; `MovieRepository` protocol added | `Assignment/Domain/Models/Movie.swift`, `MovieDetail.swift`, `Assignment/Domain/MovieRepository.swift` | `AssignmentTests.movieModelIsHashableAndCodable`, all repository/use-case tests exercise the protocol indirectly | Passing | No `Sendable` conformance on `MovieRepository` yet (needs its dependencies audited first — Phase 4/6) |
| Repository layer | `DefaultMovieRepository` coordinates the remote data source and `MovieCache` fallback; found and fixed a cancellation-vs-failure bug in the process | `Assignment/Data/DefaultMovieRepository.swift` | `DefaultMovieRepositoryTests` (5) | Passing | No `CachePolicy` parameter yet - only one implicit policy exists (Phase 6) |
| Networking | `RemoteService`/`BaseAPIService` singleton-defaulted; `MovieSearchAPIService`/`MovieDetailAPIService` simplified in Phase 3 to remote-data-source-only (no more cache logic); known bugs still present: `isSuccess` only accepts exactly HTTP 200, search query is percent-encoded twice | `Assignment/Services/Remote/*.swift`, `Assignment/Services/MovieSearchAPIService.swift`, `MovieDetailAPIService.swift` | Indirectly via `DefaultMovieRepositoryTests` (through the protocol) | Passing (bugs not yet fixed) | Phase 4 |
| Credentials | Plaintext `UserDefaults`, singleton `AuthManager` | `Assignment/Utils/AuthManager.swift` | None | Passing | Phase 5 |
| Caching | `MovieCache` — plain class, file-backed, fallback-only, no TTL/eviction; ownership of the fallback *policy* moved to `DefaultMovieRepository` in Phase 3 (the cache type itself is unchanged) | `Assignment/Services/Cache/MovieCache.swift`, `Assignment/Data/DefaultMovieRepository.swift` | `DefaultMovieRepositoryTests` (cache-fallback + cancellation tests) | Passing | Still not actor-isolated, no TTL/eviction (Phase 6) |
| Image loading | Plain SwiftUI `AsyncImage`, no app-level cache | `Assignment/Views/MoviesListView.swift`, `MovieDetailView.swift` | None | Passing | Phase 8 |
| Combine | One pipeline: `$searchText` → `debounce` → `removeDuplicates` → `sink` → `Task` | `MovieSearchViewModel.swift` | None dedicated | Passing | Phase 7 documents/hardens this, doesn't rebuild it |
| Concurrency | `@MainActor` ViewModels/coordinators; project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; no actors anywhere yet | Project build settings; all ViewModel/Coordinator files | Coordinator tests exercise `@MainActor` code paths | Passing | Phase 6 introduces the first real actors |
| Testing | `AssignmentTests` (Swift Testing, 39 tests) + `AssignmentUITests` (XCTest, 1 smoke test) | `AssignmentTests/*.swift`, `AssignmentTests/Fakes/*.swift`, `AssignmentUITests/AssignmentUITests.swift` | 40 tests total, all passing | Passing | No networking/actor/UIKit-bridge tests yet — those arrive with Phases 4-6 |
| Documentation | `docs/ARCHITECTURE_REFACTOR_PLAN.md` (migration plan) + this `docs/Learning/` area | `docs/*.md`, `docs/Learning/*.md` | N/A | N/A | Kept in sync phase-by-phase per this file's own header note |

## Verification for this snapshot

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Assignment.xcodeproj -scheme Assignment \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO test
```
Result: **TEST SUCCEEDED**, 40/40 tests passing, 0 warnings (excluding the
unrelated, pre-existing "no AppIntents.framework dependency" notice).
