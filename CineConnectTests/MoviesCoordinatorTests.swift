import Foundation
import Testing
@testable import CineConnect

@MainActor
struct MoviesCoordinatorTests {
    private func makeCoordinator() -> MoviesCoordinator {
        MoviesCoordinator(authManager: .shared, remoteService: RemoteService())
    }

    @Test func pathStartsEmpty() {
        let coordinator = makeCoordinator()
        #expect(coordinator.path.isEmpty)
    }

    @Test func appendingDetailRouteGrowsPath() {
        let coordinator = makeCoordinator()
        let movie = Movie(id: "1", title: "Test", subtitle: "Subtitle", pageSlug: "/in/movies/test/1", posterURL: nil)

        coordinator.path.append(MoviesRoute.detail(movie))

        #expect(coordinator.path.count == 1)
    }
}
