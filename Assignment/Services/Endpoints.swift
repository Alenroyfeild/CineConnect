//
//  Endpoints.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

enum Endpoints {
    struct Endpoint {
        let path: String
        let method: HTTPMethod
    }
    
    static let searchMovies: Endpoint = .init(path: "https://www.hotstar.com/api/internal/bff/v2/pages/search", method: .get)
    static let movieDetails: Endpoint = .init(path: "https://www.hotstar.com/api/internal/bff/v2/slugs", method: .get)
}
