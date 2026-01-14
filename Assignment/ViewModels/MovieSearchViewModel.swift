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

    private let apiService: MovieSearchAPIServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init(apiService: MovieSearchAPIServiceProtocol) {
        self.apiService = apiService
        setupSearchObserver()
    }

    convenience init() {
        self.init(apiService: MovieSearchAPIService())
    }

    private func setupSearchObserver() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
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
            let response = try await apiService.searchVideos(query: query)
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

enum SearchError {
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
