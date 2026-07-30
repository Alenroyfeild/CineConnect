import Foundation
import Testing
@testable import CineConnect

@MainActor
@Suite
struct SearchMoviesUseCaseTests {
    @Test func returnsNilForEmptyQuery() async throws {
        let repository = FakeMovieRepository()
        let useCase = SearchMoviesUseCase(repository: repository)

        let result = try await useCase(query: "   ")

        #expect(result == nil)
        #expect(repository.searchQueriesReceived.isEmpty)
    }

    @Test func trimsWhitespaceBeforeCallingRepository() async throws {
        let repository = FakeMovieRepository()
        let useCase = SearchMoviesUseCase(repository: repository)

        _ = try await useCase(query: "  batman  ")

        #expect(repository.searchQueriesReceived == ["batman"])
    }

    @Test func forwardsRepositoryResultsOnSuccess() async throws {
        let repository = FakeMovieRepository()
        let expected = [Movie(id: "1", title: "T", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        repository.searchResult = .success(expected)
        let useCase = SearchMoviesUseCase(repository: repository)

        let result = try await useCase(query: "batman")

        #expect(result == expected)
    }

    @Test func propagatesRepositoryErrors() async throws {
        let repository = FakeMovieRepository()
        repository.searchResult = .failure(FakeMovieRepository.FakeError.unconfigured)
        let useCase = SearchMoviesUseCase(repository: repository)

        await #expect(throws: FakeMovieRepository.FakeError.self) {
            _ = try await useCase(query: "batman")
        }
    }

    @Test func propagatesCancellation() async throws {
        let repository = FakeMovieRepository()
        repository.searchResult = .failure(CancellationError())
        let useCase = SearchMoviesUseCase(repository: repository)

        await #expect(throws: CancellationError.self) {
            _ = try await useCase(query: "batman")
        }
    }
}
