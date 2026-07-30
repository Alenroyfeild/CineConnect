//
//  MovieDetailDTO.swift
//  CineConnect
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

struct MovieDetailDTO: Decodable {
    let success: MovieDetailSuccess
}

struct MovieDetailSuccess: Decodable {
    let page: MovieDetailPage
}

struct MovieDetailPage: Decodable {
    let spaces: [String: MovieDetailSpace]
}

struct MovieDetailSpace: Decodable {
    let widgetWrappers: [MovieDetailWidgetWrapper]?
    
    enum CodingKeys: String, CodingKey {
        case widgetWrappers = "widget_wrappers"
    }
}

struct MovieDetailWidgetWrapper: Decodable {
    let widget: MovieDetailWidget
}

struct MovieDetailWidget: Decodable {
    let data: MovieDetailWidgetData
}

struct MovieDetailWidgetData: Decodable {
    let contentInfo: MovieDetailContentInfo?
    let heroImg: MovieDetailImageInfo?
    let starcast: String?
    
    enum CodingKeys: String, CodingKey {
        case contentInfo = "content_info"
        case heroImg = "hero_img"
        case starcast
    }
}

struct MovieDetailImageInfo: Decodable {
    let src: String
}

struct MovieDetailContentInfo: Decodable {
    let title: String
    let description: String
    let calloutMetaTags: [MovieDetailCalloutMetaTag]?
    let superscriptTags: [MovieDetailTag]?
    
    enum CodingKeys: String, CodingKey {
        case title, description
        case calloutMetaTags = "callout_meta_tags"
        case superscriptTags = "superscript_tags"
    }
}

struct MovieDetailTag: Decodable {
    let value: String?
}

struct MovieDetailCalloutMetaTag: Decodable {
    let calloutTag: MovieDetailCalloutTag
    
    enum CodingKeys: String, CodingKey {
        case calloutTag = "callout_tag"
    }
}

struct MovieDetailCalloutTag: Decodable {
    let txt: MovieDetailTextData
}

struct MovieDetailTextData: Decodable {
    let text: String
}

