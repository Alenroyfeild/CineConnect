import SwiftUI

@MainActor
final class MoviesCoordinator: Coordinator {
    let authManager: AuthManager
    var onLogout: (() -> Void)?

    init(authManager: AuthManager = .shared) {
        self.authManager = authManager
    }

    func makeView() -> some View {
        NavigationStack {
            MoviesListView(onLogout: { [weak self] in
                self?.onLogout?()
            })
                .environmentObject(authManager)
                .navigationDestination(for: Movie.self) { movie in
                    MovieDetailView(movie: movie)
                }
        }
    }
}
