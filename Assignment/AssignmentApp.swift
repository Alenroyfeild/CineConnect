//
//  AssignmentApp.swift
//  Assignment
//
//  Created by Balaji Royal on 09/01/26.
//

import SwiftUI

@main
struct AssignmentApp: App {
    private let dependencyContainer: AppDependencyContainer
    @StateObject private var appCoordinator: AppCoordinator

    init() {
        let container = AppDependencyContainer()
        dependencyContainer = container
        _appCoordinator = StateObject(wrappedValue: container.makeAppCoordinator())
    }

    var body: some Scene {
        WindowGroup {
            appCoordinator.makeRootView()
                .onAppear { appCoordinator.start() }
        }
    }
}
