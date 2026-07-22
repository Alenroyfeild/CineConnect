import SwiftUI

@MainActor
final class AuthCoordinator: Coordinator {
    let authManager: AuthManager
    var onAuthenticated: (() -> Void)?

    init(authManager: AuthManager = .shared) {
        self.authManager = authManager
    }

    func makeView() -> some View {
        LoginView(onAuthenticated: { [weak self] in
            self?.onAuthenticated?()
        })
        .environmentObject(authManager)
    }
}
