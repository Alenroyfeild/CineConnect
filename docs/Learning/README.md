# CineConnect — Learning Area

This is the entry point for learning CineConnect's architecture from its
**actual, current implementation** — not from a description of where the
project is eventually headed. Every claim in this folder is checked against
real files, real tests, and a real build before it's written down; see
`docs/Learning/IMPLEMENTATION_JOURNAL.md` for the phase-by-phase record of
when each piece landed.

## Status labels used throughout this folder

- **Implemented and verified** — in production code, covered by a passing test, built successfully.
- **Implemented but partially tested** — in production code and building, but a real gap in test coverage is called out explicitly.
- **In progress** — being worked on in the current phase.
- **Planned** — designed/decided but not yet in the code. Never described using the same present-tense language as implemented work.
- **Intentionally not used** — considered and deliberately rejected, with the reason recorded.

## What's actually implemented right now

| Area | Status |
|---|---|
| Composition root (`AppDependencyContainer`) | Implemented and verified |
| App root switching (`AppCoordinator`) | Implemented and verified |
| Authentication coordinator | Implemented but partially tested (exercises the real `AuthManager.shared`, not a fake — see Phase 1 doc) |
| Movies navigation (`MoviesCoordinator`, `MoviesRoute`, coordinator-owned `NavigationPath`) | Implemented and verified |
| Injected `MovieSearchViewModel` / `MovieDetailViewModel` | Implemented and verified |
| Unit test target (Swift Testing) + UI test target (XCTest) | Implemented and verified |
| Security remediation (credential removal, history scrub, secret scanning) | Implemented and verified — see `../SECURITY.md` |
| Domain/repository/DTO/mapper boundary (`MovieRepository`, `DefaultMovieRepository`, use cases) | Implemented and verified |
| Networking (retry policy, `200..<300` fix, encoding fix, injected interceptor, structured errors) | Implemented and verified |
| Credentials store (Keychain-backed `CredentialsStore`) / UIKit auth bridge | Implemented and verified (real Keychain calls untested in this environment - see Phase 5 doc §10/§18) |
| Actor-based memory/disk caches, request coalescing | Implemented and verified |
| Combine/cancellation hardening | Planned (Phase 7 — the debounced search pipeline itself already exists from before this migration; Phase 7 is about hardening and documenting it, not building it from scratch) |
| Cached image pipeline | Planned (Phase 8) |
| Project renaming, accessibility, CI, final docs | Planned (Phase 9) |

## Reading order

1. `CURRENT_IMPLEMENTATION.md` — the one table that describes the whole app's current state.
2. `Architecture/Phase-01-Composition-Root-and-Coordinators.md`
3. `Architecture/Phase-02-Movies-Navigation-and-MVVM.md`
4. `Architecture/Phase-03-Domain-and-Repository.md`
5. `Architecture/Phase-04-Networking.md`
6. `Architecture/Phase-05-Authentication.md` — also read `../SWIFTUI_UIKIT_INTEROPERABILITY.md` alongside this one.
7. `Architecture/Phase-06-Caching.md` — read this one carefully if you're prepping for actor/concurrency interview questions; it has the project's clearest reentrancy example.
8. `FILE_INDEX.md` — once you want file-by-file depth.
9. `CONCEPT_TO_CODE_MAP.md` — once you want concept-first navigation instead of file-first.

Phase 7 (Combine/cancellation hardening) is next; its doc will appear here
once that phase actually lands.

## Code-reading order

1. [`Assignment/AssignmentApp.swift`](../../Assignment/AssignmentApp.swift) — entry point.
2. [`Assignment/App/AppDependencyContainer.swift`](../../Assignment/App/AppDependencyContainer.swift) — composition root.
3. [`Assignment/Coordinators/Coordinator.swift`](../../Assignment/Coordinators/Coordinator.swift), [`AppCoordinator.swift`](../../Assignment/Coordinators/AppCoordinator.swift), [`AuthenticationCoordinator.swift`](../../Assignment/Coordinators/AuthenticationCoordinator.swift), [`MoviesCoordinator.swift`](../../Assignment/Coordinators/MoviesCoordinator.swift), [`MoviesRoute.swift`](../../Assignment/Coordinators/MoviesRoute.swift).
4. [`Assignment/ViewModels/MovieSearchViewModel.swift`](../../Assignment/ViewModels/MovieSearchViewModel.swift), [`MovieDetailViewModel.swift`](../../Assignment/ViewModels/MovieDetailViewModel.swift).
5. [`Assignment/Views/MoviesListView.swift`](../../Assignment/Views/MoviesListView.swift), [`MovieDetailView.swift`](../../Assignment/Views/MovieDetailView.swift).

## Interview-preparation order

Each phase doc under `Architecture/` ends with its own interview Q&A,
counter-questions, and exercises for exactly what that phase implemented —
read them in the same order as the phase docs above. A cross-cutting
`docs/INTERVIEW_GUIDE.md` (outside this folder) is planned for Phase 9, once
every phase's questions already exist here and can be assembled rather than
invented fresh.

## Exercise order

Exercises live at the end of each phase document, scoped to what that phase
actually built. Do Phase 1's and Phase 2's exercises before Phase 3's — they
assume you can read the composition root and coordinator code fluently.

## Links to other documentation

- [`../ARCHITECTURE_REFACTOR_PLAN.md`](../ARCHITECTURE_REFACTOR_PLAN.md) — the full migration plan, phase list, and CC0–CC4 audit.
- [`../../SECURITY.md`](../../SECURITY.md) — the credential-exposure incident and remediation (kept in place, not moved here).
- Test suites: [`AssignmentTests/`](../../AssignmentTests/), [`AssignmentUITests/`](../../AssignmentUITests/).

## A note on folder structure

Only `Architecture/` and `Decisions/` exist under this folder so far. The
remaining topic folders (`Swift/`, `SwiftUI/`, `Concurrency/`, `Combine/`,
`Networking/`, `Caching/`, `Testing/`, `UIKitInteroperability/`,
`Interview/`, `Exercises/`) are created the moment a phase produces a real,
substantial document for them — not before. An empty folder with no content
would just be a broken promise the next reader trips over.
