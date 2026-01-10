//
//  AuthManager.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation
import WebKit
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isLoggedIn: Bool
    
    private let userTokenKey = "x-hs-usertoken"
    private let platformKey = "x-hs-platform"
    private let cookieKey = "cookie"
    
    private init() {
        self.isLoggedIn = UserDefaults.standard.string(forKey: userTokenKey) != nil &&
                         UserDefaults.standard.string(forKey: cookieKey) != nil
    }
    
    func getUserToken() -> String? {
        return UserDefaults.standard.string(forKey: userTokenKey)
    }
    
    func getPlatform() -> String? {
        return UserDefaults.standard.string(forKey: platformKey) ?? "web"
    }
    
    func getCookie() -> String? {
        return UserDefaults.standard.string(forKey: cookieKey)
    }
    
    func getHeaders() -> [String: String] {
        var headers: [String: String] = [
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
        ]
        
        if let platform = getPlatform() {
            headers["x-hs-platform"] = platform
        }
        
        if let userToken = getUserToken() {
            headers["x-hs-usertoken"] = userToken
        }
        
        if let cookie = getCookie() {
            headers["Cookie"] = cookie
        }
        
        return headers
    }
    
    func saveCredentials(userToken: String?, platform: String?, cookie: String?) {
        print("💾 AuthManager: Saving credentials...")
        
        if let userToken = userToken {
            UserDefaults.standard.set(userToken, forKey: userTokenKey)
            print("✅ Saved userToken: \(userToken.prefix(20))...")
        }
        
        let finalPlatform = platform ?? "web"
        UserDefaults.standard.set(finalPlatform, forKey: platformKey)
        print("✅ Saved platform: \(finalPlatform)")
        
        if let cookie = cookie {
            UserDefaults.standard.set(cookie, forKey: cookieKey)
            print("✅ Saved cookie: \(cookie.prefix(50))...")
        }
        
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            self.isLoggedIn = true
            print("✅ AuthManager: isLoggedIn = true")
        }
    }
    
    func isAuthenticated() -> Bool {
        let hasToken = getUserToken() != nil
        let hasCookie = getCookie() != nil
        let authenticated = hasToken && hasCookie
        
        print("🔐 AuthManager: isAuthenticated = \(authenticated) (token: \(hasToken), cookie: \(hasCookie))")
        return authenticated
    }
    
    func logout(completion: (() -> Void)? = nil) {
        print("🚪 AuthManager: Logging out...")
        
        UserDefaults.standard.removeObject(forKey: userTokenKey)
        UserDefaults.standard.removeObject(forKey: platformKey)
        UserDefaults.standard.removeObject(forKey: cookieKey)
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            self.isLoggedIn = false
        }
        
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            print("🗑️ Clearing \(records.count) WebKit data records...")
            
            dataStore.removeData(ofTypes: dataTypes, for: records) {
                print("✅ WebKit data cleared")
                
                self.clearHTTPCookies()
                
                URLCache.shared.removeAllCachedResponses()
                print("✅ URL cache cleared")
                
                DispatchQueue.main.async {
                    completion?()
                }
            }
        }
    }
    
    private func clearHTTPCookies() {
        if let cookies = HTTPCookieStorage.shared.cookies {
            print("🗑️ Clearing \(cookies.count) HTTP cookies...")
            for cookie in cookies {
                if cookie.domain.contains("hotstar") {
                    print("🗑️ Deleting cookie: \(cookie.name)")
                }
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
            print("✅ HTTP cookies cleared")
        }
    }
    
    func navigateToLogin(from window: UIWindow?) {
        print("🔄 Navigating to login...")
        
        guard let window = window else {
            print("❌ Window not available")
            return
        }
        
        let loginVC = LoginViewController()
        
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = loginVC
        }
        
        window.makeKeyAndVisible()
        print("✅ Navigated to login")
    }
}
