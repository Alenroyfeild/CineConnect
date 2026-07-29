import Foundation

/// Maps the Hotstar detail-page response shape to the domain `MovieDetail`
/// model. Kept separate from `MovieDetailDTO.swift` for the same reason as
/// `MovieSearchMapper.swift` - decoding shape and mapping decisions change
/// independently.
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
