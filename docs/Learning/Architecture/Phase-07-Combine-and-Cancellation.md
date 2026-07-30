# Phase 7 — Combine and Cancellation Hardening

Status: **Implemented and verified**.

## 1. Previous implementation

`MovieSearchViewModel.setupSearchObserver()` already had the real shape
this phase was scoped to harden: `$searchText.debounce(for: .milliseconds(500),
scheduler: DispatchQueue.main).removeDuplicates().sink { ... }`, bridging
into a cancel-on-new-input `Task` for the actual network call. This
predates the migration and was never rebuilt from scratch - Phase 7's job
was to hardenit and make it testable, not redesign it. The one real gap:
`500` was a literal in the pipeline, not a parameter - every test that
needed to observe debounced behavior had to wait a real, generous margin
over 500ms (750ms, in the tests that existed through Phase 6).

## 2. Problem

Waiting 750ms per assertion made `MovieSearchViewModelTests` the slowest
file in the suite (the "search race" test alone took ~1.5s). That's not
just an inconvenience - slow tests are exactly the kind of thing that
gets skipped, run less often, or quietly deleted under time pressure. It
also meant the debounce *interval itself* had never been exercised at any
value other than 500ms, since there was no seam to change it.

## 3. Target responsibility

Make the debounce interval an injectable parameter, defaulting to the real
500ms in production. Use a small interval in tests. Verify cancellation
and stale-result rejection still hold under the faster interval. Document
the full pipeline and the Combine/async-await split.

## 4. Files introduced

None (a genuinely small, focused change - see §12 for why a larger
redesign wasn't warranted).

## 5. Files modified

- `Assignment/ViewModels/MovieSearchViewModel.swift` (`debounceInterval` parameter)
- `AssignmentTests/MovieSearchViewModelTests.swift` (rewritten to use short intervals; one new test)

## 6. Files removed

None.

## 7. Runtime flow before

```
$searchText
  .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)   // 500 hardcoded
  .removeDuplicates()
  .sink { query in ... starts a cancel-on-new-input Task ... }
```

## 8. Runtime flow after

```
init(searchMovies:, debounceInterval: .milliseconds(500))   // production default, unchanged behavior
  $searchText
    .debounce(for: debounceInterval, scheduler: DispatchQueue.main)   // now a parameter
    .removeDuplicates()
    .sink { query in ... same cancel-on-new-input Task logic, untouched ... }
```

Numbered, with file/type/method/context - see
`docs/Learning/COMBINE_SEARCH_PIPELINE.md` for the full operator-by-operator
walkthrough (kept as its own document since it's referenced from multiple
places and stands alone as the "how does this pipeline work" reference).

**Tests covering this:** `MovieSearchViewModelTests` (6, all now running
against a 5-20ms debounce instead of 500ms).

## 9. Code excerpts

**Exact production code** (`Assignment/ViewModels/MovieSearchViewModel.swift`):

```swift
init(searchMovies: SearchMoviesUseCase, debounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(500)) {
    self.searchMovies = searchMovies
    self.debounceInterval = debounceInterval
    setupSearchObserver()
}
```

## 10. Build evidence

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Assignment.xcodeproj -scheme Assignment \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean test
```
Result: **BUILD SUCCEEDED**, **TEST SUCCEEDED**, 0 warnings, 103/103 tests
passing.

A real, disclosed timing-tuning story from this phase: the first attempt
used a 5ms debounce and 60ms settle margin for *every* test, including the
two-cycle "search race" test. That one failed under normal test-suite load
(too tight a margin for a test with two sequential debounce-and-cancel
cycles plus real `Task` scheduling). Fixed by giving that specific test
looser margins (20ms debounce, 150ms settle, run three times back-to-back
during this phase's own verification to confirm stability) while keeping
the simpler single-debounce tests at the tighter 5ms/60ms - a concrete
example of "how fast can a timing-based test safely go" not being a single
fixed number, but a question of how many moving parts that particular test
has.

## 11. Test evidence

103 tests total (was 102). `MovieSearchViewModelTests` gained one test
(`rapidTypingOnlyTriggersOneSearchAfterTypingStops`, proving several rapid
`searchText` assignments collapse into exactly one use-case call) and had
its existing 5 tests rewritten to run against short debounce intervals -
the whole file now runs in well under a second combined, versus several
seconds before.

## 12. Alternatives

1. **A full virtual-time `Scheduler`** (the way RxTest's `TestScheduler`
   lets you simulate elapsed time without real delays). Rejected: Combine
   doesn't ship a public virtual-time scheduler, and building one
   correctly is a substantial undertaking for a two-screen app's one
   debounce pipeline - an injectable real interval, run short in tests,
   gets 90% of the benefit (fast, still-somewhat-timing-dependent tests)
   for a fraction of the engineering cost.
2. **Redesign the pipeline around `AsyncSequence` instead of Combine.**
   Rejected - the existing Combine pipeline already does exactly what's
   needed (`debounce` + `removeDuplicates` have direct, well-tested
   Combine operators; `AsyncSequence` doesn't have an equivalent
   `debounce` in the standard library), and rebuilding a working pipeline
   in a different framework for this phase's actual problem
   (untestable timing) would be scope creep.
3. **Leave `500` hardcoded, mark the timing tests as slow/skip-by-default.**
   Rejected - hides the problem rather than fixing it, and a "usually
   skipped" test suite is close to no test suite at all.

## 13. Trade-offs

Short-interval tests are still technically timing-dependent (they use
real `Task.sleep`, not a virtual clock) - see §12, alternative 1. This is
an accepted trade-off given Combine's lack of a public virtual scheduler,
not a claim that these tests are perfectly deterministic under arbitrary
system load.

## 14. Failure scenarios

**Search race** (the canonical scenario, already covered since Phase 3):
`MovieSearchViewModelTests.newQueryCancelsStaleInFlightSearch` - see
`docs/Learning/Architecture/Phase-03-Domain-and-Repository.md` §14 for the
original write-up; this phase only changed its timing, not its logic.

**Rapid typing**: `rapidTypingOnlyTriggersOneSearchAfterTypingStops` proves
`debounce` + `removeDuplicates` together mean six keystrokes in quick
succession produce exactly one use-case call, for the final value only -
not six calls, and not even two.

## 15. Interview Q&A

### Why is `debounce` handled with Combine but the network call itself with async/await?

**Strong answer:** `$searchText` is a *continuous stream* of values over
time - Combine's operators (`debounce`, `removeDuplicates`) are built
exactly for shaping streams like that. A single network request, by
contrast, is one asynchronous operation with one result - `async/await`
models that directly and more simply than wrapping it in a `Future` or a
single-value `Publisher` would.

**Code evidence:**
- `Assignment/ViewModels/MovieSearchViewModel.swift`'s `setupSearchObserver()` (Combine) and `search(query:)` (async/await)

**Follow-up question:** How do the two actually connect - what bridges a
Combine `sink` into a `Task`?

**Follow-up answer:** The `sink` closure itself: on each debounced,
deduplicated value, it cancels any previous `searchTask` and starts a new
`Task` wrapping the `async` `search(query:)` call. Combine owns "when to
react to input changes"; the `Task` owns "run this one async operation and
let it be cancelled."

**Senior counter-question:** Why not use `.map { query in Future { ... } }.switchToLatest()` to keep everything inside Combine?

**Counter-answer:** `Future` in Combine starts its work eagerly at
creation time, not at subscription time, and doesn't inherently cancel its
underlying work just because its subscriber is cancelled - wrapping
`async/await` network calls in `Future` for this reason is a known
foot-gun. `switchToLatest` would still need something to actually cancel
the *previous* async operation, which is exactly what
`Task`-cancellation already gives for free with the current design. There
was no reason to introduce that complexity for a case `Task` cancellation
already which handles correctly.

**Trade-off:** Two concurrency models in one file (Combine + async/await)
instead of one - accepted because each is used for what it's actually
good at, not because using only one would be simpler in any meaningful way.

**Failure scenario:** If `Future`-wrapping were used without careful
manual cancellation forwarding, a stale request could keep running (and
its result arrive late) even after the user typed a new query - exactly
the bug class `guard latest == query` and `Task` cancellation together
prevent in the current design.

**Weak answer:** "Combine is for reactive stuff, async/await is for async
stuff."

**Improved answer:** Names the actual mechanism (`Task` cancellation
triggered from a Combine `sink`), the actual alternative considered
(`Future`/`switchToLatest`), and the actual reason it wasn't used (eager
execution, no automatic cancellation forwarding).

## 16. Counter-questions

- "Why wasn't the debounce interval made configurable via a UI setting
  too, not just tests?" No product need identified for that - the
  injectable parameter exists for testability, not end-user
  configurability; adding a settings UI for it would be exactly the kind
  of speculative feature this migration's own rules warn against.
- "Could `removeDuplicates()` ever cause a real search to be silently
  dropped?" Only if the exact same string is typed twice in a row with no
  different characters in between - which correctly should *not* trigger
  a second identical search.

## 17. Exercises

**Observe:** Set a breakpoint inside the `.sink` closure in
`setupSearchObserver()`. Type a query character by character in the
running app and count how many times it's actually hit versus how many
characters were typed - proof of `debounce` collapsing rapid input.

**Modify:** Change the production default in `MovieSearchViewModel.init`
from `.milliseconds(500)` to `.milliseconds(250)`. Run the app and judge
whether search feels more responsive or just noisier (more in-flight
requests started and cancelled) - there's no single correct answer here,
it's a real product trade-off.

**Break intentionally:** Temporarily change
`MovieSearchViewModelTests.newQueryCancelsStaleInFlightSearch`'s Batman
delay from 2 seconds to 0 seconds (same speed as Avatar). Watch it become
flaky/fail - direct evidence of why the delay needs to comfortably outlast
the settle margins, not just be "long".

**Extend:** Add a test proving that typing the same query, clearing it,
then typing it again produces two separate use-case calls (not
deduplicated across the clear) - `removeDuplicates()` only suppresses
*consecutive* identical values, not identical values with something
different in between.

**Interview:** Without re-reading this document, explain why `Future` was
considered and rejected for wrapping the network call in this pipeline.

## 18. Remaining limitations

Timing-based tests, even at short intervals, are not immune to scheduling
jitter under extreme system load (§13) - a true virtual-time scheduler
would remove this, at a cost this project didn't judge worthwhile (§12).
No UI exposes the debounce interval as a setting (not a goal of this
phase). The Combine pipeline itself is otherwise unchanged from before
this migration began - Phase 7 hardened its testability, not its
behavior.
