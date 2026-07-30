import Foundation
import Testing
@testable import CineConnect

/// This use case is a deliberate pass-through (see its own doc comment) -
/// these tests exist to prove that's actually true, not to demonstrate
/// meaningful behavior of its own.
@MainActor
@Suite
struct GetMovieDetailUseCaseTests {
    @Test func forwardsSlugAndResultUnchanged() async throws {
        let repository = FakeMovieRepository()
        let expected = MovieDetail(title: "T", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil)
        repository.detailResult = .success(expected)
        let useCase = GetMovieDetailUseCase(repository: repository)

        let result = try await useCase(slug: "/in/movies/x/1")

        #expect(result.title == expected.title)
        #expect(repository.detailSlugsReceived == ["/in/movies/x/1"])
    }

    @Test func propagatesRepositoryErrors() async throws {
        let repository = FakeMovieRepository()
        repository.detailResult = .failure(FakeMovieRepository.FakeError.unconfigured)
        let useCase = GetMovieDetailUseCase(repository: repository)

        await #expect(throws: FakeMovieRepository.FakeError.self) {
            _ = try await useCase(slug: "/in/movies/x/1")
        }
    }
}
