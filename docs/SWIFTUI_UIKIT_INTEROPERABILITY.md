# SwiftUI ↔ UIKit Interoperability in CineConnect

CineConnect's login flow is a real, unavoidable case for this bridge: there
is no public Hotstar login API, so authentication means driving an actual
`WKWebView` through a real login page and extracting session cookies from
it - something SwiftUI has no native primitive for. This document explains
exactly how that bridge works, using the real files involved.

## The three files involved

| File | Direction | Role |
|---|---|---|
| [`CineConnect/Views/Login/LoginView.swift`](../CineConnect/Views/Login/LoginView.swift) | SwiftUI → UIKit | `UIViewControllerRepresentable` that hosts `LoginViewController` |
| [`CineConnect/Views/Login/LoginViewController.swift`](../CineConnect/Views/Login/LoginViewController.swift) | UIKit, owns WebKit | The actual login screen: `WKWebView`, cookie extraction, calling `AuthManager` |
| [`CineConnect/Coordinators/AuthenticationCoordinator.swift`](../CineConnect/Coordinators/AuthenticationCoordinator.swift) | SwiftUI coordination | Constructs `LoginView`, reacts to its completion event |

## SwiftUI creating UIKit

```swift
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
```

`makeUIViewController` is called once, when SwiftUI first needs to render
this view. `authManager` is passed in from `AuthenticationCoordinator` (see
below) - `LoginView` never constructs its own `AuthManager` or reaches for
`AuthManager.shared`.

## `makeUIViewController` vs. `updateUIViewController`

- **`makeUIViewController`**: construction, called once per representable
  instance's lifetime. This is where `LoginViewController(authManager:)` is
  built and its `onAuthenticated` closure is wired.
- **`updateUIViewController`**: called whenever SwiftUI re-evaluates this
  view's parent and the representable's own properties might have changed.
  It's empty here - deliberately: nothing about `LoginView`'s state changes
  after creation (`authManager` and `onAuthenticated` are both set once),
  so there's nothing for SwiftUI to push into the controller on update. An
  empty `updateUIViewController` is correct here, not an oversight.

## Why no `Coordinator` object

`UIViewControllerRepresentable` supports an associated `Coordinator` type
specifically for cases where the UIKit side needs to act as a delegate
(e.g., implementing `WKNavigationDelegate` and reporting back *through* the
representable). `LoginViewController` implements `WKNavigationDelegate`
itself, directly - it doesn't need the representable to mediate that,
because none of the navigation-delegate callbacks need to reach SwiftUI.
The only thing that does need to reach SwiftUI (successful login) is
reported via a plain closure (`onAuthenticated`) instead.

**When would a `Coordinator` become necessary here?** If `LoginViewController`
needed the *representable itself* to own delegate conformance (for example,
if `LoginView` needed to inspect or modify web view navigation policy from
SwiftUI-owned state), a `Coordinator` would be the place to put that
delegate conformance, since the coordinator - unlike the `View` struct -
has reference semantics and can persist across view updates.

## UIKit sending events to SwiftUI: delegates vs. closures

`LoginViewController.onAuthenticated: (() -> Void)?` is a plain closure
property, not a delegate protocol. For a single, one-shot "I'm done" event,
a closure is simpler than defining a one-method delegate protocol - there's
no ongoing back-and-forth that would benefit from a named protocol type.
`WKNavigationDelegate`, by contrast, *is* a delegate protocol, because
WebKit itself defines that contract and it involves many distinct callback
moments (`didFinish`, `decidePolicyFor`, etc.) - `LoginViewController`
implements it directly for its own web-view lifecycle, unrelated to how it
talks to SwiftUI.

## Ownership and ARC

```swift
final class AuthenticationCoordinator: Coordinator {
    let authManager: AuthManager
    var onAuthenticated: (() -> Void)?

    func makeView() -> some View {
        LoginView(authManager: authManager, onAuthenticated: { [weak self] in
            self?.onAuthenticated?()
        })
        .environmentObject(authManager)
    }
}
```

The closure passed into `LoginView` captures `self` **weakly**. Without
`[weak self]`, the closure would hold a strong reference to
`AuthenticationCoordinator`, which `AppCoordinator` also holds strongly -
not an actual retain cycle in this specific graph (the closure doesn't get
stored back onto something `self` owns), but `[weak self]` is the safe
default for any closure crossing a coordinator boundary in this codebase,
and costs nothing here since the coordinator's lifetime doesn't depend on
this specific closure firing.

Inside `LoginViewController`, `Task { [weak self] in ... }` blocks (used to
bridge async work into synchronous UIKit lifecycle methods, see below) also
capture `self` weakly - a `LoginViewController` that's been dismissed
shouldn't be kept alive just because an in-flight `Task` still holds a
strong reference to it.

## `@MainActor` requirements

`LoginViewController` is not itself annotated `@MainActor` (a tracked,
honest gap - see `docs/Learning/FILE_INDEX.md`'s entry for this file), but
every UIKit call within it runs on the main thread by UIKit's own
lifecycle guarantees. `AuthManager`, which it holds a reference to, *is*
`@MainActor`-isolated - calls like `await authManager.saveCredentials(...)`
from inside a `Task` started in a UIKit callback correctly hop onto the
main actor for that call.

## Bridging WebKit's completion-handler APIs into `async/await`

`WKWebsiteDataStore` and `WKHTTPCookieStore` predate Swift concurrency and
only offer completion-handler APIs. `WebDataClearingService` and
`LoginViewController.extractAndSaveHeaders` both bridge these into
`async/await` via `withCheckedContinuation`:

```swift
let cookies = await withCheckedContinuation { continuation in
    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
        continuation.resume(returning: cookies)
    }
}
```

This doesn't change WebKit's underlying behavior - the completion handler
still fires exactly once, on the main thread - it just lets the rest of
the method read as a linear `async` sequence instead of a pyramid of
nested closures, and lets `HotstarCredentialExtractor.extract(from:)` (a
plain, non-async, pure function) sit cleanly in between.

## Why app navigation stays outside `LoginViewController`

`LoginViewController.navigateToMainApp()` does exactly one thing:
`onAuthenticated?()`. It has no knowledge of `AppCoordinator`, `Root`, or
any other screen. This matters for two reasons:

1. **Testability**: `HotstarCredentialExtractor`'s logic is unit-tested
   with zero UIKit/WebKit/navigation involvement (see
   `CineConnectTests/HotstarCredentialExtractorTests.swift`) precisely
   because credential extraction and "what happens next" are separate
   concerns.
2. **Single navigation owner**: `AppCoordinator` is the only type that
   decides what showing `.movies` after login actually means. If
   `LoginViewController` navigated directly (e.g., by replacing
   `window.rootViewController`, which the pre-migration code used to do),
   there would be two competing navigation authorities in the app instead
   of one.

## Security limitations, stated honestly

This is credential extraction from an unofficial, reverse-engineered web
login flow, not an OAuth SDK or a documented API:

- Hotstar's cookie/session contract can change at any time without notice,
  breaking `HotstarCredentialExtractor`'s hardcoded cookie-name list
  (`userUP`, `sessionUserUP`, `userHID`, etc.).
- The extracted session token is a long-lived credential with whatever
  privileges the logged-in web session has - there is no scoped,
  revocable, short-lived token the way a real OAuth flow would provide.
- Storage moved from plaintext `UserDefaults` to the Keychain in Phase 5
  (see `docs/Learning/Architecture/Phase-05-Authentication.md`), which
  meaningfully raises the bar against casual on-device inspection, but
  does not change the fundamental fragility of depending on an unofficial
  web login surface.
- This project's own git history includes a real incident (see
  `SECURITY.md`) where an actual session credential was accidentally
  committed - a concrete illustration of why credentials extracted this
  way must never appear in logs, source, or test fixtures, and why
  `scripts/check-secrets.sh` exists.
