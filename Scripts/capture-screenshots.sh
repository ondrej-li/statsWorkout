#!/usr/bin/env bash
#
# Captures the App Store screenshots from clean simulators.
#
# Usage:
#   Scripts/capture-screenshots.sh [iphone|ipad|all]
#
# Frames land in screenshots/iphone and screenshots/ipad. Each shot is the app
# itself with the status bar pinned to 9:41, flattened to remove the alpha
# channel and stripped of the metadata chunks App Store Connect rejects.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

BUNDLE_ID="com.defik74.statsWorkout"
SCHEME="StatsWorkout"
PROJECT="StatsWorkout.xcodeproj"

# App Store Connect sorts by display class: the iPhone tab wants 6.1"/6.3"
# (1206x2622); a 6.9" phone produces 1320x2868, which that tab refuses.
IPHONE="${SHOT_IPHONE:-Shot iPhone 6.3}"
IPHONE_TYPE="${SHOT_IPHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
IPAD="${SHOT_IPAD:-iPad Pro 13-inch (M5)}"
DELAY="${SHOT_DELAY:-6}"

# A whole past day reads better than the hours elapsed so far, so the day and
# chart shots freeze the clock just before midnight of the previous day.
FROZEN_DAY="${SHOT_DAY:-$(date -v-1d +%Y-%m-%d)}T23:30:00"

which="${1:-all}"

echo "==> Building"
xcodebuild build \
    -project "$PROJECT" -scheme "$SCHEME" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -configuration Debug -quiet

app_bundle=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{d=$2} / FULL_PRODUCT_NAME/{p=$2} END{print d"/"p}')

echo "==> App: $app_bundle"

ensure_device() {
    local name=$1
    if ! xcrun simctl list devices available | grep -q "^    $name ("; then
        if [ "$name" = "$IPHONE" ]; then
            xcrun simctl create "$name" "$IPHONE_TYPE" "${SHOT_IPHONE_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}"
        else
            echo "error: simulator '$name' not found" >&2
            return 1
        fi
    fi
}

# capture <device> <out-dir> <name> [launch arguments…]
capture() {
    local device=$1 dir=$2 name=$3
    shift 3

    echo "    $name"
    xcrun simctl boot "$device" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device" -b >/dev/null 2>&1 || true
    xcrun simctl status_bar "$device" override \
        --time '9:41' --dataNetwork wifi --wifiBars 3 --cellularBars 4 \
        --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true

    xcrun simctl terminate "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl install "$device" "$app_bundle"

    # Demo data keeps every chart populated; -settings.useMockData is read from
    # the argument domain, so it overrides whatever the previous run stored.
    xcrun simctl launch "$device" "$BUNDLE_ID" -settings.useMockData YES "$@" >/dev/null
    sleep "$DELAY"

    mkdir -p "$dir"
    xcrun simctl io "$device" screenshot "$dir/$name.raw.png" >/dev/null 2>&1
    swift tools/flatten-png.swift "$dir/$name.raw.png" "$dir/$name.png" >/dev/null
    rm -f "$dir/$name.raw.png"
    python3 tools/strip-png-metadata.py "$dir/$name.png" >/dev/null
}

iphone() {
    ensure_device "$IPHONE"
    echo "==> iPhone ($IPHONE)"
    local d=screenshots/iphone
    rm -f "$d"/*.png 2>/dev/null || true

    # A complete month reads better than the three days elapsed so far, so the
    # shots step one period back.
    capture "$IPHONE" "$d" 01-dashboard \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all -screenshotOffset -1
    capture "$IPHONE" "$d" 02-day \
        -screenshotTab stats -screenshotPeriod day -screenshotScope all \
        -screenshotNow "$FROZEN_DAY" -screenshotSection charts -screenshotSelect peak
    capture "$IPHONE" "$d" 03-progress \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all \
        -screenshotOffset -1 -screenshotSection progress -screenshotSelect peak
    # The workout-only view is most legible unscrolled, where the switch itself
    # and the smaller numbers are both visible.
    capture "$IPHONE" "$d" 04-activities-only \
        -screenshotTab stats -screenshotPeriod month -screenshotScope activities \
        -screenshotOffset -1
    capture "$IPHONE" "$d" 05-activity-log \
        -screenshotTab activities
    capture "$IPHONE" "$d" 06-settings \
        -screenshotTab settings
}

ipad() {
    ensure_device "$IPAD"
    echo "==> iPad ($IPAD)"
    local d=screenshots/ipad
    rm -f "$d"/*.png 2>/dev/null || true

    capture "$IPAD" "$d" 01-dashboard \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all -screenshotOffset -1
    capture "$IPAD" "$d" 02-day \
        -screenshotTab stats -screenshotPeriod day -screenshotScope all \
        -screenshotNow "$FROZEN_DAY" -screenshotSection charts -screenshotSelect peak
    capture "$IPAD" "$d" 03-progress \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all \
        -screenshotOffset -1 -screenshotSection progress -screenshotSelect peak
    capture "$IPAD" "$d" 04-activity-log \
        -screenshotTab activities
}

case "$which" in
    iphone) iphone ;;
    ipad) ipad ;;
    all) iphone; ipad ;;
    *) echo "usage: $0 [iphone|ipad|all]" >&2; exit 2 ;;
esac

echo "==> Done"
