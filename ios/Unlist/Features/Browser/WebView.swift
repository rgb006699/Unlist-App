import Observation
import SwiftUI
import WebKit

enum NavigationDecision: Equatable { case allow, handOff, cancel }

/// Web pages load; mail/phone links open the system app only when tapped;
/// anything else (app-store and app links, intents) is quietly dropped.
func navigationDecision(for url: URL, userInitiated: Bool) -> NavigationDecision {
    switch url.scheme?.lowercased() ?? "" {
    case "http", "https", "about", "blob", "data": .allow
    case "mailto", "tel", "sms": userInitiated ? .handOff : .cancel
    default: .cancel
    }
}

/// A new window (target=_blank) opens in place only when the person tapped a
/// link or sent a form; script popups such as ads are dropped.
func opensPopupInPlace(_ type: WKNavigationType) -> Bool {
    type == .linkActivated || type == .formSubmitted
}

/// Load "errors" that just mean a navigation was cancelled or handed off.
func isIgnorableLoadError(_ error: Error) -> Bool {
    let e = error as NSError
    if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return true }
    return e.domain == "WebKitErrorDomain" && (e.code == 101 || e.code == 102)
}

/// A broker page in a private web view (nothing is kept between visits).
@MainActor
@Observable
final class BrowserState: NSObject, WKNavigationDelegate, WKUIDelegate {
    @ObservationIgnored let webView: WKWebView
    @ObservationIgnored private let frames = FrameTracker()
    private(set) var host = ""
    private(set) var isLoading = false
    /// True once the page's document exists, which is long before ads and
    /// trackers finish loading.
    private(set) var canFill = false
    private(set) var errorText: String?
    private(set) var currentURL: URL?

    private let startURL: URL
    private var started = false

    /// Nothing loads until `start()`, so throwaway copies SwiftUI makes while
    /// re-rendering never contact the site.
    init(url: URL) {
        startURL = url
        currentURL = url
        host = url.host() ?? ""
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        frames.install(in: config)
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }

    func start() {
        guard !started else { return }
        started = true
        load(startURL)
    }

    func load(_ url: URL) {
        currentURL = url
        host = url.host() ?? ""
        webView.load(URLRequest(url: url))
    }

    func reload() {
        errorText = nil
        if webView.url == nil, let url = currentURL { load(url) } else { webView.reload() }
    }

    /// Runs the fill script on the current page; returns how many fields it filled.
    func fill(payload: String) async -> Int {
        await AutofillRunner.fill(webView, frames: frames, payload: payload)
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .allow }
        switch navigationDecision(for: url, userInitiated: action.navigationType == .linkActivated) {
        case .allow: return .allow
        case .handOff:
            await UIApplication.shared.open(url)
            return .cancel
        case .cancel: return .cancel
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        canFill = false
        errorText = nil
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        canFill = true
        currentURL = webView.url ?? currentURL
        host = webView.url?.host() ?? host
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        canFill = true
        currentURL = webView.url ?? currentURL
        host = webView.url?.host() ?? host
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failed(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failed(error)
    }

    private func failed(_ error: Error) {
        isLoading = false
        if isIgnorableLoadError(error) { return }
        errorText = error.localizedDescription
    }

    // MARK: WKUIDelegate

    /// Tapped links that open a new window load here instead.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, opensPopupInPlace(navigationAction.navigationType) {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

struct WebView: UIViewRepresentable {
    let state: BrowserState

    func makeUIView(context: Context) -> WKWebView { state.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
