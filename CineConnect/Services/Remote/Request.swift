//
//  Remote.swift
//  CineConnect
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

        // `getURLRequest(from:)`/`getURL()` used to be declared here, private
        // and unused - `RemoteService` had its own separate, duplicate
        // `buildURLRequest`/`getURL` implementing the exact same logic.
        // Removed in Phase 4 rather than kept as dead code; `RemoteService`
        // is the single place request/URL construction happens now.
    }
}

struct HTTPMethod: Equatable {
    let rawValue: String
}

extension HTTPMethod {
    static let get = HTTPMethod(rawValue: "GET")
    static let post = HTTPMethod(rawValue: "POST")
}

extension HTTPURLResponse {
    /// Fixed in Phase 4: was `statusCode <= 200 && statusCode <= 299`, which
    /// only exactly 200 satisfies (both conditions being true for anything
    /// above 200 is impossible) - meaning a 201, 204, or 299 all incorrectly
    /// reported failure.
    var isSuccess: Bool { (200..<300).contains(statusCode) }
}

