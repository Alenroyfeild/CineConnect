//
//  Movie.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import Foundation

struct Movie: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let pageSlug: String
    let posterURL: URL?
}
