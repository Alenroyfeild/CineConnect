//
//  RemoteService.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation
import Combine

protocol RemoteServiceProtocol {
    func execute<T: Decodable>(request: Remote.Request) async throws -> T
}

final class RemoteService: RemoteServiceProtocol {
    private let urlSession: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let preInterceptors: [RequestInterceptor]
    private let postInterceptors: [ResponseInterceptor]
    
    public init(
        urlSession: URLSession = .shared,
        jsonEncoder: JSONEncoder = .init(),
        jsonDecoder: JSONDecoder = .init(),
        preInterceptors: [RequestInterceptor] = [],
        postInterceptors: [ResponseInterceptor] = []
    ) {
        self.urlSession = urlSession
        self.jsonEncoder = jsonEncoder
        self.jsonDecoder = jsonDecoder
        self.preInterceptors = preInterceptors
        self.postInterceptors = postInterceptors
    }
    
    /// Executes a request asynchronously and decodes the response.
    func execute<T: Decodable>(request: Remote.Request) async throws -> T {
        let url = try getURL(from: request)
        let urlRequest = try buildURLRequest(from: request, url: url)
        
        let interceptedRequest = try await preInterceptors.reduce(urlRequest) { result, interceptor in
            try await interceptor.intercept(result)
        }
        
        let (data, response) = try await urlSession.data(for: interceptedRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteError.invalidResponse
        }
        
        if !httpResponse.isSuccess {
            throw RemoteError.general(status: httpResponse.description, statusCode: httpResponse.statusCode)
        }
        
        let remoteResponse = Response(response: httpResponse, data: data)
        let decryptedResponse = try await postInterceptors.reduce(remoteResponse) { result, interceptor in
            try await interceptor.intercept(response: result)
        }
        
        return try jsonDecoder.decode(T.self, from: decryptedResponse.data)
    }
    
    private func buildURLRequest(from request: Remote.Request, url: URL) throws -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        
        if let body = request.body {
            guard let encodedBody = try? body.asBody(from: jsonEncoder) else {
                throw RemoteError.invalidBody
            }
            urlRequest.httpBody = encodedBody
        }
        return urlRequest
    }
    
    private func getURL(from request: Remote.Request) throws -> URL {
        guard let url = request.url.asURL(),
              var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw RemoteError.invalidURL
        }
        
        urlComponents.queryItems = request.parameters?.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let constructedURL = urlComponents.url else {
            throw RemoteError.invalidURL
        }
        return constructedURL
    }
}

extension RemoteService {
    static let shared :RemoteService = {
        let preInterceptors: [RequestInterceptor] = [AuthenticationInterceptor()]
        let remoteService = RemoteService(preInterceptors: preInterceptors)
        return remoteService
    }()
}
