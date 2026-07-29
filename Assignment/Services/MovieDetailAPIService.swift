//
//  MovieDetailAPIService.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation

protocol MovieDetailAPIServiceProtocol {
    func fetchMovieDetail(slug: String) async throws -> MovieDetail
}

/// Remote data source for movie detail: builds the request, decodes the
/// DTO, maps to domain. Cache fallback used to live here too - it now
/// lives in `DefaultMovieRepository`.
///
/// Slug cleaning (`"/watch"` suffix removal) stays here rather than moving
/// to `GetMovieDetailUseCase`: it's specific to how Hotstar's detail
/// endpoint expects a page slug, an API-shape detail the domain layer
/// shouldn't need to know about.
class MovieDetailAPIService: BaseAPIService, MovieDetailAPIServiceProtocol {
    func fetchMovieDetail(slug: String) async throws -> MovieDetail {
        let cleanSlug = slug.replacingOccurrences(of: "/watch", with: "")

        guard let url = URL(string: "\(Endpoints.movieDetails.path)\(cleanSlug)") else {
            throw RemoteError.invalidURL
        }

        do {
            let movieDTO: MovieDetailDTO = try await remoteService.execute(request: .init(url: url, method: Endpoints.movieDetails.method))

            guard let movieDetail = movieDTO.toMovieDetail() else {
                throw RemoteError.invalidResponse
            }

            return movieDetail
        } catch let error as DecodingError {
            throw RemoteError.parsingError(error: error)
        } catch let error as RemoteError {
            throw error
        } catch {
            throw RemoteError.unknown(error: error)
        }
    }
}
