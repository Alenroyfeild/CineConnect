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

class MovieSearchAPIService: BaseAPIService, MovieSearchAPIServiceProtocol {
    func searchVideos(query: String) async throws -> [Movie] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw RemoteError.invalidURL
        }
        
        let baseURL = Endpoints.searchMovies.path
        let searchSessionId = UUID().uuidString.lowercased()
        let searchId = "\(searchSessionId)-\(Int.random(in: 1...10))"
        let referrerProps = "{\"search_session_id\":\"\(searchSessionId)\",\"search_id\":\"\(searchId)\"}"
        
        guard let encodedReferrer = referrerProps.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw RemoteError.invalidURL
        }
        
        let parameters: [String: String] = [
            "slug" : "in&slug=explore",
            "search_query" : encodedQuery,
            "referrer_props" : encodedReferrer
        ]
        
        do {
            let moviesSearchDTO: MovieSearchDTO = try await remoteService.execute(request: .init(url: URL(string: "\(baseURL)")!, method: Endpoints.searchMovies.method, parameters: parameters))
            return moviesSearchDTO.toMovies()
        } catch let error as DecodingError {
            throw RemoteError.parsingError(error: error)
        } catch let error as RemoteError {
            throw error
        } catch {
            throw RemoteError.unknown(error: error)
        }
    }
}
