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
    case unknown(error: Error)
    
    static func from(_ error: Error) -> RemoteError {
        switch error {
        case let urlError as URLError:
            return .network(error: urlError)
        case let decodingError as DecodingError:
            return .parsingError(error: decodingError)
        default:
            return .unknown(error: error)
        }
    }
}

struct RemoteErrorResponse: Decodable, Error {
    public let errorCode: String
    public let message: String
    
    init(errorCode: String, message: String) {
        self.errorCode = errorCode
        self.message = message
    }
}
