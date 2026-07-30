import Foundation

/// Three policies, each with genuinely different behavior - no
/// `.returnCacheElseLoad` case: given `.cacheFirst` already does "return
/// cache if present and fresh, else load," a fourth case meaning almost
/// the same thing would be a distinction without a difference.
enum CachePolicy: Sendable {
    /// Try the network; on failure, fall back to a cached value even if
    /// it's stale (better than nothing). This is the default - it's what
    /// `MovieCache`'s pre-Phase-6 behavior already did, just now backed by
    /// real memory/disk layers instead of one flat disk cache.
    case networkFirst

    /// Return a *fresh* (non-expired) cached value immediately if one
    /// exists; only hit the network when there isn't one.
    case cacheFirst

    /// Skip the cache entirely - always hit the network, then write the
    /// result through to cache. Intended for an explicit user-initiated
    /// refresh action (Phase 9 UI hook; not wired to any control yet).
    case reloadIgnoringCache
}
