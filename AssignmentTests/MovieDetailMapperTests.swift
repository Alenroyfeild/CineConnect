import Foundation
import Testing
@testable import Assignment

/// Tests `MovieDetailDTO.toMovieDetail()`.
@MainActor
@Suite
struct MovieDetailMapperTests {
    private func decode(_ json: String) throws -> MovieDetailDTO {
        try JSONDecoder().decode(MovieDetailDTO.self, from: Data(json.utf8))
    }

    @Test func mapsAFullDetailResponse() throws {
        let dto = try decode("""
        {
          "success": { "page": { "spaces": {
            "space1": {
              "widget_wrappers": [{
                "widget": { "data": {
                  "content_info": {
                    "title": "Nanu Local",
                    "description": "A comedy film.",
                    "callout_meta_tags": [{ "callout_tag": { "txt": { "text": "U/A 16+" } } }],
                    "superscript_tags": [{ "value": "2h 12m" }]
                  },
                  "hero_img": { "src": "sources/r1/poster.jpg" },
                  "starcast": "Actor One, Actor Two"
                } }
              }]
            }
          } } }
        }
        """)

        let detail = dto.toMovieDetail()

        #expect(detail?.title == "Nanu Local")
        #expect(detail?.description == "A comedy film.")
        #expect(detail?.rating == "U/A 16+")
        #expect(detail?.duration == "2h 12m")
        #expect(detail?.subtitle == "Actor One, Actor Two")
        #expect(detail?.posterURL != nil)
    }

    @Test func missingOptionalFieldsMapToNilNotACrash() throws {
        let dto = try decode("""
        {
          "success": { "page": { "spaces": {
            "space1": {
              "widget_wrappers": [{
                "widget": { "data": {
                  "content_info": {
                    "title": "Minimal Movie",
                    "description": "Just the basics."
                  }
                } }
              }]
            }
          } } }
        }
        """)

        let detail = dto.toMovieDetail()

        #expect(detail?.title == "Minimal Movie")
        #expect(detail?.rating == nil)
        #expect(detail?.duration == nil)
        #expect(detail?.subtitle == nil)
        #expect(detail?.posterURL == nil)
    }

    @Test func invalidResponseWithNoContentInfoAnywhereMapsToNil() throws {
        let dto = try decode("""
        {
          "success": { "page": { "spaces": {
            "space1": { "widget_wrappers": [{ "widget": { "data": {} } }] }
          } } }
        }
        """)

        #expect(dto.toMovieDetail() == nil)
    }

    @Test func noSpacesAtAllMapsToNil() throws {
        let dto = try decode("""
        { "success": { "page": { "spaces": {} } } }
        """)

        #expect(dto.toMovieDetail() == nil)
    }
}
