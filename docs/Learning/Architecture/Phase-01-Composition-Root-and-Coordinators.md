# Phase 1 — Composition Root, Test Infrastructure, and Coordinator DI

Status: **Implemented and verified**. Commits `ae220c9` (test targets),
`a1abfdd` (composition root).

## 1. Previous implementation

`AppCoordinator()` self-constructed everything: `AuthCoordinator(authManager:
AuthManager = .shared)` and `MoviesCoordinator(authManager: AuthManager =
.shared)` each independently defaulted to the process-wide singleton. There
was also no test target at all — `xcodebuild -list` showed one target, one
scheme, zero tests.

## 2. Problem

Three separate default-parameter call sites reaching `AuthManager.shared`
meant "the singleton is used in one controlled place" wasn't true, and
nothing could substitute a fake `AuthManager` even if one existed, because
nothing forced dependencies through a single seam. And with zero tests,
none of this — or anything else — had regression protection.

## 3. Target responsibility

One composition root (`AppDependencyContainer`) resolves the singleton;
every coordinator requires its dependency with no default; a real test
target exists to verify it.

## 4. Files introduced

- `Assignment/App/AppDependencyContainer.swift`
- `AssignmentTests/AssignmentTests.swift`, `AssignmentTests/AppCoordinatorTests.swift`
- `AssignmentUITests/AssignmentUITests.swift`
- Two new native targets in `Assignment.xcodeproj/project.pbxproj`

## 5. Files modified

- `Assignment/AssignmentApp.swift` — builds the container, gets the
  coordinator from it.
- `Assignment/Coordinators/AppCoordinator.swift` — `init(authManager:)` no
  longer defaults.
- `Assignment/Coordinators/MoviesCoordinator.swift` — same.
- `Assignment/Coordinators/AuthCoordinator.swift` → renamed
  `AuthenticationCoordinator.swift`, same default removed.

## 6. Files removed

None.

## 7. Runtime flow before

```
AssignmentApp.body
  → AppCoordinator()                              // self-constructs
      → AuthCoordinator(authManager: .shared)      // reaches singleton itself
      → MoviesCoordinator(authManager: .shared)    // reaches singleton itself
```

## 8. Runtime flow after

```
AssignmentApp.init()
  → AppDependencyContainer(authManager: nil)
      → resolves authManager ?? AuthManager.shared   // ONE place
  → container.makeAppCoordinator()
      → AppCoordinator(authManager: container.authManager)   // required, no default
          → AuthenticationCoordinator(authManager:)           // required, no default
          → MoviesCoordinator(authManager:)                   // required, no default
  → StateObject(wrappedValue: coordinator)
```

Each numbered step, with file/type/method/context:

1. **File:** `AssignmentApp.swift` · **Type:** `AssignmentApp` · **Method:**
   `init()` · **Context:** SwiftUI app launch, main thread.
2. **File:** `AppDependencyContainer.swift` · **Type:** `AppDependencyContainer`
   · **Method:** `init(authManager:)` · **Context:** `@MainActor`. No
   suspension point, no cancellation, no error path — pure construction.
3. **File:** `AppDependencyContainer.swift` · **Method:**
   `makeAppCoordinator()` · same context.
4. **File:** `AppCoordinator.swift` · **Method:** `init(authManager:)` ·
   `@MainActor`. Reads `authManager.isAuthenticated()` synchronously
   (`UserDefaults` lookup, no suspension).
5. **File:** `AssignmentApp.swift` · the result is handed to
   `StateObject(wrappedValue:)`.

**Test covering this flow:** `AppCoordinatorTests.dependencyContainerWiresACoordinator`.

## 9. Code excerpts

**Exact production code** (`Assignment/App/AppDependencyContainer.swift`):

```swift
@MainActor
final class AppDependencyContainer {
    let authManager: AuthManager

    init(authManager: AuthManager? = nil) {
        self.authManager = authManager ?? AuthManager.shared
    }

    func makeAppCoordinator() -> AppCoordinator {
        AppCoordinator(authManager: authManager)
    }
}
```

**Exact production code** (`Assignment/Coordinators/AppCoordinator.swift`,
the changed initializer only):

```swift
init(authManager: AuthManager) {
    self.authManager = authManager
    self.root = authManager.isAuthenticated() ? .movies : .auth
    self.authCoordinator = AuthenticationCoordinator(authManager: authManager)
    self.moviesCoordinator = MoviesCoordinator(authManager: authManager)
    ...
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

## 11. Test evidence

`AppCoordinatorTests` — 6 tests, all passing:
`startsAtAuthRootWhenNotAuthenticated`, `startsAtMoviesRootWhenAuthenticated`,
`showMoviesAndShowAuthUpdateRoot`, `authCoordinatorCompletionBubblesToAppCoordinator`,
`moviesCoordinatorLogoutBubblesToAppCoordinator`, `dependencyContainerWiresACoordinator`.

## 12. Alternatives

1. **Leave the default parameters, add a test-only override** — rejected:
   the default is the actual production bug (implicit singleton access),
   not something to preserve alongside a test seam.
2. **A protocol-based `AppDependencyContainerProtocol`** — rejected as
   premature: there is exactly one container implementation and no current
   need to substitute a different one (previews/tests can just construct
   `AppDependencyContainer()` directly, which already resolves
   `AuthManager.shared` — not ideal, but not worse than before, and not
   worth an empty-boundary protocol yet per the "no protocols without a
   substitution need" rule).
3. **A value-type container (struct of closures)** — considered, deferred;
   see `FILE_INDEX.md`'s entry for `AppDependencyContainer`.

## 13. Trade-offs

Removing the default parameters means every coordinator initializer call
site (including tests and any future preview code) must supply
`authManager` explicitly — slightly more verbose, in exchange for making
"where does the singleton get touched" a single, greppable answer.

## 14. Failure scenarios

**Actor-isolation warning caught during this phase:** the container's first
draft used `init(authManager: AuthManager = AuthManager.shared)` — a
default-argument expression referencing a `@MainActor`-isolated static
property. This produced: *"main actor-isolated static property 'shared' can
not be referenced from a nonisolated context."* Fixed by resolving the
value inside the init body instead (`authManager ?? AuthManager.shared`),
which runs with the type's own actor isolation. See `FILE_INDEX.md`'s
`AppDependencyContainer` entry, "Isolation," for the full explanation.

## 15. Interview Q&A

### Why did you introduce a composition root instead of leaving default parameters?

**Strong answer:** Default parameters that resolve `.shared` mean every
consumer *can* bypass injection, and in this codebase, three different
coordinators did. `AppDependencyContainer` makes the container the one type
allowed to resolve the singleton; everything downstream requires the
dependency explicitly, so there's exactly one place to look when the
singleton eventually gets replaced (Phase 5).

**Code evidence:**
- `Assignment/App/AppDependencyContainer.swift`
- `Assignment/Coordinators/AppCoordinator.swift:16-21` (required parameter, no default)
- Test: `AppCoordinatorTests.dependencyContainerWiresACoordinator`

**Follow-up question:** Doesn't `AppDependencyContainer` itself still
default to `.shared`?

**Follow-up answer:** Yes — deliberately. A composition root has to resolve
its foundational singletons *somewhere*; the goal isn't "no code anywhere
ever touches `.shared`," it's "exactly one type does, and everything else
receives it as a parameter."

**Senior counter-question:** Isn't the underlying `AuthManager` still a
singleton class, so what did this actually change functionally?

**Counter-answer:** Correct that the *type* hasn't changed — `AuthManager`
is still `class AuthManager { static let shared = AuthManager() }`. What
changed is the *access pattern*: before, four places (three coordinators +
the composition root once it existed) could each independently decide to
use `.shared`; now, one place does, and everything else is forced through
a constructor parameter. That's what makes swapping `AuthManager` for a
protocol-backed type in Phase 5 a one-file change to this container instead
of a four-file hunt.

**Trade-off:** More constructor parameters to thread through; in exchange,
a single, auditable resolution point.

**Failure scenario:** If a new coordinator were added and someone wrote
`init(authManager: AuthManager = .shared)` again out of habit, nothing
currently stops it at compile time — this is enforced by convention and
code review, not the type system. A lint rule or a `@available(*, deprecated)`-style
guard is a reasonable future hardening step, not yet added (would be
"educational but not yet exercised" territory — flagged, not built,
since there's no current second occurrence to actually guard against).

**Weak answer:** "It's a dependency injection container so things are
testable."

**Improved answer:** It's specifically the single point that resolves
`AuthManager.shared`, which is what lets `AppCoordinatorTests` construct
coordinators with an explicit `AuthManager` reference instead of each test
needing to know about the singleton independently — and it's the seam
Phase 5 will use to swap `AuthManager` for something actually mockable.

## 16. Counter-questions

- "If `AppDependencyContainer` disappeared, would the app still compile?"
  No — `AssignmentApp` has nothing else that resolves `AuthManager` for the
  now-parameter-required coordinators.
- "Why is the container a class and not a struct?" See `FILE_INDEX.md`'s
  Type Choice section for `AppDependencyContainer.swift`.

## 17. Exercises

**Observe:** Set a breakpoint in `AppDependencyContainer.init`. Launch the
app and confirm it's hit exactly once per app launch, before any
coordinator is constructed.

**Modify:** Add a second dependency to `AppDependencyContainer` (e.g., an
`AppLogger` placeholder — see the "no concept merely to create
documentation" rule in the migration brief before doing this for real;
this exercise is about the mechanics of adding a dependency, not about
shipping a real logger yet). Predict which files need to change before you
run the build.

**Break intentionally:** Temporarily add back `= .shared` to
`AppCoordinator.init(authManager: AuthManager = .shared)`. Run
`AppCoordinatorTests` — do they still pass? (They should — this is exactly
why "it compiles and tests pass" isn't sufficient proof an architecture
rule is being followed; only code review / a grep-based check catches this
class of regression.) Restore the required parameter afterward.

**Extend:** Add a `makeAuthenticationCoordinator()` factory method to
`AppDependencyContainer` that `AppCoordinator` could use instead of
constructing `AuthenticationCoordinator` itself — would that change where
"child coordinator ownership" lives? (It wouldn't have to — `AppCoordinator`
can still *own* the instance even if the container's factory *constructs*
it — a good way to feel out the ownership-vs-construction distinction.)

**Interview:** Without re-reading this document, explain out loud why
`AppDependencyContainer.init` resolves `AuthManager.shared` inside the
function body instead of as a default parameter value.

## 18. Remaining limitations

`AuthenticationInterceptor` and `LoginViewController` still read
`AuthManager.shared` directly — not touched by this phase on purpose (see
`docs/ARCHITECTURE_REFACTOR_PLAN.md` §1c and `FILE_INDEX.md`'s
`LoginViewController` entry). `AppCoordinator` doesn't yet *subscribe* to
authentication-state changes, only reads it once at construction and
reacts via explicit closures — a real gap, see this doc's §15 counter-answer.

---

# Before/after: coordinator dependency construction

## Before

```swift
@MainActor
final class AppCoordinator: ObservableObject {
    init(authManager: AuthManager = .shared) {
        self.authManager = authManager
        self.authCoordinator = AuthCoordinator(authManager: authManager)
        self.moviesCoordinator = MoviesCoordinator(authManager: authManager)
        ...
    }
}
```

Problems:
- Three coordinators (this one plus its two children) each independently
  default to `.shared` — "the singleton is used in one place" was false.
- A test wanting to substitute a fake `AuthManager` has no seam other than
  swapping the global singleton itself.
- Nothing marks which type is *supposed to* be the one place resolving the
  singleton.

## After

```swift
@MainActor
final class AppDependencyContainer {
    let authManager: AuthManager
    init(authManager: AuthManager? = nil) {
        self.authManager = authManager ?? AuthManager.shared
    }
    func makeAppCoordinator() -> AppCoordinator {
        AppCoordinator(authManager: authManager)
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    init(authManager: AuthManager) {   // no default
        self.authManager = authManager
        self.authCoordinator = AuthenticationCoordinator(authManager: authManager)
        self.moviesCoordinator = MoviesCoordinator(authManager: authManager)
        ...
    }
}
```

- Who now creates the coordinator: `AppDependencyContainer`, via
  `AssignmentApp.init()`.
- How dependencies are supplied: as required initializer parameters, all
  the way down.
- How previews/tests construct it: `AppCoordinatorTests` passes
  `.shared` explicitly today (the real gap: it's still the *same*
  singleton instance, not a fake — tracked for Phase 5, not hidden).
