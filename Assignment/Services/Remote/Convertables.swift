//
//  URLConvertable.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

public protocol URLConvertable {
    func asURL() -> URL?
}

public extension URLConvertable where Self == URL {
    func asURL() -> URL? {
        self
    }
}

public extension URLConvertable where Self == String {
    func asURL() -> URL? {
        URL(string: self)
    }
}

extension URL: URLConvertable { }
extension String: URLConvertable {}


public protocol BodyConvertable: Encodable {
    func asBody(from jsonEncoder: JSONEncoder) throws -> Data
}

public extension BodyConvertable where Self == Data {
    func asBody(from jsonEncoder: JSONEncoder) throws -> Data {
        self
    }
}

extension Data: BodyConvertable { }

public extension BodyConvertable {
    func asBody(from jsonEncoder: JSONEncoder) throws -> Data {
        try jsonEncoder.encode(self)
    }
}
