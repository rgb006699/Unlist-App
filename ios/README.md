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
