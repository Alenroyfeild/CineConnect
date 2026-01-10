//
//  AssignmentApp.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import SwiftUI

@main
struct AssignmentApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    MoviesListView()
                        .environmentObject(authManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}
