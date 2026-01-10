//
//  MovieSearchDTO.swift
//  Assignment
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

extension MovieSearchDTO {
    private var imageBaseURL: String {
        "https://img1.hotstarext.com/image/upload/f_auto,t_web_m_1x/"
    }

    func toMovies() -> [Movie] {
        var movies: [Movie] = []

        if let headerTray = success.page.spaces.headerTray,
           let wrappers = headerTray.widgetWrappers {
            let heroMovies = wrappers.compactMap { wrapper -> Movie? in
                let data = wrapper.widget.data

                var description: String? = nil
                if let firstInfo = data.contentInfo {
                    for info in firstInfo {
                        if description != nil {
                            description! += " • "  + info.title
                        } else {
                            description = info.title
                        }
                    }
                }
                
                guard let title = data.title,
                      let pageSlug = data.primaryCTA?.actions.onClick
                        .compactMap({ $0.pageNavigation?.pageSlug })
                        .first else { return nil }

                let posterURL: URL?
                if let src = data.image?.src {
                    posterURL = URL(string: imageBaseURL + src)
                } else {
                    posterURL = nil
                }

                return Movie(
                    id: pageSlug,
                    title: title,
                    subtitle: description ?? "Featured",
                    pageSlug: pageSlug,
                    posterURL: posterURL
                )
            }
            movies.append(contentsOf: heroMovies)
        }

        if let resultsSpace = success.page.spaces.results,
           let widgetWrappers = resultsSpace.widgetWrappers {
            let searchMovies = widgetWrappers
                .flatMap { $0.widget.data.items }
                .compactMap { item -> Movie? in
                    guard
                        let card = item.searchCard,
                        let pageSlug = card.data.actions.onClick
                            .compactMap({ $0.pageNavigation?.pageSlug })
                            .first
                    else { return nil }

                    let posterURL: URL?
                    if let src = card.data.image?.src {
                        posterURL = URL(string: imageBaseURL + src)
                    } else {
                        posterURL = nil
                    }

                    return Movie(
                        id: pageSlug,
                        title: card.data.title,
                        subtitle: card.data.subtitle ?? "No subtitle available",
                        pageSlug: pageSlug,
                        posterURL: posterURL
                    )
                }
            movies.append(contentsOf: searchMovies)
        }

        return movies.filter { $0.pageSlug.hasPrefix("/in/movies") }
    }
}
