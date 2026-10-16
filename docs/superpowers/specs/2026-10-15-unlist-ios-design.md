# Unlist for iPhone — Design Spec

Date: 2026-10-15
Builds on: `docs/superpowers/specs/2026-10-15-unlist-design.md` (web app)

## Goal

A native iPhone app named **Unlist** that anyone can download and use on their
own: track data broker listings, generate removal requests, and get reminded
to recheck. It does everything the web app does, with all data on the phone,
plus local recheck notifications. The web app stays as it is.

Success: a new user installs Unlist, fills in their details, works through the
broker list using per-broker steps and a ready-to-send email, and gets a
phone notification when a removal is due for recheck — with no account,
server or network service involved.

## Decisions

| Topic | Decision |
| --- | --- |
| Approach | Native SwiftUI app (not a web wrapper). |
| Location | `ios/` folder in the Unlist-App repo. |
| Project | XcodeGen `ios/project.yml` → `Unlist.xcodeproj` (never hand-edited, gitignored). |
| Language / UI | Swift 6 (strict concurrency), SwiftUI, iOS 17+, iPhone only. |
| State | `@Observable` (no ObservableObject/Combine). |
| Storage | One JSON file on the device, same format as the web `data.json`. |
| Broker list | Repo-root `brokers.json`, copied into the app bundle at build. |
| Reminders | Local notifications (UserNotifications), no server. |
| Tests | Swift Testing (`import Testing`, `@Test`, `#expect`). |
| Dependencies | None beyond Apple frameworks. |
| Display name | `Unlist`; bundle id `com.unlist.app` (placeholder until the owner's Apple team is set). |

## Out of scope (for now)

- App Store submission itself (needs the owner's Apple Developer account,
  signing team and App Store Connect listing). The app is made ready for it.
- iCloud sync, iPad-specific layout, widgets, importing a web `data.json`.
- Automated scanning of broker sites.

## Structure

```
ios/
  project.yml
  Unlist/
    App/          UnlistApp (entry), RootView (tabs), AppModel (@Observable)
    Core/         Models, Status, Dates, Templates, Merge, Store, Reminders (no UI)
    Features/
      Dashboard/  DashboardView, tiles, due panel, broker list
      Broker/     BrokerDetailView, RequestView, MailComposer
      Profile/    ProfileView
    Resources/    Assets.xcassets (AppIcon, AccentColor), brokers.json (build copy)
  UnlistTests/    Swift Testing, one file per Core unit
```

`Core` has no SwiftUI imports, so it is unit-testable. It is a direct port of
the web `shared/` code, and its tests mirror the web tests case for case, so
both apps follow the same rules.

## Core units

| Unit | Responsibility | Mirrors |
| --- | --- | --- |
| `Models.swift` | `Broker`, `Profile`, `Address`, `BrokerRecord`, `HistoryEntry`, `DataFile`, `Status`, `ViewStatus`, `Method`, `RelistRisk` — `Codable`, JSON keys identical to the web | `shared/types.ts`, `schema.ts` |
| `Status.swift` | `applyStatus`, `markStillRemoved`, `viewStatus`, `progress`, `todayISO`, `addDays` | `shared/status.ts` |
| `Dates.swift` | `formatDate` ("Oct 15, 2026"), `relativeDays` ("in 3 months") | `web/format.ts` |
| `Labels.swift` | status labels, plain-language help, `nextStep` | `web/labels.ts` |
| `Templates.swift` | TDPSA and general request text, `mailtoURL` | `shared/templates.ts` |
| `Merge.swift` | `BrokerRow`, `mergeBrokers` (orphan records kept on disk, not shown) | `shared/merge.ts` |
| `Store.swift` | load / atomic save / `.bak` / restore of the data file | `server/store.ts` |
| `BrokerList.swift` | load bundled `brokers.json`, skipping invalid or duplicate entries | `server/brokers.ts` |
| `Reminders.swift` | compute and schedule recheck notifications | new |

Dates stay ISO `YYYY-MM-DD` strings in **local** time, as in the web app.

## Data on the phone

- File: `Application Support/Unlist/data.json`, backup `data.json.bak`,
  temp `data.json.tmp`. It is included in the user's normal
  encrypted device backup.
- File protection: `.completeUntilFirstUserAuthentication`.
- Writes are atomic (write temp → copy current to `.bak` → replace).
- Missing file with no backup → start empty. Missing file with a backup, or an
  unreadable file → the app shows "Your data couldn't be read" with
  **Restore from backup**, which keeps the unreadable file as
  `data.json.corrupt-<time>`. Restore refuses when the file is readable.
- All saves go through one `@MainActor` model, so there are no concurrent writes.
- No analytics, accounts or network calls. Broker pages open in Safari only
  when the user taps a link.

## Screens

Tab bar with **Dashboard** and **Profile**. First launch with an empty profile
opens Profile with a short welcome line.

1. **Dashboard** (`NavigationStack`)
   - Headline "N of M sites have removed you" and a progress bar.
   - Four tiles: Removed, In progress, Need recheck, Not checked yet. Tapping
     one filters the list; tapping again clears it.
   - "How Unlist works" card while nothing is started.
   - "Due for recheck" section: Search again (opens Safari), Still removed,
     Re-listed.
   - Searchable list (`.searchable`) of brokers: name, method icon, status
     pill, next step. Tap → Broker detail.
2. **Broker detail**
   - Header: name, status pill, method, re-list risk, verification note,
     requirement badges, **Open search page** / **Open opt-out page**.
   - Your progress: status `Picker`, plain-language help, dates with relative
     time, listing URL and notes (saved when editing ends).
   - How to opt out: numbered steps.
   - Removal request: template picker (Texas TDPSA / General), preview,
     **Email** (in-app Mail composer when available, else `mailto:`),
     **Copy**, **Share**. The app never sends anything itself.
   - History, newest first.
3. **Profile** (`Form`)
   - Full name, other names, addresses (street, city, state default TX, ZIP,
     current toggle — one current at most), phones, emails.
   - Standard iOS text content types and keyboards.
   - Save button; leaving with unsaved changes asks first.

Design: SF Symbols, the Unlist green accent, system fonts with Dynamic Type,
light and dark mode, VoiceOver labels on icons and tiles.

## Reminders

- When a broker becomes `removed` (or is rechecked), schedule a local
  notification at 9:00 local time on its `recheckAt` date:
  title "Time to recheck <Broker>", body "Search again to make sure your
  listing hasn't come back." Identifier `recheck-<brokerId>` (rescheduling
  replaces it).
- Leaving `removed` cancels that broker's notification.
- On launch, all pending reminders are re-synced from the data file.
- Permission is requested the first time a reminder is scheduled, not at launch.
  If denied, the in-app "Due for recheck" list still works.
- Tapping a notification opens that broker's detail screen.

## App icon

1024×1024 opaque PNG in `Assets.xcassets/AppIcon` (single size; iOS rounds the
corners): deep green background (Unlist accent, subtle top-to-bottom
gradient) with a white shield and a green check mark cut into it, matching the
web logo. Generated by a script in `ios/Scripts/` so it can be regenerated.

## Error handling

- Invalid entries in `brokers.json` are skipped (and logged in debug builds).
- Unreadable data file → restore flow above; the app never overwrites it.
- Mail not configured → fall back to `mailto:`, then to Copy/Share.
- Notification permission denied → reminders silently off; a note on the
  Broker detail screen explains how to turn them on in Settings.

## Testing

- `UnlistTests` (Swift Testing): Status, Dates, Labels, Templates, Merge,
  Store (temp directory: atomic write, backup, corrupt, restore rules), and
  BrokerList, ported from the web tests with the same cases; Reminders
  (identifier, fire date 9:00 local, cancel on leaving removed) via a
  scheduler protocol and a fake.
- A test that the bundled `brokers.json` decodes with ≥ 35 valid entries.
- Build and run in the iOS Simulator; check every screen in light and dark,
  with large Dynamic Type, by hand.

## Distribution checklist (owner)

1. Join the Apple Developer Program.
2. Set the team and final bundle id in `ios/project.yml`.
3. Create the App Store Connect record; add privacy details ("Data Not
   Collected") and a privacy policy URL.
4. Archive in Xcode and upload; submit for review.
