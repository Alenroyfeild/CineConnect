//
//  Remote.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

enum Remote { }

extension Remote {
    struct Request {
        let url: URLConvertable
        let method: HTTPMethod
        var headers: [String: String]?
        var parameters: [String: String]?
        var body: BodyConvertable?
        
        init(url: URLConvertable, method: HTTPMethod = .get, headers: [String: String]? = nil, parameters: [String: String]? = nil, body: BodyConvertable? = nil) {
            self.url = url
            self.method = method
            self.headers = headers
            self.parameters = parameters
            self.body = body
        }
        
        mutating func setBody(_ body: BodyConvertable) {
            self.body = body
        }
        
        mutating func setParameters(_ parameters: [String: String]) {
            self.parameters = parameters
        }
        
        mutating func setHeader(_ headers: [String: String]) {
            self.headers = headers
        }
        
        mutating func addParameter(_ parameter: String, value: String) {
            if parameters == nil {
                parameters = [:]
            }
            parameters?.updateValue(value, forKey: parameter)
        }
        
        mutating func addHeader(_ header: String, value: String) {
            if headers == nil {
                headers = [:]
            }
            headers?.updateValue(value, forKey: header)
        }
        
        private func getURLRequest(from jsonEncoder: JSONEncoder) throws -> URLRequest {
            let url = try getURL()
            
            var request = URLRequest(url: url)
            request.httpMethod = method.rawValue
            request.allHTTPHeaderFields = headers
            
            if let body {
                guard let encodedBody = try? body.asBody(from: jsonEncoder) else {
                    throw RemoteError.invalidBody
                }
                request.httpBody = encodedBody
            }
            
            return request
        }
        
        private func getURL() throws -> URL {
            guard let url = url.asURL(),
                  var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                throw RemoteError.invalidURL
            }
            
            urlComponents.queryItems = parameters?.map({ URLQueryItem(name: $0.key, value: $0.value)})
            
            guard let constructedURL = urlComponents.url else {
                throw RemoteError.invalidURL
            }
            
            return constructedURL
        }
    }
}

struct HTTPMethod {
    let rawValue: String
}

extension HTTPMethod {
    static let get = HTTPMethod(rawValue: "GET")
    static let post = HTTPMethod(rawValue: "POST")
}

extension HTTPURLResponse {
    var isSuccess: Bool { statusCode <= 200 && statusCode <= 299 }
}

