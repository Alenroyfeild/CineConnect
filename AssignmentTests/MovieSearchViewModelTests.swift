import Foundation
import Testing
@testable import Assignment

/// These tests wait on the real 500ms Combine debounce in
/// `MovieSearchViewModel.setupSearchObserver` rather than an injected,
/// test-controllable scheduler - that seam doesn't exist yet (tracked for
/// Phase 7's Combine-hardening work). The waits below use a generous
/// margin over 500ms specifically to avoid flakiness from that limitation,
/// not because the timing itself is meaningful.
@MainActor
@Suite
struct MovieSearchViewModelTests {
    private static let debounceMargin: Duration = .milliseconds(750)

    @Test func emptyQueryResetsToIdleState() async throws {
        let repository = FakeMovieRepository()
        let viewModel = MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: repository))

        viewModel.searchText = "   "
        try await Task.sleep(for: Self.debounceMargin)

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchError == nil)
        #expect(viewModel.isLoading == false)
        #expect(repository.searchQueriesReceived.isEmpty)
    }

    @Test func nonEmptyQueryPopulatesResultsOnSuccess() async throws {
        let repository = FakeMovieRepository()
        let expected = [Movie(id: "1", title: "Batman", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        repository.searchResult = .success(expected)
        let viewModel = MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: repository))

        viewModel.searchText = "batman"
        try await Task.sleep(for: Self.debounceMargin)

        #expect(viewModel.searchResults == expected)
        #expect(viewModel.searchError == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func emptySuccessfulResponseSetsNoResultsError() async throws {
        let repository = FakeMovieRepository()
        repository.searchResult = .success([])
        let viewModel = MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: repository))

        viewModel.searchText = "no-such-movie"
        try await Task.sleep(for: Self.debounceMargin)

        #expect(viewModel.searchError == .noResults)
        #expect(viewModel.searchResults.isEmpty)
    }

    @Test func repositoryFailureSetsNetworkError() async throws {
        let repository = FakeMovieRepository()
        repository.searchResult = .failure(FakeMovieRepository.FakeError.unconfigured)
        let viewModel = MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: repository))

        viewModel.searchText = "batman"
        try await Task.sleep(for: Self.debounceMargin)

        #expect(viewModel.searchError == .networkError)
        #expect(viewModel.isLoading == false)
    }

    /// The exact scenario from
    /// docs/Learning/Architecture/Phase-03-Domain-and-Repository.md's
    /// "search race" failure scenario: the user types "Batman", then
    /// "Avatar" before Batman's (artificially slow) search completes.
    /// Avatar must win - Batman's in-flight Task gets cancelled, and even
    /// if it hadn't been, the `guard latest == query` staleness check would
    /// still reject it.
    @Test func newQueryCancelsStaleInFlightSearch() async throws {
        let repository = FakeMovieRepository()
        let batmanMovies = [Movie(id: "1", title: "Batman", subtitle: "S", pageSlug: "/batman", posterURL: nil)]
        let avatarMovies = [Movie(id: "2", title: "Avatar", subtitle: "S", pageSlug: "/avatar", posterURL: nil)]
        repository.delayedSearchResultsByQuery["batman"] = (.success(batmanMovies), 3_000_000_000) // 3s - long enough to still be in flight
        repository.delayedSearchResultsByQuery["avatar"] = (.success(avatarMovies), 0)
        let viewModel = MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: repository))

        viewModel.searchText = "batman"
        try await Task.sleep(for: Self.debounceMargin) // let Batman's debounce fire and its (slow) Task start

        viewModel.searchText = "avatar"
        try await Task.sleep(for: Self.debounceMargin) // let Avatar's debounce fire, cancel Batman, resolve Avatar

        #expect(viewModel.searchResults == avatarMovies)
        #expect(repository.searchQueriesReceived.contains("batman"))
        #expect(repository.searchQueriesReceived.contains("avatar"))
    }
}
