#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# AltStore Classic signs this device build with the user's Apple account.
# Signing is disabled here only for this IPA; simulator tests keep local signing.
xcodebuild -project VeloxNutrition.xcodeproj -scheme VeloxNutrition \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedData/AltStore \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build

APP_PATH="DerivedData/AltStore/Build/Products/Release-iphoneos/VeloxNutrition.app"
test -d "$APP_PATH"
xcrun lipo -verify_arch arm64 "$APP_PATH/VeloxNutrition"
python3 - "$APP_PATH/Info.plist" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as file:
    info = plistlib.load(file)
assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"], "Expected an iPhone device build"
assert info["CFBundleIdentifier"] == "app.veloxnutrition.personal"
print("Validated iPhoneOS bundle and arm64 executable.")
PY

PACKAGE_DIR=$(mktemp -d)
trap 'rm -rf "$PACKAGE_DIR"' EXIT
mkdir -p "$PACKAGE_DIR/Payload" artifacts
ditto "$APP_PATH" "$PACKAGE_DIR/Payload/VeloxNutrition.app"
ditto -c -k --keepParent "$PACKAGE_DIR/Payload" artifacts/VeloxNutrition-AltStore.ipa
python3 - <<'PY'
import zipfile
with zipfile.ZipFile("artifacts/VeloxNutrition-AltStore.ipa") as ipa:
    assert ipa.testzip() is None, "IPA archive is damaged"
    assert "Payload/VeloxNutrition.app/Info.plist" in ipa.namelist()
    assert "Payload/VeloxNutrition.app/VeloxNutrition" in ipa.namelist()
print("Validated IPA archive structure and integrity.")
PY
