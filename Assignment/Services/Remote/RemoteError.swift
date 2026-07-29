//
//  RemoteError.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

enum RemoteError: Error {
    case invalidURL
    case invalidBody
    case invalidResponse
    case network(error: Error)
    case parsingError(error: Error)
    case general(status: String, statusCode: Int)
    /// A non-2xx response whose body successfully decoded as
    /// `RemoteErrorResponse` - preferred over `.general` when the server
    /// gave a structured reason, added in Phase 4 (the type existed since
    /// before, but nothing ever attempted to decode it).
    case server(RemoteErrorResponse)
    case unknown(error: Error)

    /// Maps an arbitrary caught error to a `RemoteError`. Callers must check
    /// `error is CancellationError` and rethrow *before* calling this - a
    /// cancelled request isn't representable as a `RemoteError` case, and
    /// wrapping it as `.unknown` would hide it from a caller's
    /// `catch is CancellationError` handling.
    static func from(_ error: Error) -> RemoteError {
        switch error {
        case let remoteError as RemoteError:
            // Already-typed errors (thrown by RemoteService itself) pass
            // through unchanged rather than getting double-wrapped as
            // `.unknown(error: RemoteError.someCase)`.
            return remoteError
        case let urlError as URLError:
            return .network(error: urlError)
        case let decodingError as DecodingError:
            return .parsingError(error: decodingError)
        default:
            return .unknown(error: error)
        }
    }
}

struct RemoteErrorResponse: Codable, Error {
    public let errorCode: String
    public let message: String
    
    init(errorCode: String, message: String) {
        self.errorCode = errorCode
        self.message = message
    }
}
