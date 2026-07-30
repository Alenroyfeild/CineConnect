# Phase 9 — Strict Concurrency, Accessibility, CI, and the Project Rename

Status: **Implemented and verified**. Commits `8f8cd97` (9a: strict
concurrency, accessibility, CI) and `fd8e032` (9b: Assignment → CineConnect
rename).

This phase is split into two sub-phases in the commit history because they
touch genuinely different concerns — 9a changes build settings and adds new
capability (stricter compiler checking, accessibility, CI); 9b is a pure
rename with no behavioral change. Documented together since both are
"project quality" work with no new architectural concept of their own, unlike
Phases 1-8.

## 1. Previous implementation

The project built without `SWIFT_STRICT_CONCURRENCY` set explicitly (Xcode's
default, weaker than `complete`). `LoginViewController` was not `@MainActor`
-annotated despite being UIKit/main-thread-bound in practice (a gap tracked
since Phase 4/5's docs). `HotstarCredentialExtractor` had no isolation
annotation. No view in the app exposed accessibility identifiers, so no UI
test could reliably target a specific button or row. `CineConnectUITests`
(then `AssignmentUITests`) had exactly one smoke test
(`testAppLaunches`) and said so in its own comment: *"Critical-path UI tests
(search, detail, logout) land in Phase 9 once the app exposes stable
accessibility identifiers."* No CI workflow existed at all. The project,
target, scheme, and bundle identifier were still named `Assignment`
throughout — a placeholder name from before this migration had a real
product identity.

## 2. Problem

Without `SWIFT_STRICT_CONCURRENCY = complete`, this migration's own actor-
isolation discipline (Phases 1, 3, 4, 5, 6, all hitting real isolation
warnings and fixing them) was being checked at a *weaker* level than Swift 6
will eventually require by default — passing today's build doesn't prove
the code is actually Swift 6-clean. No accessibility identifiers meant the
UI test target's own comment describing planned critical-path tests was an
unfulfillable promise: `XCUIApplication` queries need a stable identifier or
label to target a specific element reliably, and none existed. No CI meant
every verification in this entire session (108 tests, zero warnings, clean
secret scan) was only ever checked locally, with no independent, repeatable
gate on future changes. `Assignment` as a product name was never accurate —
this is a movie-browsing app, not a generic take-home assignment — and every
day it stayed that way was a day of drift between the project's real
identity and its literal file/target names.

## 3. Target responsibility

**9a:** Turn on `SWIFT_STRICT_CONCURRENCY = complete`, fix whatever it
surfaces (informed by, not starting from scratch on top of, five phases of
prior isolation fixes). Add accessibility identifiers to the views a UI test
would actually need to target. Add a CI workflow that runs the same
build+test command used throughout this session.

**9b:** Rename every file, folder, target, scheme, bundle identifier, and
doc reference from `Assignment`/`AssignmentTests`/`AssignmentUITests` to
`CineConnect`/`CineConnectTests`/`CineConnectUITests`, with no behavioral
change, verified by a full clean build and test run before and after.

## 4. Files introduced

- `.github/workflows/build-and-test.yml`

No new Swift source files — this phase modifies build settings, existing
views, and existing project/file names; it introduces no new type.

## 5. Files modified

**9a:**
- `CineConnect.xcodeproj/project.pbxproj` (`SWIFT_STRICT_CONCURRENCY = complete;` added to all 6 Debug/Release configuration lists across the app, unit-test, and UI-test targets)
- `CineConnect/Views/Login/LoginViewController.swift` (`@MainActor` added to the class; `WKNavigationDelegate`'s `decidePolicyFor:` rewritten to the SDK's real 3-parameter, `@MainActor`-closured signature — see §9)
- `CineConnect/Views/Login/HotstarCredentialExtractor.swift` (`nonisolated` added to the enum)
- `AssignmentUITests/AssignmentUITests.swift` (`@MainActor` added to the class — pre-rename filename at the time)
- `CineConnect/Views/MoviesListView.swift` (`accessibilityIdentifier`/`accessibilityLabel` on the logout button, `accessibilityIdentifier` on each row and the results list, `accessibilityElement(children: .combine)` on the row)
- `CineConnect/Views/MovieDetailView.swift` (`accessibilityIdentifier("movieDetailScreen")`)

**9b:** every file under `Assignment/`, `AssignmentTests/`, `AssignmentUITests/`, and `Assignment.xcodeproj/` (renamed, contents text-substituted), plus every `docs/*.md` file and `README.md` (text substitution, and — for `README.md` specifically — a full content rewrite, since it had drifted architecturally stale well before this phase; see its own commit).

## 6. Files removed

None (9b renames, it doesn't delete — `git mv` on directories, then `sed`
inside file contents).

## 7. Runtime flow before

Not applicable in the usual sense — this phase changes build-time checking,
static accessibility metadata, and CI/naming, not a runtime data flow. The
one runtime-relevant before/after is `LoginViewController`'s
`WKNavigationDelegate` conformance:

```
LoginViewController: WKNavigationDelegate
  func webView(_:decidePolicyFor:decisionHandler:)   // 2-param form
    // compiles and runs (WebKit calls it via a compatibility path)
    // but does not actually override the delegate's real requirement
```

## 8. Runtime flow after

```
@MainActor class LoginViewController: UIViewController, WKNavigationDelegate
  func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    preferences: WKWebpagePreferences,
    decisionHandler: @escaping @MainActor (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
  )   // the SDK's actual current requirement, now genuinely overridden
```

Numbered, with file/type/method/context:

1. **File:** `LoginViewController.swift` · class-level `@MainActor` ·
   applies to every method and stored property in the type, not just the
   delegate method — this is what let the delegate conformance below
   actually type-check against `WKNavigationDelegate`'s real, main-actor
   -isolated closure parameter.
2. **File:** `LoginViewController.swift` · `webView(_:decidePolicyFor:preferences:decisionHandler:)`
   · called by WebKit on a navigation decision; `decisionHandler` is invoked
   synchronously within the method body, no suspension point.

**Tests covering this:** none directly (UIKit-lifecycle-bound, same
documented gap as Phase 5) — verified by the build itself: this is a case
where the *absence* of a compiler warning under `SWIFT_STRICT_CONCURRENCY =
complete` is the evidence, not a passing assertion.

## 9. Code excerpts

**Exact production code** (`CineConnect/Views/Login/LoginViewController.swift`,
the fixed delegate method):

```swift
@MainActor
class LoginViewController: UIViewController {
    ...
}

extension LoginViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if let url = navigationAction.request.url {
            if url.absoluteString.contains("apps.apple.com") || url.absoluteString.contains("itunes.apple.com") {
                decisionHandler(.cancel, preferences)
                return
            }
        }
        decisionHandler(.allow, preferences)
    }
}
```

**Exact production code** (`CineConnect/Views/MoviesListView.swift`, the
accessibility identifiers a UI test would actually target):

```swift
Button(action: logout) { ... }
    .accessibilityIdentifier("logoutButton")
    .accessibilityLabel("Logout")

// each row:
    .accessibilityIdentifier("movieRow-\(movie.id)")
    .accessibilityElement(children: .combine)

// the list itself:
    .accessibilityIdentifier("movieSearchResultsList")
```

## 10. Build evidence

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CineConnect.xcodeproj -scheme CineConnect \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean test
```
Result (9a): **BUILD SUCCEEDED**, **TEST SUCCEEDED**, 0 warnings under
`SWIFT_STRICT_CONCURRENCY = complete`, 108/108 tests passing.
Result (9b, after every rename): **BUILD SUCCEEDED**, **TEST SUCCEEDED**, 0
warnings, 108/108 tests passing — re-run in full after the rename to prove
it changed names, not behavior.

**How much of Phases 1-8's prior isolation work actually paid off here:**
turning on `SWIFT_STRICT_CONCURRENCY = complete` for the first time, after
five phases of already fixing every `nonisolated`/`nonisolated(unsafe)`/
default-argument-isolation issue those phases hit along the way (Phases 1,
3, 4, 5, 6), surfaced only **three** remaining real issues project-wide —
`LoginViewController`'s missing `@MainActor` (and the delegate-signature
mismatch it was masking), `HotstarCredentialExtractor` needing `nonisolated`,
and the UI test class needing `@MainActor`. A project that had deferred all
that isolation work to this one phase would have hit dozens of these at
once instead of three; doing it incrementally, phase by phase, is exactly
why this phase's own list is this short.

**The rename's own verification (9b), disclosed in full:** `git mv` on every
top-level directory (`Assignment/` → `CineConnect/`, etc.) and the two
top-level test files that `sed` alone wouldn't rename (`AssignmentTests.swift`
→ `CineConnectTests.swift`, `AssignmentUITests.swift` → `CineConnectUITests.swift`
— caught by re-running `check-docs-links.sh` after the first pass, which
flagged a stale path reference), followed by `sed -i '' 's/Assignment/CineConnect/g'`
across every `.swift` file in the renamed directories, `project.pbxproj`
(validated with `plutil -lint` after, 0→0 remaining `Assignment` occurrences),
and every `docs/*.md`/`README.md` file. `DEVELOPMENT_TEAM` and
`CODE_SIGN_STYLE` were confirmed unchanged (not part of the rename's scope).
`xcodebuild -list` confirmed the renamed targets/scheme resolve correctly
before the first post-rename build was attempted.

## 11. Test evidence

No new tests this phase (accessibility identifiers and a rename don't
themselves need new test coverage — the acid test is that the existing 108
still pass unchanged). 108/108 passing before and after both 9a and 9b.

## 12. Alternatives

1. **Fix strict-concurrency issues lazily, only when Swift 6 eventually
   forces the setting.** Rejected — this migration's whole point is
   demonstrating disciplined concurrency; deferring the actual strict
   check to some future forced migration would leave every phase's isolation
   claims unverified against the real compiler mode.
2. **Skip accessibility identifiers until a UI test actually needs one.**
   Rejected — `CineConnectUITests`'s own header comment already promised
   critical-path tests "once the app exposes stable accessibility
   identifiers"; adding the identifiers is the honest first step toward
   actually keeping that promise, even though (see §18) the critical-path
   tests themselves aren't written yet.
3. **Pin a specific Xcode version in CI instead of selecting the latest at
   runtime.** Rejected for this environment: this session cannot inspect
   GitHub's actual runner image contents, so pinning a version risked
   pinning one that doesn't exist on the runner; selecting "latest available"
   is more resilient to that unknown, at the cost of not reproducing this
   exact local Xcode version in CI.
4. **Rename the project in the very first commit of this migration, before
   any architecture work.** Rejected then and confirmed correct in hindsight
   now: the mega-prompt's own instruction was to protect behavior with tests
   first, rename last, in its own isolated commit — doing it now, after 108
   tests exist to catch a rename mistake, is strictly safer than doing it
   when the only regression protection was "the app still launches."

## 13. Trade-offs

The CI workflow's "select the latest Xcode/simulator at runtime" strategy
(§12, alternative 3) trades reproducibility (the exact toolchain version CI
uses can silently change between runs as GitHub updates its runner images)
for resilience against pinning a version that turns out not to exist there
— a reasonable default for a personal/learning project without an existing
CI history to know what's actually available, but not what a team with
release-stability requirements would typically choose.

## 14. Failure scenarios

**What if `SWIFT_STRICT_CONCURRENCY = complete` had surfaced a data race
this session's manual review had missed?** That's exactly what compiling
under the stricter mode is *for* — the fact that only three, all
non-data-race, issues surfaced (a missing annotation, a signature mismatch,
and a missing isolation marker — not an actual detected race) is evidence
the incremental Phase 1-8 discipline worked, not proof no race could ever
exist; strict concurrency checking catches isolation-safety violations at
compile time, but it can't catch every possible logical race a determined
enough adversarial input could still find.

**What if the rename had missed a file?** `check-docs-links.sh`'s
backtick-quoted-path check caught exactly this once (§10) — a stale
`AssignmentTests.swift`/`AssignmentUITests.swift` filename reference that
the directory-level `git mv` plus content-level `sed` had both missed,
because the *files themselves* still had their old names even after their
*parent directories* were renamed and their *contents* were substituted.
Concrete proof of why an automated link/reference check, not just "the
build still succeeds," is a load-bearing quality gate.

## 15. Interview Q&A

### Why enable `SWIFT_STRICT_CONCURRENCY = complete` at the end of the migration instead of the start?

**Strong answer:** Turning it on from commit one would have meant fixing the
same underlying isolation issues (default-argument expressions referencing
`@MainActor` statics, plain data models needing `nonisolated`, actors vs.
`nonisolated(unsafe)`) all at once, with no incremental context. Doing the
architecture work first, under the compiler's default (weaker) concurrency
checking, meant each phase's isolation fixes were driven by that phase's own
actual new code — and by the time strict mode was finally turned on, it
found only three remaining issues project-wide, because the other dozen-plus
instances of the same underlying pattern had already been fixed along the
way, each with full context for why.

**Code evidence:**
- `CineConnect.xcodeproj/project.pbxproj` (`SWIFT_STRICT_CONCURRENCY = complete`)
- Contrast: Phase 1's `AppDependencyContainer` default-argument fix, Phase 6's `nonisolated struct Movie`/`MovieDetail` — both found and fixed *before* this phase, under the weaker default setting

**Follow-up question:** Doesn't that mean the codebase was "unsafe" for eight phases?

**Follow-up answer:** No — the underlying compiler diagnostics for these
specific issues (default-argument actor-isolation warnings, `Sendable`
conformance errors) already fired under the project's default settings in
every phase they occurred; `SWIFT_STRICT_CONCURRENCY = complete` broadens
*which categories* of concurrency issue get flagged as an error rather than
a warning (or not flagged at all), it doesn't retroactively mean earlier
phases were flying blind — see each phase's own §10 for the specific
diagnostic text hit at the time.

**Senior counter-question:** If strict mode had found a dozen new issues
instead of three, would sequencing it last still have been the right call?

**Counter-answer:** Yes, for the same reason — fixing a dozen issues with
each phase's original design context still fresh (had they been caught
phase-by-phase) is more tractable than fixing a dozen issues at the very end
with no memory of which specific design decision caused each one. The
*low* count here is a good outcome of the incremental approach, not
evidence the approach only works when the count happens to be low.

**Trade-off:** Eight phases of development happened without the compiler's
strictest concurrency gate active — a real, accepted risk window, closed
before the project was considered complete rather than left open indefinitely.

**Failure scenario:** A project that never turns strict concurrency on at
all (deferring indefinitely, not just sequencing it last) ships with
whatever concurrency bugs its weaker default checking missed, with no plan
to ever find out.

**Weak answer:** "Concurrency checking should always be on from day one."

**Improved answer:** Names the actual trade-off (incremental fixes with
context vs. one large fix-everything-at-once pass) and the actual result
(three issues, not zero, not a dozen) instead of treating "turn it on
early" as a universal rule with no cost.

### Why weren't the "critical-path UI tests" this phase's own comment promised actually written?

**Strong answer:** Honest answer, not a deflection: accessibility
identifiers were added because they're the *prerequisite* for reliable
`XCUIApplication` element targeting, but writing full search/detail/logout
UI test flows is separate, larger work this phase didn't have scope to
finish alongside strict-concurrency and rename. `CineConnectUITests.swift`'s
own comment still says exactly this — it isn't quietly deleted or
reworded to imply the work is done.

**Code evidence:**
- `CineConnectUITests/CineConnectUITests.swift`'s comment (unchanged by this phase, on purpose)
- The identifiers themselves: `CineConnect/Views/MoviesListView.swift`, `MovieDetailView.swift`

**Follow-up question:** Isn't adding identifiers with no test consuming them dead code?

**Follow-up answer:** Not dead — they're consumed by `accessibilityLabel`
for VoiceOver right now (a real, immediate accessibility benefit
independent of testing), and they're the specific, named prerequisite the
UI test file's own comment is waiting on; "add the seam, then the thing
that uses it" is a normal and defensible sequencing, not a speculative
abstraction with no consumer at all.

**Senior counter-question:** How would you prioritize writing those tests against other remaining gaps in this project (e.g., `KeychainStore`'s untested real Keychain calls from Phase 5)?

**Counter-answer:** Honestly, the untested real Keychain path is the higher
-risk gap — a security-relevant code path with zero automated coverage in
this environment — versus UI tests, which mostly guard against visual/
navigation regressions already partially covered by the underlying
ViewModel/coordinator unit tests. Both are named explicitly rather than
either being quietly treated as "basically done."

**Trade-off:** Documented above.

**Failure scenario:** If a future contributor assumed "accessibility
identifiers exist, so this app obviously has UI test coverage," they'd be
wrong — worth stating plainly rather than letting the identifiers alone
imply more coverage than actually exists.

**Weak answer:** "UI tests are next."

**Improved answer:** Names the actual remaining gap, the actual reason it
wasn't closed in this phase, and an honest relative-priority comparison
against this project's other known untested area.

## 16. Counter-questions

- "Why does the CI workflow run `clean test` instead of just `test`?" To
  match exactly the command this entire session used for every phase's own
  verification (see every phase doc's §10) — consistency between "what CI
  runs" and "what was actually verified locally throughout this migration"
  mattered more than a marginal CI speed gain from skipping a clean build.
- "If GitHub's runner image doesn't have any iPhone simulator matching the
  selection script's Python filter, what happens?" The `Pick an available
  iPhone simulator` step would produce an empty `device_name`, and the
  subsequent `xcodebuild` destination string would be malformed — a real,
  named risk of the "select at runtime" strategy (§12/§13), only checkable
  by an actual CI run, which this session cannot trigger.

## 17. Exercises

**Observe:** Open `CineConnect.xcodeproj/project.pbxproj` and search for
`SWIFT_STRICT_CONCURRENCY` — confirm it appears in all six configuration
entries (Debug/Release × three targets), not just the app target.

**Modify:** Add a fourth accessibility identifier to a view element that
doesn't have one yet (e.g., the search text field in `MoviesListView`).
Predict, before writing it, what a `CineConnectUITests` test using it would
look like (hint: `app.textFields["yourIdentifier"].tap()`), even though no
such test exists yet.

**Break intentionally:** Temporarily remove `@MainActor` from
`LoginViewController` and rebuild. Observe the exact warning/error text that
returns — confirms this phase's fix is load-bearing, not cosmetic. Restore
`@MainActor` afterward.

**Extend:** Write the first real critical-path UI test this phase's own
comment promised — e.g., a test that launches the app, and (if a fake/mock
login state can be injected for UI testing — currently it can't; this is
part of the exercise) asserts `app.otherElements["movieSearchResultsList"].exists`.
Decide, and write down your reasoning, what's actually needed to make the
app UI-testable in an authenticated state without a live Hotstar login.

**Interview:** Without re-reading this document, explain why this project's
CI workflow selects the latest available Xcode/simulator at runtime instead
of pinning a specific version, and name the real risk that strategy carries.

## 18. Remaining limitations

The `CineConnectUITests` critical-path tests (search, detail navigation,
logout) that `CineConnectUITests.swift`'s own comment describes as landing
in Phase 9 were **not** written in this phase — only the accessibility
identifiers they'd need were added (§15). The CI workflow (`build-and-test.yml`)
has been authored and reasoned about carefully but has **not** been observed
running on actual GitHub Actions infrastructure from this session — treat
its first real run as the actual verification, not this file's existence.
`KeychainStore`'s real Keychain calls remain untested in this environment
(carried forward from Phase 5, unrelated to and not fixed by this phase).
`clearCaches()` still doesn't cancel in-flight requests (carried forward
from Phase 6). No structured, redacted request/response logging exists
(mentioned as a Phase 9 candidate as far back as Phase 4's docs; not built —
no concrete logging need was identified strongly enough to justify adding
it speculatively). `docs/INTERVIEW_GUIDE.md` and a cross-cutting exercises
document were written as a direct follow-on to this phase, once every
phase's own Q&A/exercises sections already existed to assemble from — see
`docs/INTERVIEW_GUIDE.md` and `docs/LEARNING_EXERCISES.md`.

---

# Before/after: `WKNavigationDelegate` under strict concurrency

## Before

```swift
class LoginViewController: UIViewController { ... }   // no @MainActor

extension LoginViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        ...
        decisionHandler(.allow)
    }
}
```

Problems:
- Compiles and runs today (WebKit calls it via a compatibility shim), but
  doesn't actually *override* `WKNavigationDelegate`'s real current
  requirement — a silent near-miss, not a compile error, which is exactly
  what makes it easy to leave unnoticed.
- Without class-level `@MainActor`, nothing in the type is checked against
  `SWIFT_STRICT_CONCURRENCY = complete`'s stricter isolation rules at all.

## After

```swift
@MainActor
class LoginViewController: UIViewController { ... }

extension LoginViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        ...
        decisionHandler(.allow, preferences)
    }
}
```

- Who/what verifies this now: the compiler itself, under
  `SWIFT_STRICT_CONCURRENCY = complete` — zero warnings is the evidence,
  since no test can directly assert "this delegate method is genuinely
  overriding the protocol requirement."
- How this was found: not by inspection first — by turning strict
  concurrency on and reading the actual diagnostic, then confirming against
  WebKit's own header (`WKNavigationDelegate.h`) what the real, current
  method signature is.
