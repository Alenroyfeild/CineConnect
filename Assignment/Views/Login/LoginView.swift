//
//  LoginView.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//


import SwiftUI
import WebKit

struct LoginView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> LoginViewController {
        return LoginViewController()
    }
    
    func updateUIViewController(_ uiViewController: LoginViewController, context: Context) {}
}