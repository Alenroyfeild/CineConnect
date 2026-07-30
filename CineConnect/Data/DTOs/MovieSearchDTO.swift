//
//  MovieSearchDTO.swift
//  CineConnect
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation

struct MovieSearchDTO: Decodable {
    let success: MovieSearchSuccess
}

struct MovieSearchSuccess: Decodable {
    let page: MovieSearchPage
}

struct MovieSearchPage: Decodable {
    let spaces: MovieSearchSpaces
}

struct MovieSearchSpaces: Decodable {
    let results: MovieSearchResultsSpace?
    let headerTray: MovieSearchHeaderTray?

    enum CodingKeys: String, CodingKey {
        case results
        case headerTray = "header_tray"
    }
}

struct MovieSearchHeaderTray: Decodable {
    let id: String?
    let template: String?
    let widgetWrappers: [MovieSearchHeroWidgetWrapper]?

    enum CodingKeys: String, CodingKey {
        case id, template
        case widgetWrappers = "widget_wrappers"
    }
}

struct MovieSearchHeroWidgetWrapper: Decodable {
    let widget: MovieSearchHeroWidget
}

struct MovieSearchHeroWidget: Decodable {
    let data: MovieSearchHeroData
}

/// Enum to handle both string and object types for content_info
enum ContentInfoType: Decodable {
    case string(String)
    case object(title: String, description: String?)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let objectValue = try? container.decode(MovieSearchContentInfo.self) {
            self = .object(title: objectValue.title, description: objectValue.description)
        } else {
            throw DecodingError.typeMismatch(ContentInfoType.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                debugDescription: "Expected String or Object"))
        }
    }

    var title: String {
        switch self {
        case .string(let str): return str
        case .object(let title, _): return title
        }
    }

    var description: String? {
        switch self {
        case .string: return nil
        case .object(_, let desc): return desc
        }
    }
}

struct MovieSearchContentInfo: Decodable {
    let title: String
    let description: String?
}

struct MovieSearchHeroData: Decodable {
    let title: String?
    let description: String?
    let contentInfo: [ContentInfoType]?
    let image: MovieSearchHeroImage?
    let primaryCTA: MovieSearchHeroCTA?

    enum CodingKeys: String, CodingKey {
        case contentInfo = "content_info"
        case primaryCTA = "primary_cta"
        case title
        case description
        case image
    }
}

struct MovieSearchHeroImage: Decodable {
    let src: String
}

struct MovieSearchHeroCTA: Decodable {
    let actions: SearchActions
}

struct MovieSearchResultsSpace: Decodable {
    let id: String
    let template: String
    let widgetWrappers: [MovieSearchWidgetWrapper]?

    enum CodingKeys: String, CodingKey {
        case id
        case template
        case widgetWrappers = "widget_wrappers"
    }
}

struct MovieSearchWidgetWrapper: Decodable {
    let widget: MovieSearchWidget
}

struct MovieSearchWidget: Decodable {
    let data: MovieSearchWidgetData
}

struct MovieSearchWidgetData: Decodable {
    let items: [MovieSearchItem]
}

struct MovieSearchItem: Decodable {
    let searchCard: SearchHorizontalContentCard?

    enum CodingKeys: String, CodingKey {
        case searchCard = "search_horizontal_content_card"
    }
}

struct SearchHorizontalContentCard: Decodable {
    let data: SearchCardData
}

struct SearchCardData: Decodable {
    let title: String
    let subtitle: String?
    let image: SearchCardImage?
    let actions: SearchActions

    enum CodingKeys: String, CodingKey {
        case title
        case subtitle = "sub_title"
        case image
        case actions
    }
}

struct SearchCardImage: Decodable {
    let src: String
    let alt: String?
    let dimension: ImageDimension?
}

struct ImageDimension: Decodable {
    let width: Int?
    let height: Int?
}

struct SearchActions: Decodable {
    let onClick: [OnClickAction]

    enum CodingKeys: String, CodingKey {
        case onClick = "on_click"
    }
}

struct OnClickAction: Decodable {
    let pageNavigation: PageNavigation?

    enum CodingKeys: String, CodingKey {
        case pageNavigation = "page_navigation"
    }
}

struct PageNavigation: Decodable {
    let pageSlug: String

    enum CodingKeys: String, CodingKey {
        case pageSlug = "page_slug"
    }
}

