//
//  MovieSearchAPIService.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation

protocol MovieSearchAPIServiceProtocol {
    func searchVideos(query: String) async throws -> [Movie]
}

/// Remote data source for movie search: builds the request, decodes the
/// DTO, maps to domain. Cache fallback used to live here too - it now
/// lives in `DefaultMovieRepository`, so this type only knows about the
/// network, not caching policy.
class MovieSearchAPIService: BaseAPIService, MovieSearchAPIServiceProtocol {
    func searchVideos(query: String) async throws -> [Movie] {
        let baseURL = Endpoints.searchMovies.path
        let searchSessionId = UUID().uuidString.lowercased()
        let searchId = "\(searchSessionId)-\(Int.random(in: 1...10))"
        let referrerProps = "{\"search_session_id\":\"\(searchSessionId)\",\"search_id\":\"\(searchId)\"}"

        // Fixed in Phase 4: these values used to be percent-encoded here
        // *and* again by RemoteService's URLQueryItem construction (a
        // double-encoding bug - a literal space would have become "%2520"
        // instead of "%20"). URLQueryItem/URLComponents already percent-
        // encode query values, so the raw strings are passed through
        // unencoded exactly once.
        let parameters: [String: String] = [
            "slug": "in&slug=explore",
            "search_query": query,
            "referrer_props": referrerProps
        ]

        do {
            let moviesSearchDTO: MovieSearchDTO = try await remoteService.execute(
                request: .init(url: baseURL, method: Endpoints.searchMovies.method, parameters: parameters)
            )
            return moviesSearchDTO.toMovies()
        } catch is CancellationError {
            // Rethrown as-is, not mapped through RemoteError.from - see
            // that method's doc comment for why.
            throw CancellationError()
        } catch {
            throw RemoteError.from(error)
        }
    }
}
