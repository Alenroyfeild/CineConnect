# CineConnect — Current Implementation (source of truth)

Updated after every phase. If this table and the actual code disagree, the
code is right and this file is stale — file it as a bug in the migration,
don't trust the table blindly. Last updated: end of Phase 5.

| Area | Current implementation | Key files | Tests | Build status | Remaining gaps |
|---|---|---|---|---|---|
| Application composition | `AppDependencyContainer` owns the one `AuthManager` instance and builds `AppCoordinator`; `AssignmentApp.init()` constructs the container and stores the coordinator in `@StateObject` | `Assignment/App/AppDependencyContainer.swift`, `Assignment/AssignmentApp.swift` | `AppCoordinatorTests.dependencyContainerWiresACoordinator` | Passing | Container still has exactly one dependency (`AuthManager`) — grows as repository/networking phases add more |
| Authentication (state/routing) | `AuthManager` (singleton) is a thin `@MainActor` wrapper over the Keychain-backed `CredentialsStore` actor; `AppCoordinator.start()` asynchronously refreshes real state at launch, `root` starts at the safe `.auth` default until then | `Assignment/Utils/AuthManager.swift`, `Assignment/Storage/CredentialsStore.swift`, `Assignment/Coordinators/AppCoordinator.swift` | `AuthManagerTests` (5), `CredentialsStoreTests` (5), `AppCoordinatorTests` (6) | Passing | `AuthManager` is still a singleton *type* (only its storage is swappable); `AppCoordinator` still doesn't subscribe to *ongoing* auth-state changes after launch |
| Navigation | `AppCoordinator` chooses `.auth`/`.movies` root; `MoviesCoordinator` owns a `@Published NavigationPath` and a typed `MoviesRoute` enum | `AppCoordinator.swift`, `MoviesCoordinator.swift`, `MoviesRoute.swift` | `AppCoordinatorTests`, `MoviesCoordinatorTests` | Passing | Only one route case (`.detail`) exists — enough for what the app does today |
| Search | `MovieSearchViewModel` (Combine debounce → `Task` → `SearchMoviesUseCase` → `MovieRepository`), injected by `MoviesCoordinator` into `MoviesListView` | `Assignment/ViewModels/MovieSearchViewModel.swift`, `Assignment/Domain/UseCases/SearchMoviesUseCase.swift` | `MovieSearchViewModelTests` (5), `SearchMoviesUseCaseTests` (5) | Passing | Combine debounce timing still fixed at 500ms, not injectable (Phase 7) |
| Movie detail | `MovieDetailViewModel` → `GetMovieDetailUseCase` → `MovieRepository`, injected by `MoviesCoordinator` via the route's destination factory | `MovieDetailViewModel.swift`, `Assignment/Domain/UseCases/GetMovieDetailUseCase.swift` | `MovieDetailViewModelTests` (3), `GetMovieDetailUseCaseTests` (2) | Passing | `GetMovieDetailUseCase` is a deliberate pass-through (documented, not hidden) |
| Domain layer | `Movie`/`MovieDetail` moved to `Assignment/Domain/Models/`; `MovieRepository` protocol added | `Assignment/Domain/Models/Movie.swift`, `MovieDetail.swift`, `Assignment/Domain/MovieRepository.swift` | `AssignmentTests.movieModelIsHashableAndCodable`, all repository/use-case tests exercise the protocol indirectly | Passing | No `Sendable` conformance on `MovieRepository` yet (needs its dependencies audited first — Phase 4/6) |
| Repository layer | `DefaultMovieRepository` coordinates the remote data source and `MovieCache` fallback; found and fixed a cancellation-vs-failure bug in the process | `Assignment/Data/DefaultMovieRepository.swift` | `DefaultMovieRepositoryTests` (5) | Passing | No `CachePolicy` parameter yet - only one implicit policy exists (Phase 6) |
| Networking | `RemoteService` built once by `AppDependencyContainer`, threaded through `MoviesCoordinator` (no more `.shared` default anywhere); `isSuccess` fixed to `200..<300`; double-percent-encoding fixed; bounded retry policy for GET requests; structured server-error decoding | `Assignment/Services/Remote/*.swift`, `Assignment/Services/MovieSearchAPIService.swift`, `MovieDetailAPIService.swift` | `RemoteServiceTests` (9), `RetryPolicyTests` (7), `RemoteErrorTests` (4) | Passing | No structured/redacted logging yet (Phase 9) |
| Credentials | Keychain-backed via `CredentialsStore`/`KeychainStore` (Phase 5, replacing plaintext `UserDefaults`); `AuthManager` conforms to `AuthHeaderProviding`; all credential-prefix logging removed | `Assignment/Storage/CredentialsStore.swift`, `KeychainStore.swift`, `Assignment/Utils/AuthManager.swift` | `CredentialsStoreTests` (5, via in-memory fake), `AuthManagerTests` (5) | Passing | Real Keychain calls (`KeychainStore` itself) not covered by automated tests in this environment - `errSecMissingEntitlement` on unsigned builds; needs manual verification on a signed run |
| Caching | `MovieCache` — plain class, file-backed, fallback-only, no TTL/eviction; ownership of the fallback *policy* moved to `DefaultMovieRepository` in Phase 3 (the cache type itself is unchanged) | `Assignment/Services/Cache/MovieCache.swift`, `Assignment/Data/DefaultMovieRepository.swift` | `DefaultMovieRepositoryTests` (cache-fallback + cancellation tests) | Passing | Still not actor-isolated, no TTL/eviction (Phase 6) |
| Image loading | Plain SwiftUI `AsyncImage`, no app-level cache | `Assignment/Views/MoviesListView.swift`, `MovieDetailView.swift` | None | Passing | Phase 8 |
| Combine | One pipeline: `$searchText` → `debounce` → `removeDuplicates` → `sink` → `Task` | `MovieSearchViewModel.swift` | None dedicated | Passing | Phase 7 documents/hardens this, doesn't rebuild it |
| Concurrency | `@MainActor` ViewModels/coordinators; project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; no actors anywhere yet | Project build settings; all ViewModel/Coordinator files | Coordinator tests exercise `@MainActor` code paths | Passing | Phase 6 introduces the first real actors |
| Testing | `AssignmentTests` (Swift Testing, 75 tests) + `AssignmentUITests` (XCTest, 1 smoke test) | `AssignmentTests/*.swift`, `AssignmentTests/Fakes/*.swift`, `AssignmentUITests/AssignmentUITests.swift` | 76 tests total, all passing | Passing | No actor-based cache tests yet (Phase 6); real Keychain calls untested in this environment (documented limitation, not silently skipped) |
| Documentation | `docs/ARCHITECTURE_REFACTOR_PLAN.md` (migration plan) + this `docs/Learning/` area | `docs/*.md`, `docs/Learning/*.md` | N/A | N/A | Kept in sync phase-by-phase per this file's own header note |

## Verification for this snapshot

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Assignment.xcodeproj -scheme Assignment \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO test
```
Result: **TEST SUCCEEDED**, 76/76 tests passing, 0 warnings (excluding the
unrelated, pre-existing "no AppIntents.framework dependency" notice).
