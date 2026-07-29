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

/// What `AuthenticationInterceptor` needs from a credentials source -
/// nothing more. `AuthManager` conforms (see `AuthManager.swift`), itself
/// backed by the Keychain via `CredentialsStore` as of Phase 5. `async`
/// because reading from the Keychain-backed store is asynchronous.
protocol AuthHeaderProviding {
    func getHeaders() async -> [String: String]
}

final class AuthenticationInterceptor: RequestInterceptor {
    private let headerProvider: AuthHeaderProviding

    /// No default parameter, no `AuthManager.shared` reference - injected
    /// explicitly by whoever builds this interceptor (today,
    /// `AppDependencyContainer`).
    init(headerProvider: AuthHeaderProviding) {
        self.headerProvider = headerProvider
    }

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        for header in await headerProvider.getHeaders() {
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
