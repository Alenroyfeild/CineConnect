import Foundation

/// Pure extraction logic pulled out of `LoginViewController` so it's
/// testable without any `WKWebView`/UIKit dependency - `HTTPCookie` is a
/// plain Foundation type constructible directly in a test.
///
/// `nonisolated`: pure, stateless functions with no reason to be
/// actor-isolated at all - without this, the project's default-actor-
/// isolation setting infers this type's static methods as `@MainActor`
/// (the same pattern documented on `Movie`/`MovieDetail`, Phase 6),
/// which under `SWIFT_STRICT_CONCURRENCY = complete` (Phase 9) surfaced
/// as warnings in every test calling `extract(from:)` from a plain
/// (non-`@MainActor`) test struct.
nonisolated enum HotstarCredentialExtractor {
    private static let essentialCookieNames: Set<String> = [
        "userUP", "sessionUserUP", "userHID", "userPID",
        "deviceId", "loc", "geo", "SELECTED__LANGUAGE"
    ]

    struct ExtractedCredentials: Equatable {
        let cookieString: String
        let userToken: String
    }

    /// Returns `nil` when the cookie jar doesn't yet contain enough of a
    /// completed login to extract a usable session - the caller (today,
    /// `LoginViewController`) is expected to keep waiting/prompt the user
    /// again rather than treat `nil` as an error.
    static func extract(from cookies: [HTTPCookie]) -> ExtractedCredentials? {
        var essentialCookies: [HTTPCookie] = []
        var cookieString = ""
        var userToken = ""

        for cookie in cookies where cookie.domain.contains("hotstar") {
            guard essentialCookieNames.contains(cookie.name) else { continue }
            essentialCookies.append(cookie)
            cookieString += "\(cookie.name)=\(cookie.value); "
            if cookie.name == "userUP" || cookie.name == "sessionUserUP" {
                userToken = cookie.value
            }
        }

        if userToken.isEmpty, let locCookie = essentialCookies.first(where: { $0.name == "loc" }) {
            userToken = locCookie.value
        }

        let trimmedCookieString = cookieString.trimmingCharacters(in: .whitespaces)
        guard !trimmedCookieString.isEmpty, !userToken.isEmpty else { return nil }

        return ExtractedCredentials(cookieString: trimmedCookieString, userToken: userToken)
    }
}
