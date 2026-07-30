//
//  LoginView.swift
//  CineConnect
//
//  Created by Balaji Royal on 10/01/26.
//


import SwiftUI
import WebKit

struct LoginView: UIViewControllerRepresentable {
    let authManager: AuthManager
    var onAuthenticated: (() -> Void)?

    func makeUIViewController(context: Context) -> LoginViewController {
        let controller = LoginViewController(authManager: authManager)
        controller.onAuthenticated = onAuthenticated
        return controller
    }

    func updateUIViewController(_ uiViewController: LoginViewController, context: Context) {}
}
