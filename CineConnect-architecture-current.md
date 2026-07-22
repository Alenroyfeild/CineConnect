# CineConnect architecture — baseline (CC0)

Verified from the local `Assignment.xcodeproj` checkout on 2026-07-22.

## Current flow

- `Assignment/AssignmentApp.swift` is the SwiftUI `@main` entry point. It observes the singleton `AuthManager` and conditionally renders either `LoginView` or `MoviesListView`.
- `Assignment/Utils/AuthManager.swift` owns persisted Hotstar credentials and the published login state. It also contains imperative window navigation helpers and logout cleanup.
- `Assignment/Views/Login/LoginView.swift` bridges to the UIKit `LoginViewController`, whose WebKit flow extracts credentials and currently replaces the window root with a hosted `MoviesListView`.
- `Assignment/Views/MoviesListView.swift` owns a `MovieSearchViewModel`, search UI, logout action, and a SwiftUI `NavigationStack` that pushes `MovieDetailView`.
- `Assignment/Views/MovieDetailView.swift` owns a `MovieDetailViewModel` and loads detail data for the selected movie.
- `Assignment/ViewModels/` contains the existing search and detail MVVM state holders.
- `Assignment/Services/Remote/` is the existing reusable request/response/interceptor/error networking abstraction. `BaseAPIService`, `MovieSearchAPIService`, and `MovieDetailAPIService` use it for the movie APIs.
- `Assignment/Models/` contains the movie models and API DTOs.

## Baseline verification

- Project: `Assignment.xcodeproj`; scheme: `Assignment`.
- Xcode build: passed with `/Applications/Xcode.app` using an iOS Simulator SDK and code signing disabled for local verification.
- Interactive search → detail and login flows were not independently exercised in this environment because CoreSimulatorService is unavailable to the build host. The source-level flow is documented above.
- GitHub open-issue lookup was attempted for `Alenroyfeild/CineConnect`, but the environment could not connect to `api.github.com`; no issue status is asserted here.

## Known architectural gaps carried into CC1

Navigation decisions live in SwiftUI views and `AuthManager`/`LoginViewController`; there is no coordinator layer. The app also has no isolated offline cache. The existing remote service layer is intentionally preserved for the coordinator and cache slices.
