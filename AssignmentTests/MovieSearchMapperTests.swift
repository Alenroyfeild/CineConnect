import Foundation
import Testing
@testable import Assignment

/// Tests `MovieSearchDTO.toMovies()` - the explicit DTO-to-domain mapping
/// this API's shape needs, isolated from any network call.
@MainActor
@Suite
struct MovieSearchMapperTests {
    private func decode(_ json: String) throws -> MovieSearchDTO {
        try JSONDecoder().decode(MovieSearchDTO.self, from: Data(json.utf8))
    }

    @Test func mapsAResultCardToAMovie() throws {
        let dto = try decode("""
        {
          "success": { "page": { "spaces": {
            "results": {
              "id": "r1", "template": "t",
              "widget_wrappers": [{
                "widget": { "data": { "items": [{
                  "search_horizontal_content_card": {
                    "data": {
                      "title": "Nanu Local",
                      "sub_title": "2017 - Kannada",
                      "image": { "src": "sources/r1/poster.jpg" },
                      "actions": { "on_click": [{ "page_navigation": { "page_slug": "/in/movies/nanu-local/1" } }] }
                    }
                  }
                }] } }
              }]
            }
          } } }
        }
        """)

        let movies = dto.toMovies()

        #expect(movies.count == 1)
        #expect(movies.first?.title == "Nanu Local")
        #expect(movies.first?.subtitle == "2017 - Kannada")
        #expect(movies.first?.pageSlug == "/in/movies/nanu-local/1")
        #expect(movies.first?.posterURL != nil)
    }

    @Test func missingOptionalSubtitleFallsBackToDefaultText() throws {
        let dto = try decode("""
        {
          "success": { "page": { "spaces": {
            "results": {
              "id": "r1", "template": "t",
              "widget_wrappers": [{
                "widget": { "data": { "items": [{
                  "search_horizontal_content_card": {
                    "data": {
                      "title": "No Subtitle Movie",
                      "actions": { "on_click": [{ "page_navigation": { "page_slug": "/in/movies/x/1" } }] }
                    }
                  }
                }] } }
              }]
            }
          } } }
        }
        """)

        let movies = dto.toMovies()

        #expect(movies.first?.subtitle == "No subtitle available")
        #expect(movies.first?.posterURL == nil)
    }

    @Test func itemMissingPageSlugIsFilteredOutNotCrashed() throws {
        let dto = try decode("""
        {
          "success": { "page": { "spaces": {
            "results": {
              "id": "r1", "template": "t",
              "widget_wrappers": [{
                "widget": { "data": { "items": [{
                  "search_horizontal_content_card": {
                    "data": {
                      "title": "No Slug Movie",
                      "actions": { "on_click": [] }
                    }
                  }
                }] } }
              }]
            }
          } } }
        }
        """)

        let movies = dto.toMovies()

        #expect(movies.isEmpty)
    }

    @Test func emptyResultsAndNoHeaderTrayMapsToEmptyArray() throws {
        let dto = try decode("""
        { "success": { "page": { "spaces": {} } } }
        """)

        #expect(dto.toMovies().isEmpty)
    }

    @Test func nonMovieSlugsAreFilteredOut() throws {
        let dto = try decode("""
        {
          "success": { "page": { "spaces": {
            "results": {
              "id": "r1", "template": "t",
              "widget_wrappers": [{
                "widget": { "data": { "items": [{
                  "search_horizontal_content_card": {
                    "data": {
                      "title": "A TV Show",
                      "actions": { "on_click": [{ "page_navigation": { "page_slug": "/in/shows/x/1" } }] }
                    }
                  }
                }] } }
              }]
            }
          } } }
        }
        """)

        #expect(dto.toMovies().isEmpty)
    }
}
