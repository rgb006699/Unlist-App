import Foundation
import Testing
import WebKit
@testable import Unlist

@Suite struct NavigationRuleTests {
    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func webPagesLoad() {
        #expect(navigationDecision(for: url("https://a.com/x"), userInitiated: false) == .allow)
        #expect(navigationDecision(for: url("about:blank"), userInitiated: false) == .allow)
    }

    @Test func mailAndPhoneOpenOnlyOnATap() {
        #expect(navigationDecision(for: url("mailto:a@b.com"), userInitiated: true) == .handOff)
        #expect(navigationDecision(for: url("tel:5125550100"), userInitiated: false) == .cancel)
    }

    @Test func otherSchemesAreQuietlyCancelled() {
        #expect(navigationDecision(for: url("itms-apps://x"), userInitiated: true) == .cancel)
        #expect(navigationDecision(for: url("intent://x"), userInitiated: false) == .cancel)
    }

    @Test func policyInterruptionsAreNotShownAsErrors() {
        #expect(isIgnorableLoadError(NSError(domain: "WebKitErrorDomain", code: 101)))
        #expect(isIgnorableLoadError(NSError(domain: "WebKitErrorDomain", code: 102)))
        #expect(isIgnorableLoadError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        #expect(!isIgnorableLoadError(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
    }
}

@MainActor
@Suite struct BrowserStateTests {
    @Test func creatingTheStateDoesNotLoadAnything() {
        let state = BrowserState(url: URL(string: "https://example.com/results")!)
        #expect(state.webView.url == nil)
        #expect(!state.webView.isLoading)
        state.start()
        #expect(state.webView.isLoading || state.webView.url != nil)
    }
}

@Suite struct PopupRuleTests {
    @Test func onlyTappedLinksAndFormsOpenNewWindowsInPlace() {
        #expect(opensPopupInPlace(.linkActivated))
        #expect(opensPopupInPlace(.formSubmitted))
        // window.open from a page script (ads, pop-unders) is dropped.
        #expect(!opensPopupInPlace(.other))
    }
}

@MainActor
@Suite struct FillReadinessTests {
    @Test func fillIsReadyOnceThePageCommitsNotWhenItFinishes() {
        let state = BrowserState(url: URL(string: "https://example.com/")!)
        state.webView(state.webView, didStartProvisionalNavigation: nil)
        #expect(!state.canFill)
        state.webView(state.webView, didCommit: nil)
        #expect(state.isLoading)
        #expect(state.canFill)
        state.webView(state.webView, didStartProvisionalNavigation: nil)
        #expect(!state.canFill)
    }
}

@Suite struct GroupQuestionTests {
    @Test func theQuestionNamesTheStatus() {
        #expect(groupQuestion(count: 5, status: .requestSent) == "Mark all 5 sites in this group as request sent?")
    }
}
