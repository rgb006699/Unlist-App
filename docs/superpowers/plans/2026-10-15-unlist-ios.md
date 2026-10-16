# Unlist for iPhone Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the native iPhone app "Unlist": the web app's features with all data on the phone, plus local recheck reminders and an app icon.

**Architecture:** XcodeGen project in `ios/`. `Unlist/Core` is a UI-free Swift port of the web `shared/` + store code, tested case for case against the web tests. One `@MainActor @Observable AppModel` owns the data file and drives the SwiftUI screens in `Unlist/Features`. Reminders go through a `ReminderScheduler` protocol so they can be tested with a fake.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, iOS 17+, Foundation, UserNotifications, MessageUI, Swift Testing, XcodeGen (`~/.local/bin/xcodegen`).

**Spec:** `docs/superpowers/specs/2026-10-15-unlist-ios-design.md` (web rules: `docs/superpowers/specs/2026-10-15-unlist-design.md`)

## Global Constraints

- Display name `Unlist`; bundle id `com.unlist.app`; iPhone only (`TARGETED_DEVICE_FAMILY = 1`); `IPHONEOS_DEPLOYMENT_TARGET = 17.0`; `SWIFT_VERSION = 6.0` with strict concurrency.
- `ios/project.yml` is the source of truth. Never edit `Unlist.xcodeproj`; it is gitignored. Run `~/.local/bin/xcodegen generate` (in `ios/`) after adding files or settings. Info.plist keys as `INFOPLIST_KEY_*` build settings.
- `Unlist/Core` must not import SwiftUI or UIKit.
- `@Observable` only (no `ObservableObject`/Combine). No third-party packages.
- Data file JSON is byte-compatible in shape with the web `data.json`: same keys, `null` for empty dates, `version: 1`, `settings.recheckDays` default `90`, history status may be `"rechecked"`.
- Dates are ISO `YYYY-MM-DD` strings in **local** time; never derive them from UTC.
- Status labels, help text, `nextStep` text, template subject/body text: identical to the web (`web/labels.ts`, `shared/templates.ts`).
- Brokers come from repo-root `brokers.json`, bundled as a resource (no copy committed under `ios/`).
- The app makes no network requests. Links open in Safari only on tap.
- Test command: `xcodebuild test -project ios/Unlist.xcodeproj -scheme Unlist -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -quiet` → `** TEST SUCCEEDED **`.

## Review Focus

1. **Web-format compatibility** — a `data.json` written by the web app (with `"rechecked"` history and `null` dates) must decode, and an encode → decode round trip must keep orphan records. Pinned in Task 2 and Task 6.
2. **Local "today" late at night** — `todayISO` at 23:30 local is still that date. Pinned in Task 2.
3. **Reminder in the past** — a `recheckAt` earlier than now must not schedule a notification (the in-app due list covers it), and leaving `removed` must cancel. Pinned in Task 7.
4. **Unreadable file never overwritten** — corrupt or missing-with-backup data must block saves until restore, and restore must refuse on readable data. Pinned in Task 6 and Task 8.
5. **Large Dynamic Type** — tiles, rows and buttons must not truncate their meaning at accessibility text sizes. Checked by hand in Task 13.

---

### Task 1: Project scaffold

**Files:**
- Create: `ios/project.yml`, `ios/Unlist/App/UnlistApp.swift`, `ios/Unlist/Resources/Assets.xcassets/{Contents.json,AccentColor.colorset/Contents.json,AppIcon.appiconset/Contents.json}`, `ios/UnlistTests/SanityTests.swift`, `ios/README.md`
- Modify: `.gitignore` (add `ios/Unlist.xcodeproj/`, `ios/build/`, `xcuserdata/`)

**Interfaces:**
- Produces: target `Unlist` (app) and `UnlistTests` (unit tests hosted by the app); scheme `Unlist`; `brokers.json` in the app bundle.

- [ ] **Step 1:** `project.yml`: name `Unlist`, `options.bundleIdPrefix: com.unlist`, deployment iOS 17.0. Target `Unlist`: sources `Unlist` plus `- path: ../brokers.json, buildPhase: resources`; settings `PRODUCT_BUNDLE_IDENTIFIER: com.unlist.app`, `INFOPLIST_KEY_CFBundleDisplayName: Unlist`, `GENERATE_INFOPLIST_FILE: YES`, `INFOPLIST_KEY_UILaunchScreen_Generation: YES`, `INFOPLIST_KEY_UISupportedInterfaceOrientations: UIInterfaceOrientationPortrait`, `TARGETED_DEVICE_FAMILY: 1`, `SWIFT_VERSION: 6.0`, `SWIFT_STRICT_CONCURRENCY: complete`, `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`. Target `UnlistTests`: `bundle.unit-test`, sources `UnlistTests`, dependency `Unlist`. Scheme `Unlist` with test target.
- [ ] **Step 2:** AccentColor `#16684A` light / `#4CBF8E` dark. AppIcon set: single 1024 universal entry (image added in Task 12).
- [ ] **Step 3:** `UnlistApp` shows `Text("Unlist")`. `SanityTests`: `@Test func bundleHasBrokers() { #expect(Bundle.main.url(forResource: "brokers", withExtension: "json") != nil) }`.
- [ ] **Step 4:** `xcodegen generate`; run the test command → `** TEST SUCCEEDED **`.
- [ ] **Step 5:** `ios/README.md`: requirements (Xcode 27, xcodegen), `cd ios && xcodegen generate && open Unlist.xcodeproj`, test command.
- [ ] **Step 6: Commit** `chore(ios): scaffold Unlist iPhone app`

### Task 2: Models and status rules

**Files:** Create `ios/Unlist/Core/Models.swift`, `ios/Unlist/Core/Status.swift`, `ios/UnlistTests/StatusTests.swift`, `ios/UnlistTests/ModelsTests.swift`. Delete `SanityTests.swift` (the bundle check moves into `BrokerListTests` in Task 3).

**Interfaces — Produces:**
- `enum Method: String, Codable, CaseIterable { case webForm = "web_form", email, phone, mail, idUpload = "id_upload" }`
- `enum RelistRisk: String, Codable { case low, medium, high }`
- `enum Status: String, Codable, CaseIterable { case found, requestSent = "request_sent", removed, relisted }`
- `enum ViewStatus: String, CaseIterable { case notChecked = "not_checked", found, requestSent = "request_sent", removed, relisted, due }`
- `enum HistoryStatus: Codable, Equatable { case status(Status), rechecked }` (encodes as the raw string)
- `struct Broker: Codable, Identifiable, Hashable` (fields as web; `optOutEmail: String?`, `steps: [String]`, `lastVerified: String`)
- `struct Address: Codable, Hashable { var street, city, state, zip: String; var current: Bool }`
- `struct Profile: Codable, Equatable { var fullName: String; var aliases: [String]; var addresses: [Address]; var phones: [String]; var emails: [String]; static let empty }`
- `struct HistoryEntry: Codable, Equatable { let at: String; let status: HistoryStatus }`
- `struct BrokerRecord: Codable, Equatable { var status: Status; var listingUrl: String; var notes: String; var requestSentAt, removedAt, recheckAt: String?; var history: [HistoryEntry] }` — encodes `nil` dates as JSON `null` (custom `encode(to:)` with `encodeNil`).
- `struct DataFile: Codable, Equatable { var version = 1; var profile: Profile; var settings: Settings; var records: [String: BrokerRecord]; static func empty() -> DataFile }`, `struct Settings: Codable, Equatable { var recheckDays = 90 }`
- `struct Progress: Equatable { let total, removed, pending, due, notChecked: Int }`
- `func todayISO(_ now: Date = .now, calendar: Calendar = .current) -> String`
- `func addDays(_ iso: String, _ days: Int) -> String`
- `func applyStatus(_ rec: BrokerRecord?, _ status: Status, today: String, recheckDays: Int) -> BrokerRecord`
- `func markStillRemoved(_ rec: BrokerRecord, today: String, recheckDays: Int) -> BrokerRecord`
- `func viewStatus(_ rec: BrokerRecord?, today: String) -> ViewStatus`
- `func progress(_ statuses: [ViewStatus]) -> Progress`

- [ ] **Step 1: Failing tests** — port every case of `shared/status.test.ts` (dates incl. 23:30 local, padding, `2026-10-15`+90 = `2027-01-13`, Feb 28 + 1; applyStatus each status, recheck cleared when not removed, history append, input unchanged; markStillRemoved; viewStatus incl. due on/after recheck; progress counts). `ModelsTests`: decoding this exact web JSON succeeds and round-trips to an equal value:
  `{"version":1,"profile":{"fullName":"Jane","aliases":[],"addresses":[{"street":"1 Main","city":"Austin","state":"TX","zip":"78701","current":true}],"phones":[],"emails":[]},"settings":{"recheckDays":90},"records":{"spokeo":{"status":"removed","listingUrl":"","notes":"","requestSentAt":null,"removedAt":"2026-10-01","recheckAt":"2026-12-30","history":[{"at":"2026-10-01","status":"removed"},{"at":"2026-12-30","status":"rechecked"}]}}}`
  and encoding a record with nil dates produces `"requestSentAt":null`.
- [ ] **Step 2:** Run tests → FAIL (types missing).
- [ ] **Step 3:** Implement. Date math via `DateComponents`/`Calendar(identifier: .gregorian)` in the current time zone; format with zero padding.
- [ ] **Step 4:** Run tests → PASS.
- [ ] **Step 5: Commit** `feat(ios): models and status rules`

### Task 3: Merge and broker list

**Files:** Create `ios/Unlist/Core/Merge.swift`, `ios/Unlist/Core/BrokerList.swift`, `ios/UnlistTests/MergeTests.swift`, `ios/UnlistTests/BrokerListTests.swift`

**Interfaces — Produces:**
- `struct BrokerRow: Identifiable, Equatable { let broker: Broker; let record: BrokerRecord?; let view: ViewStatus; let nextDate: String?; var id: String { broker.id } }`
- `func mergeBrokers(_ brokers: [Broker], _ records: [String: BrokerRecord], today: String) -> [BrokerRow]`
- `enum BrokerList { static func load(from data: Data, log: (String) -> Void = { _ in }) -> [Broker]; static func bundled() -> [Broker] }` — decodes the array element by element (`[JSONValue]`-free: decode `[AnyBroker]` where `AnyBroker` wraps `try? Broker`), skips invalid entries, duplicate ids, `method == .email` without `optOutEmail`.

- [ ] **Step 1: Failing tests** — port `shared/merge.test.ts` (order, nextDate per status, orphan produces no row, progress over rows) and `server/app.test.ts`'s loadBrokers case (invalid + duplicate skipped, two log lines). Plus: `BrokerList.bundled()` has ≥ 35 brokers with unique ids and https URLs.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): merge records with the bundled broker list`

### Task 4: Dates and labels

**Files:** Create `ios/Unlist/Core/Dates.swift`, `ios/Unlist/Core/Labels.swift`, `ios/UnlistTests/DatesLabelsTests.swift`

**Interfaces — Produces:** `func formatDate(_ iso: String) -> String`; `func relativeDays(_ iso: String, today: String) -> String`; `extension ViewStatus { var label: String; var help: String; var symbol: String }`; `extension Status { var label: String }`; `extension Method { var label: String; var symbol: String }`; `func nextStep(_ row: BrokerRow) -> String` (uses `BrokerRow` from Task 3).

SF Symbols: notChecked `circle`, found `eye`, requestSent `paperplane`, removed `checkmark.circle`, relisted `exclamationmark.triangle`, due `clock`; webForm `globe`, email `envelope`, phone `phone`, mail `mail.stack`, idUpload `person.text.rectangle`.

- [ ] **Step 1: Failing tests** — port `web/format.test.ts` exactly (all nine `relativeDays` cases, both `formatDate` cases, `nextStep` six statuses, every help ≥ 10 chars).
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement with month names array (no `DateFormatter`, so output is locale-independent and matches the web). **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): readable dates and status labels`

### Task 5: Request templates

**Files:** Create `ios/Unlist/Core/Templates.swift`, `ios/UnlistTests/TemplatesTests.swift`

**Interfaces — Produces:** `enum TemplateID: String, CaseIterable { case tdpsa, general }` with `label` ("Texas (TDPSA)", "General"); `func fillTemplate(_ id: TemplateID, profile: Profile, broker: Broker, listingUrl: String) -> (subject: String, body: String)`; `func mailtoURL(to: String?, subject: String, body: String) -> URL`.

- [ ] **Step 1: Failing tests** — port all 14 cases of `shared/templates.test.ts` with the same fixtures and exact subject strings; mailto round-trips `Hi & bye` and `Line 1\nO'Brien #2` via `URLComponents`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement — copy the web wording verbatim; percent-encode with `.urlQueryAllowed` minus `&+=?#`. **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): TDPSA and general request templates`

### Task 6: Data store

**Files:** Create `ios/Unlist/Core/Store.swift`, `ios/UnlistTests/StoreTests.swift`

**Interfaces — Produces:**
- `enum StoreError: Error, Equatable { case corrupt(String), nothingToRestore, noBackup }`
- `struct DataStore: Sendable { init(directory: URL); func load() throws -> DataFile; func save(_ data: DataFile) throws; func restore() throws -> DataFile; static func appDefault() -> DataStore }` (directory `Application Support/Unlist`, created on first use, file protection `.completeUntilFirstUserAuthentication`)

- [ ] **Step 1: Failing tests** — port all 11 `server/store.test.ts` cases except concurrency (single-actor app): first load creates empty file; save keeps `.bak`, no `.tmp` left; bad JSON → `.corrupt` and file unchanged; schema-invalid (`{"version":2}`) → corrupt; restore copies backup and keeps `data.json.corrupt-*`; restore without backup → `.noBackup`; missing file with backup → corrupt and backup intact; restore on readable data → `.nothingToRestore`. Plus: encode → decode keeps an orphan record key.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement with `FileManager` (`replaceItemAt` for the swap; `.bak` via copy before replace). Decode failure or `version != 1` → `.corrupt`. **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): on-device data store with backup and restore`

### Task 7: Reminders

**Files:** Create `ios/Unlist/Core/Reminders.swift`, `ios/UnlistTests/RemindersTests.swift`

**Interfaces — Produces:**
- `struct Reminder: Equatable, Sendable { let id: String; let brokerId: String; let title: String; let body: String; let fireDate: DateComponents }`
- `protocol ReminderScheduler: Sendable { func requestPermissionIfNeeded() async -> Bool; func replaceAll(with reminders: [Reminder]) async }`
- `func reminders(for rows: [BrokerRow], now: Date = .now, calendar: Calendar = .current) -> [Reminder]` — one per row with `view == .removed` and `recheckAt` whose 09:00 local is after `now`; id `recheck-<brokerId>`; title `Time to recheck <name>`; body `Search again to make sure your listing hasn't come back.`
- `final class NotificationScheduler: ReminderScheduler` (UNUserNotificationCenter; removes pending `recheck-*` then adds; `userInfo["brokerId"]`)

- [ ] **Step 1: Failing tests** — removed row with future recheck → one reminder with id, title, body, fireDate `{y,m,d, hour: 9, minute: 0}`; recheck today at 08:00 now → scheduled, at 10:00 now → not; due/found/relisted rows → none.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): recheck reminder scheduling`

### Task 8: App model

**Files:** Create `ios/Unlist/App/AppModel.swift`, `ios/UnlistTests/AppModelTests.swift`

**Interfaces — Consumes:** Tasks 2–7 (rows from Task 3, labels from Task 4). **Produces:**
- `@MainActor @Observable final class AppModel { init(store: DataStore, brokers: [Broker], scheduler: ReminderScheduler, today: @escaping () -> String = { todayISO() }) }`
- State: `private(set) var data: DataFile?`, `private(set) var loadError: StoreError?`, `var rows: [BrokerRow]`, `var progress: Progress`, `var today: String`, `var openBrokerId: String?` (notification deep link)
- `func load()`; `func setStatus(_ id: String, _ status: Status)`; `func markStillRemoved(_ id: String)`; `func updateNotes(_ id: String, _ notes: String)`; `func updateListingUrl(_ id: String, _ url: String)`; `func saveProfile(_ p: Profile) throws`; `func restore()`
- Same rules as the web PATCH: same status twice → no history entry; notes/URL on a not-checked broker creates a `found` record; `markStillRemoved` only when removed. Every successful save calls `scheduler.replaceAll(with: reminders(for: rows))`, requesting permission first when there is at least one reminder. Saves are refused while `loadError != nil`.

- [ ] **Step 1: Failing tests** (temp dir store, fake scheduler recording calls, fixed `today`): fresh load with a 3-broker fixture → 3 rows, all notChecked; setStatus removed → persisted, recheck `2027-01-13`, fake receives one reminder; setStatus found after removed → fake receives none; same status twice → history 1; notes on not-checked → found; corrupt file → `loadError == .corrupt`, `setStatus` does not write; restore → loads backup; orphan record survives a save.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement. **Step 4:** Run → PASS.
- [ ] **Step 5: Commit** `feat(ios): app model tying store, rules and reminders`

### Task 9: Root, dashboard

**Files:** Create `ios/Unlist/App/RootView.swift`, `ios/Unlist/Features/Dashboard/DashboardView.swift`, `ios/Unlist/Features/Shared/StatusPill.swift`, `ios/Unlist/Features/Shared/DataErrorView.swift`; modify `UnlistApp.swift`.

**Interfaces — Consumes:** `AppModel`, labels. **Produces:** `RootView` (`TabView`: Dashboard `square.grid.2x2`, Profile `person.crop.circle`; opens Profile tab first when `profile.fullName` is empty; shows `DataErrorView` with "Restore from backup" when `loadError` is set); `StatusPill(status: ViewStatus)`.

- [ ] **Step 1:** Dashboard per spec: headline + `ProgressView`-style capsule bar, 2×2 tiles (`Grid`) as toggle buttons with `accessibilityLabel("<n> <label>")` and `.isSelected` trait, "How Unlist works" card while nothing started, "Due for recheck" section (Search again → `openURL`, Still removed, Re-listed), `.searchable` list of `NavigationLink(value: broker.id)` rows (name, method symbol + label, `StatusPill`, `nextStep`). `navigationDestination(for: String.self)` → BrokerDetail placeholder. Filtering logic lives in a pure `func filterRows(_ rows: [BrokerRow], group: TileGroup?, query: String) -> [BrokerRow]` in `Core/Labels.swift`.
- [ ] **Step 2: Failing test then implement** `filterRows` (port the dashboard tile/search test cases).
- [ ] **Step 3:** `xcodegen generate`; build; run in Simulator; screenshot light and dark.
- [ ] **Step 4: Commit** `feat(ios): dashboard`

### Task 10: Broker detail and request

**Files:** Create `ios/Unlist/Features/Broker/BrokerDetailView.swift`, `RequestSection.swift`, `MailComposer.swift`

- [ ] **Step 1:** `Form`/`List` sections per spec: header (name, pill, method, risk, verification, badges, Open search page / Open opt-out page buttons), Your progress (status `Picker` bound through `model.setStatus`, help text with `info.circle`, dates with relative time, listing URL `TextField` `.keyboardType(.URL)` `.textContentType(.URL)` saved on submit/focus loss, notes `TextField(axis: .vertical)` saved on focus loss), How to opt out (numbered), Removal request (segmented `Picker`, subject, body in a rounded box, buttons Email / Copy / `ShareLink`), History newest first. Notification-denied note when the status is removed and permission is off.
- [ ] **Step 2:** `MailComposer`: `UIViewControllerRepresentable` around `MFMailComposeViewController` (recipient `optOutEmail`); when `canSendMail()` is false use `openURL(mailtoURL(...))`; if that fails, show "Copy the request instead" alert. Copy uses `UIPasteboard.general.string` and shows a checkmark for 2 s.
- [ ] **Step 3:** Run in Simulator: change statuses, notes persist after relaunch, Copy/Share sheets appear.
- [ ] **Step 4: Commit** `feat(ios): broker detail and removal request`

### Task 11: Profile

**Files:** Create `ios/Unlist/Features/Profile/ProfileView.swift`; add `func cleanProfile(_ p: Profile) -> Profile` to `Core/Models.swift` with tests in `ModelsTests` (port the web Profile save-cleaning cases: trims, drops empty rows, drops state-only address).

- [ ] **Step 1: Failing test** for `cleanProfile`; implement; pass.
- [ ] **Step 2:** `Form` sections: Your details (name `.textContentType(.name)`, other names with add/delete), Addresses (street `.streetAddressLine1`, city `.addressCity`, state default "TX" `.addressState`, ZIP `.postalCode` numeric keyboard, "Current address" `Toggle` that clears the others), Contact (phones `.telephoneNumber` phone pad, emails `.emailAddress`). Toolbar Save (disabled when unchanged). Intro footer: "Saved only on this iPhone." Leaving the tab with unsaved changes shows a confirmation dialog (Save / Discard).
- [ ] **Step 3:** Run in Simulator; save, relaunch, values persist.
- [ ] **Step 4: Commit** `feat(ios): profile form`

### Task 12: App icon and notification deep link

**Files:** Create `ios/Scripts/make-icon.swift`, `ios/Unlist/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`; create `ios/Unlist/App/NotificationDelegate.swift`; modify `UnlistApp.swift`, `AppIcon.appiconset/Contents.json`.

- [ ] **Step 1:** `make-icon.swift` (run with `swift ios/Scripts/make-icon.swift <out.png>`): CoreGraphics 1024×1024, opaque, vertical gradient `#1C7A57` → `#11553C`, centered white shield (≈ 56% width) built from a path with a rounded top and pointed bottom, a green check mark (`#16684A`, round caps, stroke ≈ 7% width) inside. Output PNG; verify with `sips -g pixelWidth -g hasAlpha` → 1024, `hasAlpha: no`.
- [ ] **Step 2:** Reference the PNG in Contents.json (`idiom: universal, platform: ios, size: 1024x1024`). Build; check the icon on the Simulator home screen.
- [ ] **Step 3:** `NotificationDelegate` (UNUserNotificationCenterDelegate): on tap, set `model.openBrokerId = userInfo["brokerId"]`; RootView switches to Dashboard and pushes that broker. Foreground presentation shows banners.
- [ ] **Step 4: Commit** `feat(ios): app icon and reminder deep link`

### Task 13: Verification and docs

- [ ] **Step 1:** Full test command → `** TEST SUCCEEDED **`; `xcodebuild build` for `generic/platform=iOS Simulator` with no warnings in `Unlist/`.
- [ ] **Step 2:** Simulator walk-through: first launch → Profile; fill profile; dashboard tiles; mark Spokeo removed (permission prompt appears); set the data file's `recheckAt` to today (via `xcrun simctl get_app_container`) and relaunch → Due panel; Still removed; notes persist across relaunch; light, dark, and the largest accessibility text size (no clipped labels in tiles/rows/buttons).
- [ ] **Step 3:** Corrupt the data file in the container → error view → Restore works.
- [ ] **Step 4:** Update `ios/README.md` (run, test, regenerate icon) and root `README.md` (iPhone section + App Store checklist from the spec).
- [ ] **Step 5: Commit** `docs(ios): README and verification fixes`; push.
