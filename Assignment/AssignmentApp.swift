//
//  AssignmentApp.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import SwiftUI

@main
struct AssignmentApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            appCoordinator.makeRootView()
                .onAppear { appCoordinator.start() }
        }
    }
}
