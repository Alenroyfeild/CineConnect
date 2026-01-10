//
//  Interceptors.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

public protocol RequestInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

public protocol ResponseInterceptor {
    func intercept(response: Response) async throws -> Response
}

final class AuthenticationInterceptor: RequestInterceptor {
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        for header in AuthManager.shared.getHeaders() {
            modifiedRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }
        return modifiedRequest
    }
}

extension Array {
    @inlinable public func reduce<Result>(
        _ initialResult: Result,
        _ nextPartialResult: (Result, Element) async throws -> Result
    ) async rethrows -> Result {
        var result = initialResult
        for element in self {
            result = try await nextPartialResult(result, element)
        }
        return result
    }
}
