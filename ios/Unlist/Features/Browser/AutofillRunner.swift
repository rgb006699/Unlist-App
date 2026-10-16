import WebKit

/// Runs the fill script in Unlist's own JavaScript world: it shares the
/// page's form fields but not its globals or prototypes, so page scripts
/// can't intercept the values.
@MainActor
enum AutofillRunner {
    static var world: WKContentWorld = .defaultClient

    static func fill(_ web: WKWebView, payload: String) async -> Int {
        let body = AutofillScript.source + "\nreturn window.unlistFill(JSON.parse(payload)).filled;"
        let result = try? await web.callAsyncJavaScript(body, arguments: ["payload": payload], in: nil, contentWorld: world)
        return (result as? NSNumber)?.intValue ?? 0
    }
}
