# Concept → Code Map

Concept-first navigation into the codebase. A concept is only listed here
once it's actually implemented in production code and covered by at least
one passing test — see `CURRENT_IMPLEMENTATION.md` for planned concepts not
yet eligible for this table.

| Concept | Actual production implementation | Runtime use case | Test evidence | Learning document | Interview question |
|---|---|---|---|---|---|
| MVVM | `MovieSearchViewModel` + `MoviesListView`; `MovieDetailViewModel` + `MovieDetailView` | Search and detail presentation state | None dedicated yet (tracked gap, Phase 3) | `FILE_INDEX.md` | Why MVVM instead of MV (View + `@Observable` model directly)? |
| Coordinator | `AppCoordinator`, `AuthenticationCoordinator`, `MoviesCoordinator` | App root switching, login flow, search-to-detail navigation | `AppCoordinatorTests`, `MoviesCoordinatorTests` | `Architecture/Phase-01-Composition-Root-and-Coordinators.md`, `Architecture/Phase-02-Movies-Navigation-and-MVVM.md` | Why not `NavigationLink(destination:)` everywhere? |
| Dependency injection (constructor injection) | `AppDependencyContainer`, coordinators' required-parameter initializers, `MoviesCoordinator`'s ViewModel factories | App construction, feature construction | `AppCoordinatorTests.dependencyContainerWiresACoordinator` | `Architecture/Phase-01-Composition-Root-and-Coordinators.md` | Why no service locator? |
| Typed navigation route | `MoviesRoute` | Search-to-detail navigation | `MoviesCoordinatorTests.appendingDetailRouteGrowsPath` | `Architecture/Phase-02-Movies-Navigation-and-MVVM.md` | Why `Hashable` routes instead of pushing the domain model directly? |
| Coordinator-owned `NavigationPath` | `MoviesCoordinator.path` | Search-to-detail navigation | `MoviesCoordinatorTests.pathStartsEmpty` | `Architecture/Phase-02-Movies-Navigation-and-MVVM.md` | Why not let `NavigationStack` manage its own implicit path? |
| SwiftUI/UIKit interoperability | `LoginView` (`UIViewControllerRepresentable`) + `LoginViewController` | Web-based login | None (tracked gap, Phase 5) | `FILE_INDEX.md` (Phase 5 doc planned) | When do you need a `Coordinator` object on a `UIViewControllerRepresentable`, and when is a closure enough? |
| Combine debounce pipeline | `MovieSearchViewModel`'s `$searchText` → `debounce` → `removeDuplicates` → `sink` | Search-as-you-type | None dedicated yet (tracked gap, Phase 3/7) | `FILE_INDEX.md` (Phase 7 doc planned) | Why Combine for the text pipeline but async/await for the network call? |
| Structured `Task` + cancel-on-new-input | `MovieSearchViewModel.searchTask`, `MovieDetailViewModel` via `.task(id:)` | Rejecting stale search/detail responses | None dedicated yet (tracked gap) | `FILE_INDEX.md` | What happens when the user types a second query before the first search completes? |
| `@MainActor` presentation state | `MovieSearchViewModel`, `MovieDetailViewModel`, all coordinators | Every screen's observable state | Indirectly, via all coordinator/ViewModel tests running on the main actor | `FILE_INDEX.md` | Why is the ViewModel `@MainActor`-isolated instead of `Sendable` and isolation-agnostic? |
| Actor-isolated cache | *Planned* — no actor exists yet; today's `MovieCache` is a plain class | Shared cache state across concurrent search/detail requests | *Planned* | *Planned — Phase 6* | Why an actor instead of a lock-based class? |
| Repository boundary | *In progress* — Phase 3, not yet in production code | Search/detail data access | *In progress* | `Architecture/Phase-03-Domain-and-Repository.md` | Isn't the repository just forwarding methods? |
