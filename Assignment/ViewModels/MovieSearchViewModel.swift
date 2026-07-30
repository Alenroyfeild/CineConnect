//
//  MovieSearchViewModel.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation
import Combine

@MainActor
final class MovieSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [Movie] = []
    @Published var isLoading = false
    @Published var searchError: SearchError?

    private let searchMovies: SearchMoviesUseCase
    private let debounceInterval: DispatchQueue.SchedulerTimeType.Stride
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    /// `debounceInterval` defaults to the real 500ms used in production,
    /// but is injectable so tests don't have to wait on real wall-clock
    /// time - `MovieSearchViewModelTests` uses a few milliseconds instead,
    /// making the whole suite fast and deterministic rather than padded
    /// with generous sleeps around a fixed 500ms (Phase 7; see
    /// docs/Learning/Architecture/Phase-07-Combine-and-Cancellation.md).
    init(searchMovies: SearchMoviesUseCase, debounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(500)) {
        self.searchMovies = searchMovies
        self.debounceInterval = debounceInterval
        setupSearchObserver()
    }

    /// The empty-query check here (before starting a `Task` at all) exists
    /// so the loading spinner never flashes for a query that's about to be
    /// cleared to idle state - that's a presentation-timing concern.
    /// `SearchMoviesUseCase` performs the same trim/empty check again, for
    /// a different reason: it's the use case's own contract to any caller,
    /// not just this ViewModel. See `SearchMoviesUseCase`'s doc comment.
    private func setupSearchObserver() {
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
    }

    private func search(query: String) async {
        isLoading = true
        defer { isLoading = false }

        searchError = nil

        do {
            // `query` here is already trimmed and non-empty (checked above,
            // in setupSearchObserver's sink, before this Task is even
            // started - see that method's doc comment). SearchMoviesUseCase
            // re-normalizes and re-checks anyway: it guarantees the same
            // invariant for any future caller that doesn't pre-check itself,
            // not just this one. `nil` here would mean "nothing to search,"
            // which can't happen given the pre-check, but is handled
            // correctly rather than force-unwrapped.
            guard let response = try await searchMovies(query: query) else { return }
            try Task.checkCancellation()

            let latest = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard latest == query else { return }

            if response.isEmpty {
                searchError = .noResults
            } else {
                searchResults = response
            }
        } catch is CancellationError {
            // Ignore
        } catch {
            searchError = .networkError
        }
    }
}

enum SearchError: Equatable {
    case noResults
    case networkError
    case unknown

    var title: String {
        switch self {
        case .noResults:
            return "No Search Results Found"
        case .networkError, .unknown:
            return "Something Went Wrong"
        }
    }

    var message: String {
        switch self {
        case .noResults:
            return "We couldn't find any matches. Please try searching with a different title."
        case .networkError, .unknown:
            return "We couldn't complete your search. Please try again."
        }
    }

    var buttonText: String {
        switch self {
        case .noResults:
            return "Clear Search"
        case .networkError, .unknown:
            return "Try Again"
        }
    }
}
