import Foundation
import Testing
@testable import CineConnect

/// As of Phase 7, `MovieSearchViewModel`'s debounce interval is injectable
/// (see its `init`) - these tests use a few milliseconds instead of the
/// real 500ms production value, so the whole suite runs fast and
/// deterministically rather than padded with generous sleeps around a
/// fixed delay (the pre-Phase-7 version of this file waited 750ms per
/// test for exactly that reason).
@MainActor
@Suite
struct MovieSearchViewModelTests {
    private static let testDebounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(5)
    private static let settleMargin: Duration = .milliseconds(60)

    private func makeViewModel(repository: FakeMovieRepository) -> MovieSearchViewModel {
        MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: repository), debounceInterval: Self.testDebounceInterval)
    }

    @Test func emptyQueryResetsToIdleState() async throws {
        let repository = FakeMovieRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.searchText = "   "
        try await Task.sleep(for: Self.settleMargin)

        #expect(viewModel.searchResults.isEmpty)
        #expect(viewModel.searchError == nil)
        #expect(viewModel.isLoading == false)
        #expect(repository.searchQueriesReceived.isEmpty)
    }

    @Test func nonEmptyQueryPopulatesResultsOnSuccess() async throws {
        let repository = FakeMovieRepository()
        let expected = [Movie(id: "1", title: "Batman", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        repository.searchResult = .success(expected)
        let viewModel = makeViewModel(repository: repository)

        viewModel.searchText = "batman"
        try await Task.sleep(for: Self.settleMargin)

        #expect(viewModel.searchResults == expected)
        #expect(viewModel.searchError == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func emptySuccessfulResponseSetsNoResultsError() async throws {
        let repository = FakeMovieRepository()
        repository.searchResult = .success([])
        let viewModel = makeViewModel(repository: repository)

        viewModel.searchText = "no-such-movie"
        try await Task.sleep(for: Self.settleMargin)

        #expect(viewModel.searchError == .noResults)
        #expect(viewModel.searchResults.isEmpty)
    }

    @Test func repositoryFailureSetsNetworkError() async throws {
        let repository = FakeMovieRepository()
        repository.searchResult = .failure(FakeMovieRepository.FakeError.unconfigured)
        let viewModel = makeViewModel(repository: repository)

        viewModel.searchText = "batman"
        try await Task.sleep(for: Self.settleMargin)

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
        // Looser margins than the rest of this file's tests: this test has
        // two sequential debounce+settle cycles plus real Task cancellation
        // in between, so it's more sensitive to scheduling jitter under
        // test-suite load than a single debounce-and-wait. Still an order
        // of magnitude faster than the pre-Phase-7 750ms-per-step version.
        let raceDebounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(20)
        let raceSettleMargin: Duration = .milliseconds(150)

        let repository = FakeMovieRepository()
        let batmanMovies = [Movie(id: "1", title: "Batman", subtitle: "S", pageSlug: "/batman", posterURL: nil)]
        let avatarMovies = [Movie(id: "2", title: "Avatar", subtitle: "S", pageSlug: "/avatar", posterURL: nil)]
        // Long enough to still be in flight after the first settle margin
        // elapses, regardless of minor scheduling jitter.
        repository.delayedSearchResultsByQuery["batman"] = (.success(batmanMovies), 2_000_000_000)
        repository.delayedSearchResultsByQuery["avatar"] = (.success(avatarMovies), 0)
        let viewModel = MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: repository), debounceInterval: raceDebounce)

        viewModel.searchText = "batman"
        try await Task.sleep(for: raceSettleMargin) // let Batman's debounce fire and its (slow) Task start

        viewModel.searchText = "avatar"
        try await Task.sleep(for: raceSettleMargin) // let Avatar's debounce fire, cancel Batman, resolve Avatar

        #expect(viewModel.searchResults == avatarMovies)
        #expect(repository.searchQueriesReceived.contains("batman"))
        #expect(repository.searchQueriesReceived.contains("avatar"))
    }

    @Test func rapidTypingOnlyTriggersOneSearchAfterTypingStops() async throws {
        let repository = FakeMovieRepository()
        repository.searchResult = .success([Movie(id: "1", title: "Batman", subtitle: "S", pageSlug: "/x", posterURL: nil)])
        let viewModel = makeViewModel(repository: repository)

        // Simulates fast typing - each keystroke well within the 5ms
        // debounce window of the next, so only the final value should ever
        // reach the use case (`removeDuplicates` + `debounce` together).
        for partial in ["b", "ba", "bat", "batm", "batma", "batman"] {
            viewModel.searchText = partial
        }
        try await Task.sleep(for: Self.settleMargin)

        #expect(repository.searchQueriesReceived == ["batman"])
    }
}
