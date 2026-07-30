import SwiftUI

/// Injected via the SwiftUI environment rather than a constructor
/// parameter - unlike `AuthManager`/`RemoteService` (threaded explicitly
/// through coordinators, since only a few types need them),
/// `CachedAsyncImage` is used deep inside row/detail view hierarchies
/// (`MoviesListView`'s rows, `MovieDetailView`'s poster) where threading an
/// `ImageLoader` through every intervening initializer would be pure
/// ceremony. `AppDependencyContainer` still builds the one production
/// instance; `CineConnectApp` sets it on the environment once, at the root.
private struct ImageLoaderKey: EnvironmentKey {
    static let defaultValue = ImageLoader()
}

extension EnvironmentValues {
    var imageLoader: ImageLoader {
        get { self[ImageLoaderKey.self] }
        set { self[ImageLoaderKey.self] = newValue }
    }
}

/// Deliberately a top-level type, not nested inside `CachedAsyncImage<Content>`:
/// a nested `Phase` would make its own type depend on `Content`, which
/// creates circular generic inference for any closure typed
/// `(Phase) -> Content` (`Content` can't be inferred without first knowing
/// `Phase`, and `Phase` can't be named without first knowing `Content`).
enum CachedImagePhase {
    case empty
    case success(Image)
    case failure
}

/// A focused replacement for SwiftUI's `AsyncImage`: adds an
/// application-controlled memory cache and request deduplication
/// (via `ImageLoader`), which `AsyncImage` doesn't expose. Deliberately
/// scoped to what this app needs - memory caching and phase-based
/// rendering - not a full third-party-style image framework (no disk
/// cache, no resizing/transformation pipeline).
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let content: (CachedImagePhase) -> Content

    @State private var phase: CachedImagePhase = .empty
    @Environment(\.imageLoader) private var imageLoader

    init(url: URL?, @ViewBuilder content: @escaping (CachedImagePhase) -> Content) {
        self.url = url
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                // `.task(id:)` cancels automatically when `url` changes or
                // this view disappears - the same mechanism
                // `MovieDetailViewModel` already relies on (Phase 2/3), no
                // extra cancellation bookkeeping needed here.
                await load()
            }
    }

    private func load() async {
        guard let url else {
            phase = .failure
            return
        }
        phase = .empty
        do {
            let uiImage = try await imageLoader.image(for: url)
            try Task.checkCancellation()
            phase = .success(Image(uiImage: uiImage))
        } catch is CancellationError {
            // Ignore - the row/screen showing this image disappeared or
            // its URL changed before the load finished.
        } catch {
            phase = .failure
        }
    }
}
