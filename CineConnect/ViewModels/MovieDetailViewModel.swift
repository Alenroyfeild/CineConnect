//
//  MovieDetailViewModel.swift
//  CineConnect
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation
import Combine

enum DetailError: Equatable {
    case networkError
    case notFound
}

@MainActor
class MovieDetailViewModel: ObservableObject {
    @Published var movieDetail: MovieDetail?
    @Published var isLoading = false
    @Published var detailError: DetailError?
    
    private let getMovieDetail: GetMovieDetailUseCase

    init(getMovieDetail: GetMovieDetailUseCase) {
        self.getMovieDetail = getMovieDetail
    }

    func loadMovieDetail(slug: String) async {
        isLoading = true
        detailError = nil
        movieDetail = nil

        do {
            let detail = try await getMovieDetail(slug: slug)
            
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
