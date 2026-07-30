//
//  LoginViewController.swift
//  CineConnect
//
//  Created by Balaji Royal on 10/01/26.
//

import UIKit
import WebKit
import SwiftUI

/// `@MainActor`: closes a gap tracked since Phase 4/5 ("not `@MainActor`
/// -annotated explicitly"). UIKit view controllers are main-thread-bound
/// in practice already; making that explicit is what let this class's
/// `WKNavigationDelegate` conformance fully match the protocol's own
/// (main-actor-isolated) method signatures under `SWIFT_STRICT_CONCURRENCY
/// = complete` (Phase 9) - without it, `decidePolicyFor:decisionHandler:`
/// only "nearly matched" the optional requirement instead of overriding it.
@MainActor
class LoginViewController: UIViewController {
    var onAuthenticated: (() -> Void)?
    private var webView: WKWebView!
    private let loginURL = "https://www.hotstar.com/in/subscribe"
    private var hasExtractedCredentials = false

    private let authManager: AuthManager
    private let webDataClearingService = WebDataClearingService()

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

    /// No default parameter, no `AuthManager.shared` reference - injected
    /// by `LoginView`, which gets it from `AuthenticationCoordinator`.
    init(authManager: AuthManager) {
        self.authManager = authManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported - LoginViewController is always constructed programmatically with an injected AuthManager")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // No "already authenticated, skip login" check here: AppCoordinator
        // already gates whether this screen is shown at all based on real
        // authentication state (see AppCoordinator.start()) - duplicating
        // that check here would be validating a scenario that can't happen
        // in normal operation.
        Task { [weak self] in
            await self?.webDataClearingService.clearAllWebData()
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
        proceedButton.isEnabled = false
        proceedButton.alpha = 0.5
        Task { [weak self] in
            await self?.extractAndSaveHeaders()
        }
    }

    private func loadLogin() {
        guard let url = URL(string: loginURL) else { return }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        webView.load(request)
    }

    // MARK: - Extract Credentials

    /// Cookie extraction/validation itself lives in `HotstarCredentialExtractor`
    /// (pure, testable outside this ViewController) - this method's job is
    /// just bridging the `WKHTTPCookieStore` callback into that pure logic
    /// and reacting to its result.
    private func extractAndSaveHeaders() async {
        guard !hasExtractedCredentials else { return }

        let cookies = await withCheckedContinuation { continuation in
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }

        guard let extracted = HotstarCredentialExtractor.extract(from: cookies) else {
            proceedButton.isEnabled = true
            proceedButton.alpha = 1.0

            let alert = UIAlertController(
                title: "Login Required",
                message: "Please log in first.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        hasExtractedCredentials = true
        saveCookiesToPersistentStore(cookies: cookies.filter { $0.domain.contains("hotstar") })

        await authManager.saveCredentials(
            userToken: extracted.userToken,
            platform: "web",
            cookie: extracted.cookieString
        )

        navigateToMainApp()
    }

    private func saveCookiesToPersistentStore(cookies: [HTTPCookie]) {
        let persistentStore = WKWebsiteDataStore.default()

        for cookie in cookies {
            persistentStore.httpCookieStore.setCookie(cookie)
        }
    }

    // MARK: - Navigation

    private func navigateToMainApp() {
        onAuthenticated?()
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

    /// The three-parameter overload (with `preferences:`) is the SDK's
    /// current actual `WKNavigationDelegate` requirement - the older
    /// two-parameter form used before this phase compiled and ran (WebKit
    /// still called it via a compatibility path) but only "nearly matched"
    /// the real requirement under `SWIFT_STRICT_CONCURRENCY = complete`
    /// (Phase 9), since it wasn't actually overriding anything.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if let url = navigationAction.request.url {
            if url.absoluteString.contains("apps.apple.com") || url.absoluteString.contains("itunes.apple.com") {
                decisionHandler(.cancel, preferences)
                return
            }
        }

        decisionHandler(.allow, preferences)
    }
}
