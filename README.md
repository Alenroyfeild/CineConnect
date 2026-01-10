# CineConnect

CineConnect is an iOS SwiftUI app (MVVM) that lets users browse and search movies, view a simple preview image, description, IMDb rating (if available), and duration. It uses a WebView\-based login flow to obtain authentication required for fetching data.

## Features

- Movie browsing list UI
- Movie details screen (image, description, IMDb rating if present, duration)
- Search with debounced input (MVVM \+ Combine)
- WebView login flow (WKWebView) to acquire auth/session
- Async networking via a shared remote layer

## Project Structure

```text
Assignment/
├── AssignmentApp.swift
├── Assets.xcassets/
├── Models/
│   ├── Movie.swift
│   ├── MovieDetail.swift
│   └── DTOs/
│       ├── MovieDetailDTO.swift
│       └── MovieSearchDTO.swift
├── Services/
│   ├── BaseAPIService.swift
│   ├── Endpoints.swift
│   ├── MovieDetailAPIService.swift
│   ├── MovieSearchAPIService.swift
│   └── Remote/
│       ├── Constants.swift
│       ├── Convertables.swift
│       ├── Interceptors.swift
│       ├── RemoteError.swift
│       ├── RemoteService.swift
│       ├── Request.swift
│       └── Response.swift
├── Utils/
│   ├── AppFont.swift
│   ├── AppTheme.swift
│   └── AuthManager.swift
├── ViewModels/
│   ├── MovieDetailViewModel.swift
│   └── MovieSearchViewModel.swift
└── Views/
    ├── LoadingSpinner.swift
    ├── MovieDetailView.swift
    ├── MoviesListView.swift
    └── Login/
        ├── LoginView.swift
        └── LoginViewController.swift
```

## Architecture

The app follows **MVVM**\:

- **Views** in `Views/` render UI with SwiftUI.
- **ViewModels** in `ViewModels/` manage state, user actions, and async tasks.
- **Services** in `Services/` perform networking and endpoint coordination.
- **Models** in `Models/` represent app domain objects, while `Models/DTOs/` map API payloads.

## Authentication

Login is handled through `Views/Login/` using `WKWebView` (UIKit integration).  
`Utils/AuthManager.swift` manages auth/session state (token and/or cookies depending on the implementation). Services use this auth state when performing requests.

## Networking Layer

Networking is implemented under `Services/Remote/` with shared request/response types and error handling. Feature services like:

- `Services/MovieSearchAPIService.swift`
- `Services/MovieDetailAPIService.swift`

build requests using `Services/Endpoints.swift` and the base abstractions in `Services/BaseAPIService.swift`.

## Requirements

- macOS with Xcode
- iOS target supported by the project (per Xcode settings)
- SwiftUI
- Network access for API calls
- A valid account for the streaming platform login flow (if required for auth)

## Build \& Run

1. Open `Assignment/Assignment.xcodeproj` in Xcode.
2. Select a simulator or device.
3. Build and run.

## Testing

If tests are added to the project, run them in Xcode via **Product \> Test** (or `⌘` \+ `U`).

## License

Educational/demo use only. Any referenced trademarks, branding, and media content belong to their respective owners.
