//
//  LoginViewController.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import UIKit
import WebKit
import SwiftUI

class LoginViewController: UIViewController {
    private var webView: WKWebView!
    private let loginURL = "https://www.hotstar.com/in/subscribe"
    private var hasExtractedCredentials = false

    private let proceedButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("I've Logged In - Proceed", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
       
        if AuthManager.shared.isAuthenticated() {
            print("✅ Already authenticated, navigating to main app")
            navigateToMainApp()
            return
        }

        clearAllWebData { [weak self] in
            self?.setupWebView()
            self?.setupProceedButton()
            self?.loadLogin()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        hasExtractedCredentials = false
    }

    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }

    // MARK: - Clear All Data

    private func clearAllWebData(completion: @escaping () -> Void) {
        print("🗑️ Clearing ALL web data...")

        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            dataStore.removeData(ofTypes: dataTypes, for: records) {
                HTTPCookieStorage.shared.cookies?.forEach { cookie in
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
                URLCache.shared.removeAllCachedResponses()

                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

    // MARK: - Setup WebView

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        /// Enhanced viewport script to prevent cropping
        let viewportScript = WKUserScript(
            source: """
            (function() {
                // Set viewport
                var meta = document.querySelector('meta[name="viewport"]');
                if (!meta) {
                    meta = document.createElement('meta');
                    meta.name = 'viewport';
                    document.head.appendChild(meta);
                }
                meta.content = 'width=device-width, initial-scale=0.95, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';

                // Adjust body/html
                var style = document.createElement('style');
                style.textContent = `
                    html, body {
                        width: 100vw !important;
                        max-width: 100vw !important;
                        overflow-x: hidden !important;
                        overflow-y: auto !important;
                        margin: 0 !important;
                        padding: 0 !important;
                        box-sizing: border-box !important;
                    }
                    * {
                        max-width: 100vw !important;
                        box-sizing: border-box !important;
                    }
                `;
                document.head.appendChild(style);

                // Force reflow
                document.body.offsetHeight;
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        configuration.userContentController.addUserScript(viewportScript)

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupProceedButton() {
        view.addSubview(proceedButton)

        NSLayoutConstraint.activate([
            proceedButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            proceedButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            proceedButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            proceedButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        proceedButton.addTarget(self, action: #selector(proceedButtonTapped), for: .touchUpInside)
    }

    @objc private func proceedButtonTapped() {
        print("🚀 Proceed button tapped")
        proceedButton.isEnabled = false
        proceedButton.alpha = 0.5
        extractAndSaveHeaders()
    }

    private func loadLogin() {
        guard let url = URL(string: loginURL) else { return }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        webView.load(request)
    }

    // MARK: - Extract Credentials

    private func extractAndSaveHeaders() {
        guard !hasExtractedCredentials else { return }

        let dataStore = webView.configuration.websiteDataStore

        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }

            let essentialCookieNames = [
                "userUP", "sessionUserUP", "userHID", "userPID",
                "deviceId", "loc", "geo", "SELECTED__LANGUAGE"
            ]

            var essentialCookies: [HTTPCookie] = []
            var cookieString = ""
            var userToken = ""

            for cookie in cookies where cookie.domain.contains("hotstar") {
                if essentialCookieNames.contains(cookie.name) {
                    essentialCookies.append(cookie)
                    cookieString += "\(cookie.name)=\(cookie.value); "

                    if cookie.name == "userUP" || cookie.name == "sessionUserUP" {
                        userToken = cookie.value
                    }
                }
            }

            if userToken.isEmpty, let locCookie = essentialCookies.first(where: { $0.name == "loc" }) {
                userToken = locCookie.value
            }

            if !cookieString.isEmpty && !userToken.isEmpty {
                self.hasExtractedCredentials = true

                self.saveCookiesToPersistentStore(cookies: essentialCookies)

                AuthManager.shared.saveCredentials(
                    userToken: userToken,
                    platform: "web",
                    cookie: cookieString.trimmingCharacters(in: .whitespaces)
                )

                DispatchQueue.main.async {
                    self.navigateToMainApp()
                }
            } else {
                DispatchQueue.main.async {
                    self.proceedButton.isEnabled = true
                    self.proceedButton.alpha = 1.0

                    let alert = UIAlertController(
                        title: "Login Required",
                        message: "Please log in first.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func saveCookiesToPersistentStore(cookies: [HTTPCookie]) {
        let persistentStore = WKWebsiteDataStore.default()

        for cookie in cookies {
            persistentStore.httpCookieStore.setCookie(cookie)
        }
    }

    // MARK: - Navigation

    private func navigateToMainApp() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let moviesView = MoviesListView()
            .environmentObject(AuthManager.shared)

        let hostingController = UIHostingController(rootView: moviesView)

        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
            window.rootViewController = hostingController
        }

        window.makeKeyAndVisible()
    }
}

// MARK: - WKNavigationDelegate

extension LoginViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url?.absoluteString {
            if url.contains("hotstar.com") && !url.contains("/subscribe") {
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3) {
                        self.proceedButton.isHidden = false
                        self.proceedButton.alpha = 1.0
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.proceedButton.isHidden = true
                }
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            if url.absoluteString.contains("apps.apple.com") || url.absoluteString.contains("itunes.apple.com") {
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }
}
