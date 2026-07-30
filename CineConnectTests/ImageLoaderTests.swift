import Foundation
import UIKit
import Testing
@testable import CineConnect

/// Uses the same `StubImageURLProtocol` networking tests use (Phase 4) - no
/// live image server involved. A tiny valid PNG is used as fixture data.
@MainActor
@Suite(.serialized)
struct ImageLoaderTests {
    /// The smallest possible valid PNG (1x1 transparent pixel), so
    /// `UIImage(data:)` succeeds without bundling a real image asset.
    private static let onePixelPNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ])

    private func makeLoader() -> ImageLoader {
        ImageLoader(urlSession: StubImageURLProtocol.makeSession(), memoryCache: MemoryCache(ttl: 60))
    }

    @Test func loadsAndDecodesAnImageOnSuccess() async throws {
        StubImageURLProtocol.reset()
        StubImageURLProtocol.requestHandler = { _ in (200, [:], Self.onePixelPNG) }
        let loader = makeLoader()

        let image = try await loader.image(for: URL(string: "https://example.com/poster.png")!)

        #expect(image.size.width == 1)
    }

    @Test func secondRequestForSameURLHitsMemoryCacheNotNetwork() async throws {
        StubImageURLProtocol.reset()
        StubImageURLProtocol.requestHandler = { _ in (200, [:], Self.onePixelPNG) }
        let loader = makeLoader()
        let url = URL(string: "https://example.com/poster.png")!

        _ = try await loader.image(for: url)
        StubImageURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) } // would fail if hit again
        let second = try await loader.image(for: url)

        #expect(second.size.width == 1)
    }

    @Test func nonSuccessStatusCodeThrows() async {
        StubImageURLProtocol.reset()
        StubImageURLProtocol.requestHandler = { _ in (404, [:], Data()) }
        let loader = makeLoader()

        await #expect(throws: ImageLoadingError.self) {
            _ = try await loader.image(for: URL(string: "https://example.com/missing.png")!)
        }
    }

    @Test func invalidImageDataThrows() async {
        StubImageURLProtocol.reset()
        StubImageURLProtocol.requestHandler = { _ in (200, [:], Data("not an image".utf8)) }
        let loader = makeLoader()

        await #expect(throws: ImageLoadingError.self) {
            _ = try await loader.image(for: URL(string: "https://example.com/poster.png")!)
        }
    }

    @Test func tenConcurrentRequestsForSameURLResultInOneNetworkCall() async throws {
        StubImageURLProtocol.reset()
        StubImageURLProtocol.requestHandler = { _ in (200, [:], Self.onePixelPNG) }
        let loader = makeLoader()
        let url = URL(string: "https://example.com/poster.png")!

        try await withThrowingTaskGroup(of: UIImage.self) { group in
            for _ in 0..<10 {
                group.addTask { try await loader.image(for: url) }
            }
            for try await _ in group {}
        }

        #expect(StubImageURLProtocol.receivedRequests.count == 1)
    }
}
