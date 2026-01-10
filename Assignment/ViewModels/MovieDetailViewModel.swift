//
//  MovieDetailViewModel.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation
import Combine

enum DetailError {
    case networkError
    case notFound
}

@MainActor
class MovieDetailViewModel: ObservableObject {
    @Published var movieDetail: MovieDetail?
    @Published var isLoading = false
    @Published var detailError: DetailError?
    
    private let apiService: MovieDetailAPIServiceProtocol
    
    init(apiService: MovieDetailAPIServiceProtocol = MovieDetailAPIService()) {
        self.apiService = apiService
    }
    
    func loadMovieDetail(slug: String) async {
        isLoading = true
        detailError = nil
        movieDetail = nil
        
        do {
            let detail = try await apiService.fetchMovieDetail(slug: slug)
            
            try Task.checkCancellation()
            
            self.movieDetail = detail
            self.isLoading = false
        } catch is CancellationError {
            /// Ignore cancellation; we don't want to show an error UI if we just cancelled the task
            return
        } catch {
            self.detailError = .networkError
            self.isLoading = false
        }
    }
}
