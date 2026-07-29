import Foundation
import WebKit

/// Clears WebKit website data, HTTP cookies, and the shared `URLCache`.
///
/// Before Phase 5, this exact sequence was duplicated in both
/// `AuthManager.logout` and `LoginViewController.clearAllWebData` - one
/// dedicated service now owns it, matching the migration's requirement
/// that "web data clearing is isolated in a dedicated service."
@MainActor
final class WebDataClearingService {
    /// Wraps `WKWebsiteDataStore`'s completion-handler API in `async/await`
    /// via a checked continuation - the callback-based API itself is
    /// unchanged (WebKit doesn't offer an async variant), only how callers
    /// consume it.
    func clearAllWebData() async {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        let records = await withCheckedContinuation { continuation in
            dataStore.fetchDataRecords(ofTypes: dataTypes) { continuation.resume(returning: $0) }
        }

        await withCheckedContinuation { continuation in
            dataStore.removeData(ofTypes: dataTypes, for: records) { continuation.resume() }
        }

        clearHTTPCookies()
        URLCache.shared.removeAllCachedResponses()
    }

    private func clearHTTPCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        for cookie in cookies {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }
}
