# CineConnect — Current Implementation (source of truth)

Updated after every phase. If this table and the actual code disagree, the
code is right and this file is stale — file it as a bug in the migration,
don't trust the table blindly. Last updated: end of Phase 2 / start of
Phase 3, commit `95af1c4`.

| Area | Current implementation | Key files | Tests | Build status | Remaining gaps |
|---|---|---|---|---|---|
| Application composition | `AppDependencyContainer` owns the one `AuthManager` instance and builds `AppCoordinator`; `AssignmentApp.init()` constructs the container and stores the coordinator in `@StateObject` | `Assignment/App/AppDependencyContainer.swift`, `Assignment/AssignmentApp.swift` | `AppCoordinatorTests.dependencyContainerWiresACoordinator` | Passing | Container still has exactly one dependency (`AuthManager`) — grows as repository/networking phases add more |
| Authentication (state/routing) | `AuthManager` (singleton) tracks `isAuthenticated()` via `UserDefaults`; `AppCoordinator` reads it once at init and again via explicit `showAuth()`/`showMovies()` calls, not a live subscription yet | `Assignment/Utils/AuthManager.swift`, `Assignment/Coordinators/AppCoordinator.swift` | `AppCoordinatorTests` (5 tests) | Passing | Credentials still in plaintext `UserDefaults`; `AppCoordinator` doesn't yet *observe* auth state, it's told about changes via closures — Phase 5 |
| Navigation | `AppCoordinator` chooses `.auth`/`.movies` root; `MoviesCoordinator` owns a `@Published NavigationPath` and a typed `MoviesRoute` enum | `AppCoordinator.swift`, `MoviesCoordinator.swift`, `MoviesRoute.swift` | `AppCoordinatorTests`, `MoviesCoordinatorTests` | Passing | Only one route case (`.detail`) exists — enough for what the app does today |
| Search | `MovieSearchViewModel` (Combine debounce → `Task` → `MovieSearchAPIService`), injected by `MoviesCoordinator` into `MoviesListView` | `Assignment/ViewModels/MovieSearchViewModel.swift`, `Assignment/Views/MoviesListView.swift` | None dedicated yet (pre-existing behavior, not newly changed this phase) | Passing (builds; behavior untested) | No ViewModel tests exist for search yet — Phase 3 gap to close alongside the use-case introduction |
| Movie detail | `MovieDetailViewModel`, injected by `MoviesCoordinator` into `MovieDetailView` via the route's destination factory | `MovieDetailViewModel.swift`, `Assignment/Views/MovieDetailView.swift` | None dedicated yet | Passing | Same testing gap as search |
| Domain layer | Not yet separated — `Movie`/`MovieDetail` are plain structs already free of DTO leakage, but live under `Assignment/Models/`, not a `Domain/` folder | `Assignment/Models/Movie.swift`, `Assignment/Models/MovieDetail.swift` | `AssignmentTests.movieModelIsHashableAndCodable` | Passing | Phase 3 in progress |
| Repository layer | Does not exist yet — ViewModels' injected API services call `RemoteService` directly | `Assignment/Services/MovieSearchAPIService.swift`, `MovieDetailAPIService.swift` | None | Passing (current behavior unchanged) | Phase 3 in progress |
| Networking | `RemoteService`/`BaseAPIService` singleton-defaulted; known bugs still present: `isSuccess` only accepts exactly HTTP 200, search query is percent-encoded twice | `Assignment/Services/Remote/*.swift` | None | Passing (bugs not yet fixed) | Phase 4 |
| Credentials | Plaintext `UserDefaults`, singleton `AuthManager` | `Assignment/Utils/AuthManager.swift` | None | Passing | Phase 5 |
| Caching | `MovieCache` — plain class, file-backed, fallback-only, no TTL/eviction | `Assignment/Services/Cache/MovieCache.swift` | None | Passing | Phase 6 |
| Image loading | Plain SwiftUI `AsyncImage`, no app-level cache | `Assignment/Views/MoviesListView.swift`, `MovieDetailView.swift` | None | Passing | Phase 8 |
| Combine | One pipeline: `$searchText` → `debounce` → `removeDuplicates` → `sink` → `Task` | `MovieSearchViewModel.swift` | None dedicated | Passing | Phase 7 documents/hardens this, doesn't rebuild it |
| Concurrency | `@MainActor` ViewModels/coordinators; project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; no actors anywhere yet | Project build settings; all ViewModel/Coordinator files | Coordinator tests exercise `@MainActor` code paths | Passing | Phase 6 introduces the first real actors |
| Testing | `AssignmentTests` (Swift Testing, 6 tests) + `AssignmentUITests` (XCTest, 1 smoke test) | `AssignmentTests/*.swift`, `AssignmentUITests/AssignmentUITests.swift` | 10 tests total, all passing | Passing | No repository/mapper/networking tests yet — those arrive with the layers they test |
| Documentation | `docs/ARCHITECTURE_REFACTOR_PLAN.md` (migration plan) + this `docs/Learning/` area | `docs/*.md`, `docs/Learning/*.md` | N/A | N/A | Kept in sync phase-by-phase per this file's own header note |

## Verification for this snapshot

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Assignment.xcodeproj -scheme Assignment \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO test
```
Result: **TEST SUCCEEDED**, 10/10 tests passing, 0 warnings (excluding the
unrelated, pre-existing "no AppIntents.framework dependency" notice).
