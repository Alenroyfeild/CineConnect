# The Search Debounce Pipeline

One Combine pipeline exists in CineConnect:
[`MovieSearchViewModel.setupSearchObserver()`](../CineConnect/ViewModels/MovieSearchViewModel.swift).
This document walks through it operator by operator.

```swift
$searchText
    .debounce(for: debounceInterval, scheduler: DispatchQueue.main)
    .removeDuplicates()
    .sink { [weak self] query in
        guard let self else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.searchTask?.cancel()
            self.isLoading = false
            self.searchError = nil
            self.searchResults = []
            return
        }
        self.searchTask?.cancel()
        self.searchTask = Task { [weak self] in
            guard let self else { return }
            await self.search(query: trimmed)
        }
    }
    .store(in: &cancellables)
```

## Publisher source: `$searchText`

`@Published var searchText: String` gives a `Publisher<String, Never>`
that emits every time `searchText` changes - once per keystroke (or
per-character SwiftUI text-field update), plus once immediately on
subscription with the current value.

## Normalization: where it actually happens

There's no `.map { $0.trimmingCharacters(...) }` in the pipeline itself -
trimming happens inside the `sink` closure, after `debounce`/
`removeDuplicates` have already run on the *untrimmed* value. This is
deliberate: `debounce` and `removeDuplicates` need to see real keystroke
timing and real character-by-character differences (including leading/
trailing whitespace as the user is actively typing it) to do their actual
jobs correctly; trimming earlier would change what counts as "a change"
for `removeDuplicates` in ways that don't match what the user is actually
doing.

## `removeDuplicates()`

Suppresses consecutive identical values. If `searchText` is set to the
same string twice in a row (e.g., programmatically, or via `willSet`/
`didSet` interactions), the second emission never reaches `sink`. This
does *not* deduplicate non-consecutive repeats - searching "batman",
clearing it, then searching "batman" again produces two separate
downstream emissions, correctly triggering two searches.

## `debounce(for:scheduler:)`

Waits for `debounceInterval` (500ms in production, injected as low as
5-20ms in tests - see
`docs/Learning/Architecture/Phase-07-Combine-and-Cancellation.md`) of
silence before letting a value through. Six keystrokes typed within that
window collapse into exactly one emission: the final value. This is what
makes `rapidTypingOnlyTriggersOneSearchAfterTypingStops`
(`CineConnectTests/MovieSearchViewModelTests.swift`) pass.

## Sink/subscription: the empty-query branch

Inside `sink`, an empty (after trimming) query takes an early-return path:
cancel any in-flight search, reset all published state to idle, and
return - without ever creating a `Task`. This exists so the loading
spinner never flashes for a query that's about to be cleared to idle
state, a presentation-timing concern distinct from
`SearchMoviesUseCase`'s own trim/empty check (see that type's doc comment
for why both exist).

## Task creation and cancellation

For a non-empty query, any previous `searchTask` is cancelled before a new
one is created. This is the bridge from Combine's world (a stream of text
values) into structured concurrency's world (one cancellable unit of async
work per search attempt).

## Stale-result protection

Inside `search(query:)` (the `async` function the `Task` runs):

```swift
guard let response = try await searchMovies(query: query) else { return }
try Task.checkCancellation()

let latest = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
guard latest == query else { return }
```

Two independent protections, not one: `Task.checkCancellation()` throws if
this task was cancelled (a new query started, via the `sink` closure
above); the `guard latest == query` check catches the case where, for
whatever reason, a response arrives for a query that's no longer current
even without the task itself being flagged cancelled. Both exist because
they protect against slightly different failure windows - see
`docs/Learning/Architecture/Phase-03-Domain-and-Repository.md`'s "search
race" scenario for a concrete walkthrough with a passing test.

## `Cancellable` lifetime

`.store(in: &cancellables)` keeps the `AnyCancellable` alive for as long as
`MovieSearchViewModel` itself is alive - when the ViewModel deallocates,
`cancellables` deallocates with it, which cancels the subscription
automatically. There's exactly one subscription in this pipeline, created
once in `init`.

## Why networking stays async/await, not Combine end-to-end

`SearchMoviesUseCase.callAsFunction(query:)` is `async throws -> [Movie]?`,
not a `Publisher`. A single request/response with a well-defined success/
failure/cancellation shape is exactly what `async/await` was designed for;
representing it as a single-value `Publisher` (e.g., via `Future`) would
add ceremony without adding capability - and `Future` specifically starts
its work eagerly at creation, not at subscription, and doesn't
automatically cancel its work just because a subscriber cancels, which
would have undermined the stale-result protection this pipeline depends on.
