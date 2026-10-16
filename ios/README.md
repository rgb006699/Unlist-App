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
