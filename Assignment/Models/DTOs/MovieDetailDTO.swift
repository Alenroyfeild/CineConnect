//
//  MovieDetailDTO.swift
//  Assignment
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

extension MovieDetailDTO {
    private var imageBaseURL: String {
        "https://img1.hotstarext.com/image/upload/f_auto/"
    }
    
    func toMovieDetail() -> MovieDetail? {
        for space in success.page.spaces.values {
            guard let wrappers = space.widgetWrappers else { continue }
            
            for wrapper in wrappers {
                let data = wrapper.widget.data
                
                if let info = data.contentInfo {
                    let rating = info.calloutMetaTags?.first?.calloutTag.txt.text
                    
                    let duration = info.superscriptTags?
                        .first(where: { $0.value?.contains("h") == true && $0.value?.contains("m") == true })?
                        .value
                    
                    let posterURL: URL?
                    if let src = data.heroImg?.src {
                        posterURL = URL(string: imageBaseURL + src)
                    } else {
                        posterURL = nil
                    }
                    
                    return MovieDetail(
                        title: info.title,
                        subtitle: data.starcast,
                        description: info.description,
                        posterURL: posterURL,
                        rating: rating,
                        duration: duration
                    )
                }
            }
        }
        return nil
    }
}
