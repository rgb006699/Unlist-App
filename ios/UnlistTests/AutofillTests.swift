import Foundation
import Testing
import WebKit
@testable import Unlist

@Suite struct AutofillValueTests {
    @Test func mapsTheProfile() {
        let v = autofillValues(Fixtures.profile)
        #expect(v == [
            .fullName: "Jane Q Doe", .firstName: "Jane", .lastName: "Doe",
            .email: "jane@example.com", .phone: "512-555-0100",
            .street: "22 New St", .city: "Austin", .state: "TX", .zip: "78701",
        ])
    }

    @Test func emptyProfileGivesNothing() {
        #expect(autofillValues(.empty).isEmpty)
    }

    @Test func usesFirstAddressWhenNoneIsCurrent() {
        var p = Fixtures.profile
        p.addresses = p.addresses.map { var a = $0; a.current = false; return a }
        #expect(autofillValues(p)[.street] == "1 Old Rd")
    }

    @Test func payloadCarriesValuesSelectorsAndStateName() throws {
        let json = autofillPayload(Fixtures.profile, selectors: [.email: "#mail"])
        let obj = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        #expect((obj["values"] as? [String: String])?["firstName"] == "Jane")
        #expect((obj["selectors"] as? [String: String])?["email"] == "#mail")
        #expect(obj["stateName"] as? String == "Texas")
    }
}

/// Loads HTML into a real WKWebView and runs the bundled fill script on it.
@MainActor
private final class TestPage: NSObject, WKNavigationDelegate {
    let web: WKWebView
    private var loaded: CheckedContinuation<Void, Never>?

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 800), configuration: config)
        super.init()
        web.navigationDelegate = self
    }

    func load(_ body: String) async {
        await withCheckedContinuation { c in
            loaded = c
            web.loadHTMLString("<!doctype html><html><body>\(body)</body></html>", baseURL: URL(string: "https://test.example/"))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded?.resume()
        loaded = nil
    }

    @discardableResult
    func fill(selectors: [AutofillField: String]? = nil) async throws -> Int {
        await AutofillRunner.fill(web, payload: autofillPayload(Fixtures.profile, selectors: selectors))
    }

    func value(_ selector: String) async throws -> String {
        (try await web.evaluateJavaScript("document.querySelector('\(selector)').value") as? String) ?? "<nil>"
    }

    func number(_ expression: String) async throws -> Int {
        (try await web.evaluateJavaScript("(\(expression)) || 0") as? NSNumber)?.intValue ?? -1
    }
}

@MainActor
@Suite(.serialized) struct AutofillScriptTests {
    @Test func plainNamedInputs() async throws {
        let page = TestPage()
        await page.load(#"<form><input name="fname"><input name="lname"><input name="email"><input name="zip"></form>"#)
        #expect(try await page.fill() == 4)
        #expect(try await page.value("[name=fname]") == "Jane")
        #expect(try await page.value("[name=lname]") == "Doe")
        #expect(try await page.value("[name=email]") == "jane@example.com")
        #expect(try await page.value("[name=zip]") == "78701")
    }

    @Test func autocompleteAttributesWin() async throws {
        let page = TestPage()
        await page.load(#"<input name="a1" autocomplete="given-name"><input name="a2" autocomplete="family-name"><input name="a3" autocomplete="postal-code">"#)
        #expect(try await page.fill() == 3)
        #expect(try await page.value("[name=a2]") == "Doe")
    }

    @Test func labelOnlyFields() async throws {
        let page = TestPage()
        await page.load(#"<label for="x">First Name</label><input id="x"><label for="y">Last name</label><input id="y"><label>City <input id="c"></label>"#)
        #expect(try await page.fill() == 3)
        #expect(try await page.value("#x") == "Jane")
        #expect(try await page.value("#c") == "Austin")
    }

    @Test func singleFullNameField() async throws {
        let page = TestPage()
        await page.load(#"<label>Full name <input id="n"></label><input type="email" id="e">"#)
        #expect(try await page.fill() == 2)
        #expect(try await page.value("#n") == "Jane Q Doe")
        #expect(try await page.value("#e") == "jane@example.com")
    }

    @Test func emailAddressIsNotAStreetAddress() async throws {
        let page = TestPage()
        await page.load(#"<label for="m">Email address</label><input id="m"><label for="s">Street address</label><input id="s">"#)
        try await page.fill()
        #expect(try await page.value("#m") == "jane@example.com")
        #expect(try await page.value("#s") == "22 New St")
    }

    @Test func stateSelectByCodeOrName() async throws {
        let page = TestPage()
        await page.load(#"""
        <select name="state"><option value="">--</option><option value="TN">Tennessee</option><option value="TX">Texas</option></select>
        <select id="s2" name="region"><option value="">Pick</option><option value="texas">Texas</option></select>
        """#)
        #expect(try await page.fill() == 2)
        #expect(try await page.value("[name=state]") == "TX")
        #expect(try await page.value("#s2") == "texas")
    }

    @Test func leavesTypedAndSensitiveFieldsAndNeverSubmits() async throws {
        let page = TestPage()
        await page.load(#"""
        <form onsubmit="window.submitted=(window.submitted||0)+1;return false">
          <input name="email" value="keep@x.com"><input type="password" name="first">
          <input type="hidden" name="last"><input type="checkbox" name="zip"><input name="city" disabled>
          <button type="submit">Go</button>
        </form>
        """#)
        #expect(try await page.fill() == 0)
        #expect(try await page.value("[name=email]") == "keep@x.com")
        #expect(try await page.value("[name=first]") == "")
        #expect(try await page.number("window.submitted") == 0)
    }

    @Test func controlledInputsGetEvents() async throws {
        let page = TestPage()
        await page.load(#"""
        <input id="r" name="firstName">
        <script>
          const el = document.getElementById('r');
          window.events = 0; el.addEventListener('input', () => window.events++);
          window.changes = 0; el.addEventListener('change', () => window.changes++);
        </script>
        """#)
        #expect(try await page.fill() == 1)
        #expect(try await page.value("#r") == "Jane")
        #expect(try await page.number("window.events") == 1)
        #expect(try await page.number("window.changes") == 1)
    }

    @Test func siteSearchBoxesAreLeftAlone() async throws {
        let page = TestPage()
        await page.load(#"""
        <header><input id="hdr" placeholder="Enter name, phone or address"></header>
        <form role="search"><input id="q" name="name"></form>
        <input id="s" type="search" name="city">
        <form><label for="em">Email</label><input id="em"></form>
        """#)
        #expect(try await page.fill() == 1)
        #expect(try await page.value("#hdr") == "")
        #expect(try await page.value("#q") == "")
        #expect(try await page.value("#s") == "")
        #expect(try await page.value("#em") == "jane@example.com")
    }

    @Test func fieldsInsideHiddenSectionsAreSkipped() async throws {
        let page = TestPage()
        await page.load(#"""
        <div style="display:none"><input id="h1" name="email"><input id="h2" name="fname"></div>
        <div hidden><input id="h3" name="zip"></div>
        <input id="v" name="lname">
        """#)
        #expect(try await page.fill() == 1)
        #expect(try await page.value("#h1") == "")
        #expect(try await page.value("#v") == "Doe")
    }

    @Test func pageScriptsCantReadTheFillValues() async throws {
        let page = TestPage()
        await page.load(#"""
        <input id="em" name="email">
        <script>
          window.leaked = 0;
          Object.defineProperty(window, "unlistFill", { set(fn) { window.leaked++; }, get() { return undefined; } });
          const desc = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value");
          Object.defineProperty(HTMLInputElement.prototype, "value", {
            set(v) { window.leaked++; desc.set.call(this, v); }, get() { return desc.get.call(this); }
          });
        </script>
        """#)
        #expect(try await page.fill() == 1)
        #expect(try await page.value("#em") == "jane@example.com")
        #expect(try await page.number("window.leaked") == 0)
    }

    @Test func honeypotFieldsAreSkipped() async throws {
        let page = TestPage()
        await page.load(#"""
        <input id="a" name="email" style="opacity:0">
        <input id="b" name="email" style="position:absolute;left:-9999px">
        <input id="c" name="email" aria-hidden="true">
        <input id="d" name="email" tabindex="-1">
        <input id="e" name="email" style="width:0;height:0;border:0;padding:0">
        <input id="ok" name="email">
        """#)
        #expect(try await page.fill() == 1)
        #expect(try await page.value("#ok") == "jane@example.com")
        #expect(try await page.value("#a") == "")
    }

    @Test func addressLineTwoIsLeftEmpty() async throws {
        let page = TestPage()
        await page.load(#"<label for="a1">Address line 1</label><input id="a1"><label for="a2">Address line 2</label><input id="a2"><input id="a3" name="address_2">"#)
        #expect(try await page.fill() == 1)
        #expect(try await page.value("#a1") == "22 New St")
        #expect(try await page.value("#a2") == "")
        #expect(try await page.value("#a3") == "")
    }

    @Test func perBrokerSelectorWins() async throws {
        let page = TestPage()
        await page.load(#"<input id="weird-id"><input name="email">"#)
        #expect(try await page.fill(selectors: [.email: "#weird-id"]) == 1)
        #expect(try await page.value("#weird-id") == "jane@example.com")
        #expect(try await page.value("[name=email]") == "")
    }
}
