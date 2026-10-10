#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null || ! command -v xcrun >/dev/null; then
  echo "Xcode mit ausgewählten Command Line Tools ist erforderlich."
  exit 1
fi
python3 scripts/download_fonts.py
swift test
# Select an available iPhone dynamically, so this works with multiple Xcode versions.
SIMULATOR_ID=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; devices=json.load(sys.stdin)["devices"]; phones=[d for key,ds in devices.items() if "iOS" in key for d in ds if "iPhone" in d["name"]]; print(next((d["udid"] for d in phones if d["state"]=="Booted"), phones[0]["udid"] if phones else ""))')
if [ -z "$SIMULATOR_ID" ]; then
  echo "Installiere einen iOS-Simulator in Xcode > Settings > Components."
  exit 1
fi
xcodebuild -project VeloxNutrition.xcodeproj -scheme VeloxNutrition \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath DerivedData -resultBundlePath "TestResults-$(date +%Y%m%d-%H%M%S).xcresult" \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
