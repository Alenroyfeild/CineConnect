import SwiftUI

@MainActor
final class AuthenticationCoordinator: Coordinator {
    let authManager: AuthManager
    var onAuthenticated: (() -> Void)?

    /// No default parameter - always supplied by `AppCoordinator`/
    /// `AppDependencyContainer`, never `AuthManager.shared` directly.
    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func makeView() -> some View {
        LoginView(onAuthenticated: { [weak self] in
            self?.onAuthenticated?()
        })
        .environmentObject(authManager)
    }
}
