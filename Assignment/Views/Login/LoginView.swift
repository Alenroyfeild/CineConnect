//
//  LoginView.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//


import SwiftUI
import WebKit

struct LoginView: UIViewControllerRepresentable {
    var onAuthenticated: (() -> Void)?

    func makeUIViewController(context: Context) -> LoginViewController {
        let controller = LoginViewController()
        controller.onAuthenticated = onAuthenticated
        return controller
    }
    
    func updateUIViewController(_ uiViewController: LoginViewController, context: Context) {}
}
