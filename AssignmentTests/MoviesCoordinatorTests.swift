import Foundation
import Testing
@testable import Assignment

@MainActor
struct MoviesCoordinatorTests {
    @Test func pathStartsEmpty() {
        let coordinator = MoviesCoordinator(authManager: .shared)
        #expect(coordinator.path.isEmpty)
    }

    @Test func appendingDetailRouteGrowsPath() {
        let coordinator = MoviesCoordinator(authManager: .shared)
        let movie = Movie(id: "1", title: "Test", subtitle: "Subtitle", pageSlug: "/in/movies/test/1", posterURL: nil)

        coordinator.path.append(MoviesRoute.detail(movie))

        #expect(coordinator.path.count == 1)
    }
}
