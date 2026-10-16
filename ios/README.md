# Unlist for iPhone

Native SwiftUI app (iOS 17+). Everything is stored on the phone; nothing is
sent anywhere.

## Requirements

- Xcode 27 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen` on your PATH)

## Run

```bash
cd ios
xcodegen generate
open Unlist.xcodeproj
```

`project.yml` is the source of truth — don't edit `Unlist.xcodeproj` (it's
generated and gitignored). The broker list is the repo's root `brokers.json`,
bundled at build time.

## Test

```bash
ios/Scripts/test.sh
```

## App icon

`Unlist/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is drawn by a
script, so it can be changed and regenerated:

```bash
swift ios/Scripts/make-icon.swift
```

## Faster search: links, groups and Fill

Optional fields in the root `brokers.json` (the web app ignores them):

- `searchTemplate` — a results URL with placeholders filled from the
  profile, so **Find me** opens the owner's results directly. Placeholders:
  `{first}`, `{last}`, `{middle}`, `{city}`, `{state}`, `{stateName}`, `{zip}`.
  Add `:slug` for `jane-doe` style or `:Slug` for `Jane-Doe` style; without a
  modifier the value is URL-encoded. Only add a template after checking it on
  the live site; invalid ones are dropped at load.
- `group` — brokers sharing one opt-out (e.g. `peopleconnect`). The broker
  page says so and offers to update every site in the group.
- `autofill` — CSS selectors for fields the generic Fill misses, keyed by
  `fullName`, `firstName`, `lastName`, `email`, `phone`, `street`, `city`,
  `state`, `zip`.

Broker pages open in a private in-app browser. **Fill my details** runs
`Unlist/Resources/autofill.js`: it fills empty, visible fields it recognises,
skips the site's own search box and ambiguous fields, and never submits or
touches a CAPTCHA.

## How data is stored

Everything lives in the app's private storage on the phone
(`Application Support/Unlist/data.json`, same format as the web app's file,
with a `.bak` copy). Nothing is sent anywhere. If the file can't be read, the
app offers to restore the backup and keeps the unreadable file next to it.

Recheck reminders are local notifications at 9:00 on the recheck date.

## Publishing to the App Store (owner)

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. In `project.yml`, set your team (`DEVELOPMENT_TEAM`) and final bundle id
   (`PRODUCT_BUNDLE_IDENTIFIER`, currently `com.unlist.app`), then run
   `xcodegen generate`.
3. Create the app in App Store Connect. Privacy: **Data Not Collected**.
   Add a privacy policy URL.
4. In Xcode: Product → Archive → Distribute App → App Store Connect.
5. Add screenshots and a description, then submit for review.
