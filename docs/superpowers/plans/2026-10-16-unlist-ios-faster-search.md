# Unlist iPhone — Faster Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One tap from a broker page to the owner's search results, a private in-app browser with a "My details" bar and a "Fill my details" button, and grouped shared opt-outs.

**Architecture:** New optional broker fields (`searchTemplate`, `group`, `autofill`) are decoded and validated in `Core`. Pure Swift builds search URLs and the autofill value map from the profile (unit-tested). A bundled `autofill.js` fills fields in a `WKWebView` sheet; it is tested by loading HTML fixtures into a real `WKWebView` inside Swift Testing. `AppModel` gains group-aware status changes.

**Tech Stack:** Swift 6, SwiftUI, WebKit (`WKWebView`, non-persistent data store), Swift Testing, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-16-unlist-ios-faster-search-design.md` (base: `docs/superpowers/specs/2026-10-15-unlist-ios-design.md`)

## Global Constraints

- iPhone app only; `web/`, `server/`, `shared/` unchanged. New `brokers.json` fields are optional and must keep `shared/brokers.test.ts` and `npm test` passing (zod `BrokerSchema` is not strict, so extra keys are allowed — verify).
- Placeholders: `{first}`, `{last}`, `{middle}`, `{city}`, `{state}`, `{stateName}`, `{zip}`; modifiers `:slug` and `:Slug` only.
- `WKWebsiteDataStore.nonPersistent()` for every broker page.
- The fill script never clicks, submits or touches CAPTCHA elements, and never overwrites a non-empty field.
- `Core` stays UI-free (no SwiftUI/UIKit/WebKit imports).
- Tests: `ios/Scripts/test.sh` → `** TEST SUCCEEDED **`; web `npm test` still green.

## Review Focus

1. **Names in URLs** — apostrophes, accents, hyphens, multiple spaces and one-word names must give a valid URL or a clean fallback. Pinned in Task 2.
2. **Missing profile fields** — a template needing `{city}` with no address falls back to `searchUrl` and says which field is missing. Pinned in Task 2.
3. **Controlled inputs** — React-style inputs must keep the filled value after the page re-renders. Pinned in Task 4.
4. **Never clobber or submit** — filled values never overwrite typed text; no form submits. Pinned in Task 4.
5. **Group status** — "Apply to all" writes a history entry and recheck date for each member and saves once. Pinned in Task 5.

---

### Task 1: Broker fields and validation

**Files:** Modify `ios/Unlist/Core/Models.swift`, `ios/Unlist/Core/BrokerList.swift`; create `ios/UnlistTests/BrokerFieldsTests.swift`.

**Interfaces — Produces:**
- `Broker` gains `let searchTemplate: String?`, `let group: String?`, `let autofill: [AutofillField: String]?`
- `enum AutofillField: String, CaseIterable, Codable, Sendable { case fullName, firstName, lastName, email, phone, street, city, state, zip }`
- Decoding: missing fields → nil; unknown `autofill` keys dropped (decode as `[String: String]`, map known keys).
- `BrokerList.load` keeps a broker but drops a bad `searchTemplate` (not `https://`, or an unknown placeholder/modifier) or bad `group` (not `^[a-z0-9-]+$`), logging `Dropping searchTemplate for <id>: …`.
- `func templatePlaceholders(_ template: String) -> [(name: String, modifier: String?)]` (used by validation and Task 2).

- [ ] **Step 1: Failing tests:** decode a broker JSON with all three fields; decode without them (nil); unknown autofill key dropped; `http://` template dropped with log; `{nickname}` and `{first:upper}` dropped; bad group `"People Connect"` dropped; broker itself still loaded in each case.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. Update `Fixtures.broker` with the new nil fields. **Step 4:** Run → PASS. Run `npm test` in repo root → PASS.
- [ ] **Step 5: Commit** `feat(ios): optional search template, group and autofill fields on brokers`

### Task 2: Search URL from the profile

**Files:** Create `ios/Unlist/Core/Search.swift`, `ios/UnlistTests/SearchTests.swift`.

**Interfaces — Produces:**
- `struct SearchValues: Equatable, Sendable { var first, last, middle, city, state, stateName, zip: String }` with `init(profile: Profile)` (name split on whitespace; current address else first).
- `let stateNames: [String: String]` (50 states + DC, code → name).
- `enum SearchLink: Equatable { case direct(URL), fallback(URL, missing: [String]) }`
- `func searchLink(for broker: Broker, profile: Profile) -> SearchLink` — `.direct` when every placeholder has a non-empty value and the result parses as a URL; otherwise `.fallback(searchUrl, missing: ["city", …])` (human words: "first name", "last name", "city", "state", "ZIP").
- `func slug(_ s: String, keepCase: Bool) -> String`

- [ ] **Step 1: Failing tests:**
  - `{first}%20{last}` with "Jane Q Doe" → `Jane%20Doe`; `{middle}` → `Q`.
  - "Mary-Kate O'Brien" `{first:slug}-{last:slug}` → `mary-kate-obrien`; `{last:Slug}` → `OBrien`.
  - "José Núñez" `{first:slug}` → `jose`; `{last}` percent-encodes to `N%C3%BA%C3%B1ez`.
  - Two spaces between names handled; one-word name with `{last}` → fallback missing `["last name"]`.
  - City "San Antonio" `{city:slug}` → `san-antonio`; `{city}` → `San%20Antonio`; `{stateName}` for TX → `Texas`.
  - No addresses + template with `{city}` → `.fallback(searchUrl, missing: ["city", "state"])` when both used.
  - Current address preferred over first; no current → first.
  - Broker without template → `.fallback(searchUrl, missing: [])`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement (query encoding: `addingPercentEncoding(withAllowedCharacters: .urlUnreserved)` where unreserved = `A-Za-z0-9-._~`; slug via `folding(options: [.diacriticInsensitive], locale: nil)`, drop `'`/`’`, replace other runs with `-`, trim `-`). **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): build direct search links from the profile`

### Task 3: Research and add templates, groups, selectors

**Files:** Modify `brokers.json`; create `ios/UnlistTests/BundledBrokerFieldsTests.swift`.

- [ ] **Step 1:** For each of the 38 brokers, find the site's search-results URL format by searching the site with a sample name in the built-in browser (or from published examples) and confirm the results page loads for a sample person (e.g. "John Smith, Austin TX"). Add `searchTemplate` only when confirmed. Record unconfirmed brokers in the ledger.
- [ ] **Step 2:** Add `"group": "peopleconnect"` to intelius, instantcheckmate, truthfinder, ussearch, zabasearch.
- [ ] **Step 3:** For the top 10 brokers by reach (spokeo, whitepages, beenverified, intelius/peopleconnect, peoplefinders, truepeoplesearch, fastpeoplesearch, radaris, mylife, nuwber), open the opt-out form, note fields generic matching would miss, and add `autofill` selectors only for those.
- [ ] **Step 4: Test:** every bundled broker's template (if any) passes Task 1 validation and builds a `.direct` URL for `Fixtures.profile`; the 5 PeopleConnect brokers share a group. `npm test` still passes.
- [ ] **Step 5: Commit** `feat: search templates, PeopleConnect group and autofill selectors in brokers.json`

### Task 4: Autofill values and fill script

**Files:** Create `ios/Unlist/Core/Autofill.swift`, `ios/Unlist/Resources/autofill.js`, `ios/UnlistTests/AutofillTests.swift`, `ios/UnlistTests/AutofillScriptTests.swift` (+ HTML fixtures as Swift string literals).

**Interfaces — Produces:**
- `func autofillValues(_ profile: Profile) -> [AutofillField: String]` (full/first/last from name split; first phone; first email; current-or-first address street/city/state/zip; empty values omitted).
- `func autofillPayload(_ profile: Profile, selectors: [AutofillField: String]?) -> String` — JSON `{"values": {...}, "selectors": {...}, "stateName": "Texas"}`.
- `autofill.js` defines `window.unlistFill(payload) -> {filled: Int}` per spec rules (selectors first; `autocomplete`; keyword match on name/id/placeholder/aria-label/label; state `select`; native value setter + `input`/`change` events; skip non-empty, hidden, disabled, password/checkbox/radio/file; full-name only when no first/last field).
- `enum AutofillScript { static let source: String }` loads `autofill.js` from the bundle.

- [ ] **Step 1: Failing tests (Swift mapping):** values for `Fixtures.profile`; empty profile → empty map; no current address → first address; payload JSON round-trips and contains the selector map.
- [ ] **Step 2: Failing tests (script, `@MainActor`, real `WKWebView` with `loadHTMLString`, then `evaluateJavaScript(AutofillScript.source + "unlistFill(\(payload))")`):**
  - Plain inputs `name=fname/lname/email/zip` → 4 filled, values correct.
  - `autocomplete=given-name/family-name/postal-code` with meaningless names → filled.
  - Label-only fields (`<label for=x>First Name</label><input id=x>`) → filled.
  - Single "Full name" field and no first/last → full name filled.
  - `<select name=state>` with options "TX"/"Texas" → Texas selected.
  - Pre-filled field left unchanged; password/hidden/checkbox untouched; form `onsubmit` counter stays 0.
  - React-style input (value setter tracked via `Object.defineProperty`, listening to `input`) receives the event.
  - Per-broker selector `#weird-id` for email wins over generic match.
- [ ] **Step 3:** Run → FAIL. **Step 4:** Implement; add `autofill.js` to the app target's resources in `project.yml` (it's under `Unlist/Resources`, already a source path — confirm it lands in the bundle). **Step 5:** Run → PASS.
- [ ] **Step 6: Commit** `feat(ios): fill-my-details script and value mapping`

### Task 5: Group-aware status changes

**Files:** Modify `ios/Unlist/App/AppModel.swift`, `ios/UnlistTests/AppModelTests.swift`.

**Interfaces — Produces:** `func groupMembers(of id: String) -> [Broker]` (empty when no group; includes the broker itself first); `func setStatus(_ id: String, _ status: Status, applyToGroup: Bool)` (existing `setStatus(_:_:)` = `applyToGroup: false`). One save and one reminder sync for the whole group.

- [ ] **Step 1: Failing tests:** 3-broker fixture with two sharing a group: apply to all → both records updated with history and recheck date, one save (check `.bak` holds the pre-change file), one reminder sync; just this one → only one record; broker without group → `groupMembers` empty.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement (refactor `mutateRecord` to accept several ids). **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): apply a status to every broker in a shared opt-out group`

### Task 6: In-app browser and wiring

**Files:** Create `ios/Unlist/Features/Browser/BrokerBrowserView.swift`, `ios/Unlist/Features/Browser/WebView.swift`, `ios/Unlist/Features/Browser/DetailsBar.swift`; modify `BrokerDetailView.swift`, `DashboardView.swift`, `AppModel.swift` (add `var openProfile = false`), `RootView.swift` (switch to the Profile tab when it's set, then reset it).

- [ ] **Step 1:** `WebView` (`UIViewRepresentable` over `WKWebView`): non-persistent data store; `WKUIDelegate.createWebViewWith` loads target-blank links in place; `WKNavigationDelegate` hands `mailto:`/`tel:` to `openURL`; publishes title, host, loading state and errors; exposes `fill(payload) async -> Int` via `evaluateJavaScript`.
- [ ] **Step 2:** `BrokerBrowserView(brokerId:, startURL:)` sheet: top bar (Done, host, reload, `ShareLink` for the current URL), web view, bottom bar: Fill my details (result message), Mark as… menu (Found it / Request sent / Removed; group dialog when grouped), and `DetailsBar` copy chips (name, other names, each address one line, phones, emails; check mark for 1.5 s). Empty profile → "Add your details in Profile first" + button that switches tab (via `model.openProfile = true` read by RootView).
- [ ] **Step 3:** BrokerDetail: "Search page" uses `searchLink` — `.direct` opens the browser at that URL; `.fallback` opens `searchUrl` and shows the missing-field hint under the buttons. "Opt-out page" opens the browser. Group banner "One opt-out covers N sites: …" in the header; status picker asks Apply to all / Just this one for grouped brokers. Dashboard due panel "Search again" opens the browser.
- [ ] **Step 4:** Build; simulator: open a broker, browser loads, chips copy, Mark as updates status and dashboard, Done returns.
- [ ] **Step 5: Commit** `feat(ios): in-app broker browser with My details and Fill`

### Task 7: Verification and docs

- [ ] **Step 1:** `ios/Scripts/test.sh` → `** TEST SUCCEEDED **`; root `npm test` → all pass; build has no warnings in `Unlist/`.
- [ ] **Step 2:** Simulator with a filled profile: for each broker with a template, "Search page" lands on a results page for that name (record any that don't; remove their template). On the top 10 opt-out forms, Fill fills the visible fields (record counts per site in the ledger).
- [ ] **Step 3:** Dark mode and largest text: browser bars and chips usable.
- [ ] **Step 4:** `ios/README.md`: how search templates, groups and autofill selectors work and how to add one.
- [ ] **Step 5: Commit** `docs(ios): faster search`; final review; push after the owner's OK.
