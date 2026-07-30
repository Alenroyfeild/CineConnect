//
//  MovieDetail.swift
//  CineConnect
//
//  Created by Balaji Royal on 10/01/26.
//


import Foundation

/// `Sendable`/`nonisolated` for the same reason as `Movie` - see its doc
/// comment.
nonisolated struct MovieDetail: Codable, Sendable {
    let title: String
    let subtitle: String?
    let description: String?
    let posterURL: URL?
    let rating: String?
    let duration: String?
}
