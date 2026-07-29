import Foundation

/// Maps the Hotstar search response shape to the domain `Movie` model.
/// Kept separate from `MovieSearchDTO.swift` so the decoding shape and the
/// domain-mapping decision (what counts as a movie, what to do with
/// missing fields) can change independently.
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
