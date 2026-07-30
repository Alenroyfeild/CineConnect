# Interview Guide

A cross-cutting index of every interview question this migration's own
phase documents answered from real, working code — not invented fresh for
this guide. Each entry gives the question, a one-line compressed answer,
and a link to that phase document's full **Strong answer / Code evidence /
Follow-up / Senior counter-question / Trade-off / Failure scenario / Weak
answer** treatment, which is where the actual depth lives. Read this guide
as a map, not a replacement for the phase docs it points into.

Assembled once every phase existed to assemble from — see
`docs/Learning/README.md`'s "Interview-preparation order" for why this
wasn't written earlier, invented from a topic list instead of real code.

## How to use this guide

1. Pick a theme below (or work top to bottom — themes roughly follow the
   phase order).
2. Read the one-line answer, then try answering the question yourself
   before opening the linked section.
3. Open the link. Compare your answer against the **Strong answer**, then
   read the **Follow-up** and **Senior counter-question** — most of the
   real interview signal is in how a candidate handles the counter-question,
   not the first answer.
4. Do the matching phase's exercises (`docs/LEARNING_EXERCISES.md`) before
   moving to a harder theme — several build on being able to read the
   previous phase's code fluently.

## Dependency injection and composition

**Why introduce a composition root instead of leaving default parameters that resolve `.shared`?**
One place resolves the singleton; everything downstream requires it explicitly, so replacing it later (Phase 5) is a one-file change, not a four-file hunt.
→ [`Architecture/Phase-01-Composition-Root-and-Coordinators.md` §15](Learning/Architecture/Phase-01-Composition-Root-and-Coordinators.md#15-interview-qa)

**Isn't `AppDependencyContainer` itself still touching `.shared`, so what changed?**
The *type* didn't change; the *access pattern* did — one composition root resolves it instead of every consumer independently deciding to.
→ same section, follow-up question

**Why do Views no longer construct their own ViewModels?**
A View → ViewModel-convenience-init → concrete-service chain meant no test or preview could substitute behavior without editing the View itself; the coordinator now constructs and injects both ViewModels.
→ [`Architecture/Phase-02-Movies-Navigation-and-MVVM.md` §15](Learning/Architecture/Phase-02-Movies-Navigation-and-MVVM.md#15-interview-qa)

## Navigation

**Why introduce a typed `MoviesRoute` instead of navigating with the `Movie` model directly?**
Using the domain model as the nav value conflates "this is data" with "this is a destination" — a single `Hashable` enum is what `NavigationPath` actually needs, and it's what absorbs a second destination later without touching the row view.
→ [`Architecture/Phase-02-Movies-Navigation-and-MVVM.md` §15](Learning/Architecture/Phase-02-Movies-Navigation-and-MVVM.md#15-interview-qa)

**With only one route case, isn't `MoviesRoute` over-engineering?**
The type-safety win is modest with one case; the *ownership* win (the coordinator, not the row, decides what "detail" means) already matters.
→ same section, follow-up question

## Repository and domain boundary

**Why did you introduce a repository?**
Two API services each duplicated cache-fallback policy *and* mishandled cancellation identically; `DefaultMovieRepository` gives that policy one home and fixed a real cancellation-vs-cache bug in the process.
→ [`Architecture/Phase-03-Domain-and-Repository.md` §15](Learning/Architecture/Phase-03-Domain-and-Repository.md#15-interview-qa)

**Isn't the repository just forwarding methods?**
For detail, almost — but it owns the network-vs-cache decision and correctly *not* falling back on cancellation. Honestly thin, plus one real correctness fix, not "does a ton."
→ same section, follow-up question

**When do use cases become unnecessary pass-through wrappers?**
`GetMovieDetailUseCase` is the honest example in this exact codebase — kept for dependency-shape consistency across ViewModels, documented as a deliberate pass-through rather than dressed up as doing real work.
→ [`Architecture/Phase-03-Domain-and-Repository.md` §15](Learning/Architecture/Phase-03-Domain-and-Repository.md#15-interview-qa)

## Networking

**Why fix `isSuccess` and the double-encoding bug in the same phase as adding retry/injection?**
All four changes touch the same small set of files for the same reason — "make networking correct and testable" — splitting genuinely related fixes across phases would fragment one coherent change for no reader benefit.
→ [`Architecture/Phase-04-Networking.md` §15](Learning/Architecture/Phase-04-Networking.md#15-interview-qa)

**How did you verify the double-encoding fix actually fixes the bug?**
`RemoteServiceTests.queryParametersAreEncodedExactlyOnce` asserts the sent URL contains `%20` and explicitly asserts it does *not* contain `%2520` — a test that would have failed against the old code.
→ same section, follow-up question

## Authentication and security

**Why introduce a `CredentialsStore` actor instead of just moving `UserDefaults` calls into a class?**
Two reasons: the Keychain is the platform's real secure-storage primitive (`UserDefaults` is plaintext), and wrapping it behind `SecureKeyValueStoring` is what made the logic testable at all — discovered the hard way via `errSecMissingEntitlement` in this project's unsigned build environment.
→ [`Architecture/Phase-05-Authentication.md` §15](Learning/Architecture/Phase-05-Authentication.md#15-interview-qa)

**Is the actor here protecting against a real data race?**
Honestly, not really — Keychain Services is already thread-safe at the OS level. The actor's real value is one async, testable interface, stated plainly rather than oversold as race protection.
→ same section, follow-up question

**What does `errSecMissingEntitlement` mean, and why did this project hit it?**
`-34018` — the Keychain requires an entitled, signed binary for `SecItemAdd`/`SecItemUpdate`; this project's `CODE_SIGNING_ALLOWED=NO` unsigned test builds can't write to it at all. Confirmed by a bare `swift` script on the Mac host succeeding outside the app sandbox.
→ [`Architecture/Phase-05-Authentication.md` §10](Learning/Architecture/Phase-05-Authentication.md#10-build-evidence) and §15

## Caching and actor concurrency

**Why does `InFlightRequestStore` need to be an actor, and what's the reentrancy risk if it weren't done carefully?**
Two concurrent callers must never both decide "nothing in flight" and each start their own request; the actor's serial execution makes the check-and-register step atomic *because there's no `await` between them*.
→ [`Architecture/Phase-06-Caching.md` §15](Learning/Architecture/Phase-06-Caching.md#15-interview-qa)

**What would break if you inserted an `await` between the check and the register?**
Every concurrent caller could interleave in that gap and each register its own task — coalescing would silently stop working, no crash, just N network calls instead of 1.
→ same section, follow-up question (and the matching exercise in `LEARNING_EXERCISES.md`)

**Why do search results get memory-only caching while movie details get memory *and* disk?**
Search results are cheap and change almost every keystroke; a detail page is comparatively stable and more expensive to lose — worth surviving a memory warning or relaunch.
→ [`Architecture/Phase-06-Caching.md` §15](Learning/Architecture/Phase-06-Caching.md#15-interview-qa)

## Combine and structured concurrency

**Why is `debounce` handled with Combine but the network call itself with async/await?**
`$searchText` is a continuous stream — Combine's operators are built for that; a single request/response is one async operation, which `async/await` models more directly than a `Future`-wrapped `Publisher`.
→ [`Architecture/Phase-07-Combine-and-Cancellation.md` §15](Learning/Architecture/Phase-07-Combine-and-Cancellation.md#15-interview-qa)

**Why not use `.map { Future { ... } }.switchToLatest()` to keep everything inside Combine?**
`Future` starts eagerly at creation, not subscription, and doesn't inherently cancel its work when its subscriber cancels — a known foot-gun for wrapping cancellable async work.
→ same section, senior counter-question

## Images

**Why build a custom `CachedAsyncImage` instead of just using `AsyncImage`?**
`AsyncImage`'s caching is entirely internal to `URLCache` — no visibility, no shared dedup with the rest of the app. `CachedAsyncImage` reuses the *same* `MemoryCache`/`InFlightRequestStore` actors already built and tested for movie data.
→ [`Architecture/Phase-08-Image-Pipeline.md` §15](Learning/Architecture/Phase-08-Image-Pipeline.md#15-interview-qa)

**When is SwiftUI environment injection the right call instead of constructor injection?**
When a dependency is used far deeper in the view hierarchy than the views around it have any other reason to know about — threading it through every intervening initializer would be worse for readability, not better.
→ same section, §12/§13

## Project quality, strict concurrency, and process

**Why enable `SWIFT_STRICT_CONCURRENCY = complete` at the end of the migration instead of the start?**
Doing the architecture work first, under the compiler's weaker default, meant each phase's own isolation fixes had full design context; turning strict mode on afterward found only three remaining issues project-wide — evidence incremental discipline worked, not proof the codebase was flawless before.
→ [`Architecture/Phase-09-Project-Quality.md` §15](Learning/Architecture/Phase-09-Project-Quality.md#15-interview-qa)

**Why weren't the critical-path UI tests this phase's own comment promised actually written?**
Accessibility identifiers (the stated prerequisite) landed; the tests themselves didn't, for scope reasons stated plainly rather than implied as done — see the same section's honest priority comparison against Phase 5's untested Keychain path.
→ same section

## A note on the weak-answer pattern

Nearly every phase doc's Interview Q&A ends with a **Weak answer** /
**Improved answer** pair. The pattern is consistent across all nine: the
weak answer states a general principle ("dependency injection is good for
testability," "actors prevent race conditions"); the improved answer names
the *specific* mechanism, the *specific* bug or constraint that forced the
design, and the *specific* test that would catch a regression. If you can't
fill in those three specifics for a question above without opening its
linked section, that's the signal to go read it, not to move on.
