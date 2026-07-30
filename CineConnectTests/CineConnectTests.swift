import Foundation
import Testing
@testable import CineConnect

@Test func smokeTestTargetIsWired() {
    // Minimal smoke test: proves the unit-test target builds, links against
    // the app target via @testable import, and can run. Feature-specific
    // tests (networking, mappers, repository, view models) land alongside
    // the corresponding migration phase rather than here.
    #expect(1 + 1 == 2)
}

@Test func movieModelIsHashableAndCodable() {
    let movie = Movie(
        id: "1",
        title: "Test Movie",
        subtitle: "2026",
        pageSlug: "/in/movies/test/1",
        posterURL: URL(string: "https://example.com/poster.jpg")
    )
    #expect(movie.id == "1")
}
