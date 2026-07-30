# Phase 8 — Cached Image Pipeline

Status: **Implemented and verified**.

## 1. Previous implementation

`MoviesListView`'s row poster and `MovieDetailView`'s hero image both used
plain SwiftUI `AsyncImage(url:)`. `AsyncImage` has its own internal
caching tied to `URLCache`, which the app has no visibility into or
control over - no application-level memory cache, no way to observe
hit/miss behavior, no shared deduplication with anything else in the app.

## 2. Problem

Every `MovieSearchRowView` and the detail screen's poster independently
asked `AsyncImage` to load the same URLs users would see repeatedly
(scrolling past the same result twice, revisiting a detail screen) with no
guarantee of an actual cache hit, and no way to test or reason about
caching behavior at all since it's entirely internal to `AsyncImage`.

## 3. Target responsibility

`ImageLoader` (actor) fetches and decodes images, backed by the *same*
generic `MemoryCache`/`InFlightRequestStore` actors Phase 6 built for
movie data - no parallel, image-specific cache primitives. `CachedAsyncImage`
(SwiftUI view) presents a phase-based API matching `AsyncImage`'s shape,
backed by `ImageLoader` instead of `URLCache`.

## 4. Files introduced

- `CineConnect/Caching/ImageLoader.swift`
- `CineConnect/Views/Components/CachedAsyncImage.swift`
- Tests: `CineConnectTests/ImageLoaderTests.swift`,
  `CineConnectTests/Fakes/StubImageURLProtocol.swift`

## 5. Files modified

- `CineConnect/App/AppDependencyContainer.swift` (`imageLoader` property)
- `CineConnect/CineConnectApp.swift` (`.environment(\.imageLoader, ...)` at the root)
- `CineConnect/Views/MoviesListView.swift`, `MovieDetailView.swift` (`AsyncImage` → `CachedAsyncImage`)

## 6. Files removed

None (`AsyncImage` is a system type, not a file to remove).

## 7. Runtime flow before

```
MovieSearchRowView.posterImage
  AsyncImage(url: movie.posterURL) { phase in ... }   // URLCache-backed, opaque
```

## 8. Runtime flow after

```
CineConnectApp.body
  .environment(\.imageLoader, dependencyContainer.imageLoader)   // set once, at the root

MovieSearchRowView.posterImage
  CachedAsyncImage(url: movie.posterURL) { phase in ... }
    @Environment(\.imageLoader) private var imageLoader           // read from the environment
    .task(id: url) { await load() }
      imageLoader.image(for: url)
        memoryCache.value(forKey: url) ?? {
          inFlight.value(forKey: url) {                            // L0: coalesce concurrent identical loads
            urlSession.data(from: url)                              // network
            UIImage(data:)                                          // decode, off the main actor (see §9)
            memoryCache.setValue(...)                                // L1 write-through
          }
        }
```

Numbered, with file/type/method/context:

1. **File:** `CachedAsyncImage.swift` · `body`/`.task(id: url)` ·
   `@MainActor` (SwiftUI view body), suspension point at `await load()`.
2. **File:** `CachedAsyncImage.swift` · `load()` · suspension point:
   `await imageLoader.image(for: url)` - crosses from the main actor into
   `ImageLoader`'s own isolation domain.
3. **File:** `ImageLoader.swift` · `image(for:)` · checks `memoryCache`
   first (suspension point crossing into `MemoryCache`'s domain); on miss,
   suspension point into `InFlightRequestStore`.
4. **File:** `ImageLoader.swift` · the operation closure passed to
   `InFlightRequestStore` · suspension point: `await urlSession.data(from:)`
   (network I/O); `UIImage(data:)` decoding happens synchronously right
   after, still inside `ImageLoader`'s (non-main-actor) isolation domain.
5. Back in `CachedAsyncImage.load()`: `Task.checkCancellation()`, then
   `phase = .success(...)` - a `@MainActor`-isolated state write, correctly
   hopping back since `CachedAsyncImage` is a SwiftUI view.

**Tests covering this full chain:** `ImageLoaderTests` (5).

## 9. Code excerpts

**Exact production code** (`CineConnect/Caching/ImageLoader.swift`):

```swift
actor ImageLoader {
    private let urlSession: URLSession
    private let memoryCache: MemoryCache<URL, UIImage>
    private let inFlight = InFlightRequestStore<URL, UIImage>()

    func image(for url: URL) async throws -> UIImage {
        if let cached = await memoryCache.value(forKey: url) {
            return cached
        }
        return try await inFlight.value(forKey: url) { [urlSession, memoryCache] in
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw ImageLoadingError.invalidResponse
            }
            guard let image = UIImage(data: data) else {
                throw ImageLoadingError.invalidData
            }
            await memoryCache.setValue(image, forKey: url)
            return image
        }
    }
}
```

## 10. Build evidence

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project CineConnect.xcodeproj -scheme CineConnect \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO clean test
```
Result: **BUILD SUCCEEDED**, **TEST SUCCEEDED**, 0 warnings, 108/108 tests
passing (verified across three consecutive full-suite runs given the
cross-suite flakiness found and fixed during this phase - see below).

**A real compile-time puzzle, found and fixed:** the first version of
`CachedAsyncImage<Content: View>` declared its `Phase` enum *nested*
inside the generic type, matching `AsyncImage`'s own `AsyncImagePhase`
shape. This failed to compile at both call sites with *"generic parameter
'Content' could not be inferred"* - because a nested type depends on its
enclosing type's generic parameters for name resolution, `CachedAsyncImage<Content>.Phase`
couldn't be resolved without already knowing `Content`, and `Content`
couldn't be inferred from a closure `{ (phase: Phase) -> Content in ... }`
without already knowing `Phase` - a genuine circular inference problem.
Fixed by moving `Phase` (renamed `CachedImagePhase`) to file scope, outside
the generic type entirely.

**A real cross-suite test race, found and fixed:** `ImageLoaderTests`
initially reused `StubURLProtocol` (Phase 4's networking stub). Both
`RemoteServiceTests` and `ImageLoaderTests` are `.serialized`, but that
trait only serializes tests *within* one suite - Swift Testing still runs
different suites concurrently with each other, and both suites touching
the same `StubURLProtocol` static state caused intermittent failures in
*both* suites, not just the new one. Fixed with a second, independent
stub type (`StubImageURLProtocol`) - simpler than building a genuine
cross-suite locking mechanism for what's fundamentally test-only
infrastructure. Verified stable across three consecutive full-suite runs
after the fix.

## 11. Test evidence

108 tests total (was 103). New: `ImageLoaderTests` (5 - successful
load+decode, memory-cache hit avoiding a second network call, non-2xx
status throws, invalid image data throws, ten concurrent identical
requests produce one network call).

## 12. Alternatives

1. **A disk cache layer for images too**, matching movie detail's L1+L2
   pattern. Rejected for now: `URLCache` (still active underneath
   `URLSession`, unconfigured but present) already provides *some*
   response-level disk persistence for images; adding a second, explicit
   disk layer on top would duplicate that without a demonstrated need.
   Documented as a reasonable future addition, not built speculatively.
2. **A resizing/downsampling pipeline** (common in production image
   libraries, to avoid decoding a full-resolution image just to show a
   60x80 thumbnail). Rejected - explicitly out of scope per the
   migration's own instruction to keep this "appropriately scoped... not a
   full third-party image framework."
3. **Constructor-injecting `ImageLoader` into every row/detail view**
   instead of SwiftUI environment injection. Rejected - see
   `CachedAsyncImage.swift`'s own doc comment: images are used far deeper
   in the view hierarchy than `AuthManager`/`RemoteService`, and threading
   one more parameter through every intervening view/initializer for a
   cross-cutting concern like this is exactly what SwiftUI's environment
   mechanism exists to avoid.

## 13. Trade-offs

Environment injection is less explicit at each call site than constructor
injection (a reader of `MovieSearchRowView` doesn't see "this view needs
an `ImageLoader`" in its initializer) - accepted because the alternative
(threading it through `MoviesListView` → `MovieSearchRowView` →
`CachedAsyncImage`, none of which have any other reason to know about
image loading) is worse for readability, not better.

## 14. Failure scenarios

**Duplicate image request**: `ImageLoaderTests.tenConcurrentRequestsForSameURLResultInOneNetworkCall`
proves the same coalescing behavior Phase 6 established for movie data
also holds for images - not a coincidence, since it's the exact same
`InFlightRequestStore` type doing the work.

**Cancellation when a row disappears**: `CachedAsyncImage` relies entirely
on `.task(id:)`'s built-in cancellation (no custom cancellation code
needed) - scrolling a row off-screen cancels its `load()` call the same
way navigating away from a detail screen cancels
`MovieDetailViewModel.loadMovieDetail` (Phase 2/3). Not separately
unit-tested here (SwiftUI view lifecycle isn't practically unit-testable
without a UI test), consistent with how this codebase has always treated
`.task(id:)`-driven cancellation as "correct by construction," relying on
the mechanism, not a bespoke test, per view.

## 15. Interview Q&A

### Why build a custom `CachedAsyncImage` instead of just using `AsyncImage`?

**Strong answer:** `AsyncImage`'s caching is entirely internal to
`URLCache` - there's no way to inspect it, configure its size/eviction
policy independently of the rest of the app's networking, or share
deduplication logic with anything else. `CachedAsyncImage` reuses the same
`MemoryCache`/`InFlightRequestStore` actors already built and tested for
movie data, giving the app one consistent, inspectable caching story
instead of two (one visible, one opaque).

**Code evidence:**
- `CineConnect/Caching/ImageLoader.swift`
- Test: `ImageLoaderTests.secondRequestForSameURLHitsMemoryCacheNotNetwork`

**Follow-up question:** Doesn't reusing `MemoryCache<URL, UIImage>` risk
images and, say, cached `MovieDetail` values competing for the same cache
budget?

**Follow-up answer:** No - `MemoryCache` is instantiated separately per
use (`DefaultMovieRepository` has its own instances; `ImageLoader` has its
own), each with independent `maxEntries`/`ttl`. Reuse here means "the same
*type*, used for a different purpose," not "the same *instance* shared
across unrelated data."

**Senior counter-question:** Why not add a disk cache for images too,
given detail data gets one?

**Counter-answer:** See §12, alternative 1 - `URLCache` already provides
some disk persistence for image responses today, and a second explicit
layer wasn't built without a demonstrated need for it, consistent with
this migration's stated bias against speculative abstraction.

**Trade-off:** Documented above (§13).

**Failure scenario:** A non-2xx response or undecodable data both throw
distinct `ImageLoadingError` cases rather than silently returning a blank
image - `CachedAsyncImage` treats either as `.failure`, letting the
call site's own placeholder view render.

**Weak answer:** "I made an image cache."

**Improved answer:** Names the exact reused primitives
(`MemoryCache`/`InFlightRequestStore`), the exact gap in `AsyncImage`
being addressed (no app-level visibility/control), and the exact
compile-time bug this phase found while building it (circular generic
inference from a nested `Phase` type).

## 16. Counter-questions

- "Why is `CachedImagePhase` a top-level type instead of nested inside
  `CachedAsyncImage`, when `AsyncImage`'s own `AsyncImagePhase` is a
  top-level type in Apple's API too?" Turns out Apple's own design here
  wasn't arbitrary - nesting it inside a generic type creates exactly the
  circular inference problem this phase hit and fixed (§10).
- "What would break if `ImageLoader` were `@MainActor`-isolated instead of
  a plain actor?" Image decoding (`UIImage(data:)`, which can be
  non-trivially expensive for larger images) would run on the main actor,
  contending with UI rendering - the whole point of using a plain actor
  here is to keep that work off the main thread for free.

## 17. Exercises

**Observe:** Set a breakpoint in `ImageLoader.image(for:)`. Scroll a movie
search results list up and down repeatedly and confirm the memory-cache
branch (not the network branch) is hit for posters already scrolled past once.

**Modify:** Change `ImageLoader`'s default `MemoryCache` from
`maxEntries: 100, ttl: 600` to `maxEntries: 5, ttl: 600` and observe (via
the same breakpoint) LRU eviction kicking in much sooner while scrolling
a longer results list.

**Break intentionally:** Temporarily move `CachedImagePhase` back to being
nested inside `CachedAsyncImage<Content>`. Re-run the build and reproduce
the exact "generic parameter 'Content' could not be inferred" error from
§10. Move it back out afterward.

**Extend:** Add a disk cache layer to `ImageLoader` (see §12, alternative
1) using the existing `DiskCache<Value>` actor from Phase 6 - decide what
TTL makes sense for images specifically, and write a test proving a
memory-cache miss still avoids a network call if the disk cache has the
image.

**Interview:** Without re-reading this document, explain why
`ImageLoaderTests` needed its own `StubImageURLProtocol` instead of
reusing `StubURLProtocol` from Phase 4's networking tests.

## 18. Remaining limitations

No disk cache for images (§12) - a memory-only cache means all cached
posters are lost on a memory warning or app relaunch, falling back to
`URLCache`'s own (unconfigured, default) disk behavior underneath.
No resizing/downsampling - a full-resolution image is decoded even for a
60x80 thumbnail. Cancellation-on-disappear relies entirely on `.task(id:)`
and isn't independently unit-tested (§14).
