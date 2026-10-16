#!/bin/sh
# Runs the iOS unit tests on the iPhone simulator. Usage: Scripts/test.sh [-only-testing:UnlistTests/Name]
# To run on a connected iPhone instead: UNLIST_DEVICE=<udid> UNLIST_TEAM=<team id> Scripts/test.sh
cd "$(dirname "$0")/.." || exit 1
~/.local/bin/xcodegen generate --quiet || exit 1
LOG=build/test.log
mkdir -p build
if [ -n "$UNLIST_DEVICE" ]; then
  set -- -destination "id=$UNLIST_DEVICE" -allowProvisioningUpdates DEVELOPMENT_TEAM="$UNLIST_TEAM" CODE_SIGN_STYLE=Automatic "$@"
  DATA=build/DeviceData
else
  set -- -destination "platform=iOS Simulator,name=${UNLIST_SIM:-iPhone 18 Pro}" "$@"
  DATA=build/DerivedData
fi
xcodebuild test -project Unlist.xcodeproj -scheme Unlist -derivedDataPath "$DATA" "$@" > "$LOG" 2>&1
STATUS=$?
grep -E "error:|✘|failed|recorded an issue|Test run with|TEST SUCCEEDED|TEST FAILED|BUILD FAILED" "$LOG" | grep -v -e "^\s*$" -e "ProcessSuspension" | head -40
exit $STATUS
