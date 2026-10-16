#!/bin/sh
# Runs the iOS unit tests on the iPhone simulator. Usage: Scripts/test.sh [-only-testing:UnlistTests/Name]
cd "$(dirname "$0")/.." || exit 1
~/.local/bin/xcodegen generate --quiet || exit 1
LOG=build/test.log
mkdir -p build
xcodebuild test -project Unlist.xcodeproj -scheme Unlist \
  -destination "platform=iOS Simulator,name=${UNLIST_SIM:-iPhone 18 Pro}" \
  -derivedDataPath build/DerivedData "$@" > "$LOG" 2>&1
STATUS=$?
grep -E "error:|✘|failed|recorded an issue|Test run with|TEST SUCCEEDED|TEST FAILED|BUILD FAILED" "$LOG" | grep -v "^\s*$" | head -40
exit $STATUS
