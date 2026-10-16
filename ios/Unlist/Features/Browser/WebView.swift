import Observation
import SwiftUI
import WebKit

/// A broker page in a private web view (nothing is kept between visits).
@MainActor
@Observable
final class BrowserState: NSObject, WKNavigationDelegate, WKUIDelegate {
    @ObservationIgnored let webView: WKWebView
    private(set) var host = ""
    private(set) var isLoading = false
    private(set) var errorText: String?
    private(set) var currentURL: URL?

    init(url: URL) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        load(url)
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
        let js = AutofillScript.source + "\n;unlistFill(\(payload)).filled"
        let result = try? await webView.evaluateJavaScript(js)
        return (result as? NSNumber)?.intValue ?? 0
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url, let scheme = url.scheme?.lowercased() else { return .allow }
        if ["mailto", "tel", "sms"].contains(scheme) {
            await UIApplication.shared.open(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        errorText = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
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
        if (error as NSError).code == NSURLErrorCancelled { return }
        errorText = error.localizedDescription
    }

    // MARK: WKUIDelegate

    /// Links that open a new window load here instead.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }
}

struct WebView: UIViewRepresentable {
    let state: BrowserState

    func makeUIView(context: Context) -> WKWebView { state.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
