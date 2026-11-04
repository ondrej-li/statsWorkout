#!/usr/bin/env bash
#
# Archives StatsWorkout and uploads the build to TestFlight.
#
# Usage:
#   Scripts/publish-testflight.sh [build-number]
#
# Environment:
#   TEAM_ID   Apple Developer team ID (default: B592D69P29)
#
# Requirements:
#   - Xcode signed in with the team's Apple ID (Settings > Accounts)
#   - an App Store Connect app record for com.defik74.statsWorkout
#
set -euo pipefail

TEAM_ID="${TEAM_ID:-B592D69P29}"
BUILD_NUMBER="${BUILD_NUMBER:-${1:-$(date +%Y%m%d%H%M)}}"
BUNDLE_ID="com.defik74.statsWorkout"

PROJECT="StatsWorkout.xcodeproj"
SCHEME="StatsWorkout"
ARCHIVE="build/StatsWorkout.xcarchive"
EXPORT_DIR="build/export"
EXPORT_OPTIONS="build/ExportOptions.plist"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required (brew install xcodegen)" >&2
    exit 1
fi

echo "==> Generating project"
xcodegen generate

echo "==> Archiving $BUNDLE_ID build $BUILD_NUMBER"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p build

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$ARCHIVE/Products/Applications/StatsWorkout.app/Info.plist" 2>/dev/null || echo "?")
echo "==> Exporting and uploading $BUNDLE_ID $VERSION ($BUILD_NUMBER) to App Store Connect"
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST

UPLOAD_LOG="$(mktemp)"
if ! xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates 2>&1 | tee "$UPLOAD_LOG"; then
    if grep -qE "Failed to Use Accounts|Invalid credentials|missing Xcode-Username" "$UPLOAD_LOG"; then
        cat >&2 <<HINT

error: App Store Connect rejected the upload because Xcode has no valid account.

The archive itself is fine: $ARCHIVE
Only the upload needs credentials, so nothing has to be rebuilt.

Fix it once in Xcode:
  Xcode → Settings → Accounts → sign in with the Apple ID for team $TEAM_ID
  (if it is already listed, remove it and add it again)

Then run this script again, or retry just the upload:
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
      -exportOptionsPlist "$EXPORT_OPTIONS" -exportPath "$EXPORT_DIR" \
      -allowProvisioningUpdates

HINT
    fi
    rm -f "$UPLOAD_LOG"
    exit 1
fi
rm -f "$UPLOAD_LOG"

echo "==> Uploaded build $BUILD_NUMBER. Processing usually takes a few minutes;"
echo "    TestFlight builds appear under App Store Connect > TestFlight."
