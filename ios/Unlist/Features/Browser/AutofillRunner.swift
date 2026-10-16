import WebKit

/// Runs the fill script in Unlist's own JavaScript world: it shares the
/// page's form fields but not its globals or prototypes, so page scripts
/// can't intercept the values.
@MainActor
enum AutofillRunner {
    static var world: WKContentWorld = .defaultClient

    /// Fills every frame the tracker has seen (the main page when it has seen
    /// none yet); returns the total number of fields filled.
    static func fill(_ web: WKWebView, frames: FrameTracker? = nil, payload: String) async -> Int {
        let body = AutofillScript.source + "\nreturn window.unlistFill(JSON.parse(payload)).filled;"
        let targets: [WKFrameInfo?] = frames?.frames.isEmpty == false ? frames!.frames : [nil]
        var total = 0
        for frame in targets {
            // A frame that has gone away since it loaded just throws.
            let result = try? await web.callAsyncJavaScript(body, arguments: ["payload": payload], in: frame, contentWorld: world)
            total += (result as? NSNumber)?.intValue ?? 0
        }
        return total
    }
}

/// Remembers each frame that loads a document, so Fill can reach forms
/// inside iframes. A new main-frame document starts the list over.
@MainActor
final class FrameTracker: NSObject, WKScriptMessageHandler {
    private static let name = "unlistFrame"
    private(set) var frames: [WKFrameInfo] = []

    func install(in config: WKWebViewConfiguration) {
        let script = WKUserScript(source: "window.webkit.messageHandlers.\(Self.name).postMessage(0);",
                                  injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .defaultClient)
        config.userContentController.addUserScript(script)
        config.userContentController.add(self, contentWorld: .defaultClient, name: Self.name)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.frameInfo.isMainFrame { frames = [] }
        frames.append(message.frameInfo)
    }
}
