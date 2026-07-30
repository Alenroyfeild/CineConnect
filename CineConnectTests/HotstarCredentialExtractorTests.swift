import Foundation
import Testing
@testable import CineConnect

/// `HotstarCredentialExtractor` was pulled out of `LoginViewController`
/// specifically so it could be tested like this - with plain `HTTPCookie`
/// values, no `WKWebView` involved at all.
@Suite
struct HotstarCredentialExtractorTests {
    private func cookie(name: String, value: String, domain: String = ".hotstar.com") -> HTTPCookie {
        HTTPCookie(properties: [
            .name: name,
            .value: value,
            .domain: domain,
            .path: "/"
        ])!
    }

    @Test func extractsUserTokenFromUserUPCookie() {
        let cookies = [
            cookie(name: "userUP", value: "token-value"),
            cookie(name: "deviceId", value: "device-123")
        ]

        let result = HotstarCredentialExtractor.extract(from: cookies)

        #expect(result?.userToken == "token-value")
        #expect(result?.cookieString.contains("userUP=token-value") == true)
        #expect(result?.cookieString.contains("deviceId=device-123") == true)
    }

    @Test func fallsBackToLocCookieWhenNoUserTokenCookiePresent() {
        let cookies = [
            cookie(name: "loc", value: "loc-value"),
            cookie(name: "deviceId", value: "device-123")
        ]

        let result = HotstarCredentialExtractor.extract(from: cookies)

        #expect(result?.userToken == "loc-value")
    }

    @Test func ignoresCookiesFromOtherDomains() {
        let cookies = [
            cookie(name: "userUP", value: "should-be-ignored", domain: ".example.com")
        ]

        #expect(HotstarCredentialExtractor.extract(from: cookies) == nil)
    }

    @Test func ignoresCookiesNotInTheEssentialList() {
        let cookies = [
            cookie(name: "some_other_cookie", value: "irrelevant")
        ]

        #expect(HotstarCredentialExtractor.extract(from: cookies) == nil)
    }

    @Test func returnsNilWhenNoUsableTokenCanBeFound() {
        let cookies = [
            cookie(name: "SELECTED__LANGUAGE", value: "en")
        ]

        #expect(HotstarCredentialExtractor.extract(from: cookies) == nil)
    }

    @Test func returnsNilForEmptyCookieList() {
        #expect(HotstarCredentialExtractor.extract(from: []) == nil)
    }
}
