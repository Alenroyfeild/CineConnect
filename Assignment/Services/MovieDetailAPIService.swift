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

class MovieDetailAPIService: BaseAPIService, MovieDetailAPIServiceProtocol {
    private let baseURL = "https://www.hotstar.com/api/internal/bff/v2/slugs"
    
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
