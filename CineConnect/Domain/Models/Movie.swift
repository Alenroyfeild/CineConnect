//
//  Movie.swift
//  CineConnect
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation

/// `Sendable`: crosses actor boundaries as-is into/out of `MemoryCache`,
/// `DiskCache`, and `InFlightRequestStore` (Phase 6) - safe because every
/// stored property is itself a value type with no shared mutable state.
///
/// `nonisolated`: the project's default-actor-isolation setting
/// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) otherwise infers this
/// type's own protocol conformances (`Decodable` in particular) as
/// `@MainActor`-isolated, which then can't satisfy a generic actor's
/// `Value: Sendable` constraint from a non-`@MainActor` context (the
/// error was "main actor-isolated conformance of 'Movie' to 'Decodable'
/// cannot satisfy... 'Sendable'"). A plain data model has no reason to be
/// actor-isolated at all.
nonisolated struct Movie: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let pageSlug: String
    let posterURL: URL?
}
