//
//  MovieSearchViewModel.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation
import Combine

@MainActor
class MovieSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [Movie] = []
    @Published var isLoading = false
    @Published var searchError: SearchError?

    private let apiService: MovieSearchAPIServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(apiService: MovieSearchAPIServiceProtocol = MovieSearchAPIService()) {
        self.apiService = apiService
        setupSearchObserver()
    }

    private func setupSearchObserver() {
        $searchText
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    self.searchResults = []
                    self.searchError = nil
                    return
                }

                Task {
                    await self.search(query: query)
                }
            }
            .store(in: &cancellables)
    }

    private func search(query: String) async {
        isLoading = true
        searchError = nil
        searchResults = []

        do {
            let response = try await apiService.searchVideos(query: query)
            
            try Task.checkCancellation()
            
            if response.isEmpty {
                self.searchError = .noResults
            } else {
                self.searchResults = response
            }
        } catch is CancellationError {
            /// Ignore cancellation; we don't want to show an error UI if we just cancelled the task
            return
        } catch {
            self.searchError = .networkError
        }

        isLoading = false
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
