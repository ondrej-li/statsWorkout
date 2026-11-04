#!/usr/bin/env bash
#
# Captures the App Store screenshots from clean simulators.
#
# Usage:
#   Scripts/capture-screenshots.sh [iphone|ipad|all] [en|cs]
#
# Frames land in screenshots/<locale>/iphone and screenshots/<locale>/ipad, one
# folder per App Store localisation. Each shot is the app itself in light mode
# with the status bar pinned to 9:41, flattened to remove the alpha channel and
# stripped of the metadata chunks App Store Connect rejects.
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
DELAY="${SHOT_DELAY:-8}"

# A whole past day reads better than the hours elapsed so far, and yesterday
# also has workouts to show under the chart, so the day shot steps back one day.

which="${1:-all}"
locale="${2:-en}"

# The app language comes from a launch argument, but the system status bar and
# the calendar follow the simulator's region, so that is set to match.
case "$locale" in
    en) app_language=english; region=en_US ;;
    cs) app_language=czech; region=cs_CZ ;;
    *) echo "usage: $0 [iphone|ipad|all] [en|cs]" >&2; exit 2 ;;
esac

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

# wait_for_screen <device> <screen> <name>
#
# The app drops a marker file into its Documents folder when a screen has
# finished loading (see ScreenshotRoute.markReady), so the capture waits for
# content instead of guessing with a fixed delay.
wait_for_screen() {
    local device=$1 screen=$2 name=$3
    local deadline=$((SECONDS + 45))
    while [ $SECONDS -lt $deadline ]; do
        if screen_ready "$device" "$screen"; then
            return 0
        fi
        sleep 1
    done
    echo "warning: $name did not finish loading in 45s" >&2
    return 1
}

# screen_ready <device> <screen>
screen_ready() {
    local device=$1 screen=$2
    local container
    container=$(xcrun simctl get_app_container "$device" "$BUNDLE_ID" data 2>/dev/null || true)
    [ -n "$container" ] && [ -f "$container/Documents/screenshot-ready-$screen" ]
}

# launch_app <device> [launch arguments…]
launch_app() {
    local device=$1
    shift
    xcrun simctl terminate "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$device" "$BUNDLE_ID" \
        -settings.useMockData YES \
        -settings.language "$app_language" \
        -screenshotHideDemoLabels YES \
        "$@" >/dev/null
}

# ensure_region <device> <locale>
#
# The status bar date and the calendar's first weekday come from the device
# region, so an English frame on a Czech simulator shows "Wed 4. 11.". Changing
# it needs a reboot, so it is only done when it differs.
ensure_region() {
    local device=$1 want=$2 current
    current=$(xcrun simctl spawn "$device" defaults read .GlobalPreferences AppleLocale 2>/dev/null | tr -d '"' || true)
    [ "$current" = "$want" ] && return 0
    echo "==> Setting region on $device to $want"
    # spawn needs a booted device, and the new region only takes effect after a
    # restart.
    xcrun simctl boot "$device" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device" -b >/dev/null 2>&1 || true
    xcrun simctl spawn "$device" defaults write .GlobalPreferences AppleLocale -string "$want"
    xcrun simctl shutdown "$device" >/dev/null 2>&1 || true
    xcrun simctl boot "$device" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device" -b >/dev/null 2>&1 || true
}

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

# capture <device> <out-dir> <name> <ready-screen> [launch arguments…]
capture() {
    local device=$1 dir=$2 name=$3 ready=$4
    shift 4

    echo "    $name"
    xcrun simctl boot "$device" >/dev/null 2>&1 || true
    xcrun simctl bootstatus "$device" -b >/dev/null 2>&1 || true
    xcrun simctl status_bar "$device" override \
        --time '9:41' --dataNetwork wifi --wifiBars 3 --cellularBars 4 \
        --batteryState charged --batteryLevel 100 >/dev/null 2>&1 || true
    xcrun simctl ui "$device" appearance light >/dev/null 2>&1 || true

    xcrun simctl terminate "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl uninstall "$device" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl install "$device" "$app_bundle"

    # Demo data keeps every chart populated; -settings.useMockData is read from
    # the argument domain, so it overrides whatever the previous run stored.
    # -screenshotHideDemoLabels hides the demo chip, banner and route caption so
    # the artwork shows the product, not the scaffolding. Both are debug-only.
    launch_app "$device" "$@"

    mkdir -p "$dir"
    # A frame is only good when the screen has loaded, is still loaded, and has
    # stopped moving. Two frames a moment apart must look the same, and the
    # app's "ready" marker (cleared whenever a reload starts) must be there after
    # both - a skeleton card or a scroll animation otherwise photographs
    # perfectly well.
    local attempt=1
    local first="$dir/.$name.a.png"
    while true; do
        if ! wait_for_screen "$device" "$ready" "$attempt"; then
            # A launch occasionally hangs on a loaded machine; starting it again
            # is cheaper than failing the whole run.
            echo "    retrying $name"
            launch_app "$device" "$@"
        fi
        # Let the scroll position and the animation settle before the frames.
        sleep 2
        xcrun simctl io "$device" screenshot "$first" >/dev/null 2>&1
        sleep 1
        xcrun simctl io "$device" screenshot "$dir/$name.raw.png" >/dev/null 2>&1

        if swift tools/png-brightness.swift "$dir/$name.raw.png" >/dev/null 2>&1 \
            && screen_ready "$device" "$ready" \
            && swift tools/png-difference.swift "$first" "$dir/$name.raw.png" >/dev/null 2>&1; then
            rm -f "$first"
            break
        fi
        if [ "$attempt" -ge 4 ]; then
            rm -f "$first"
            echo "error: $name never settled" >&2
            return 1
        fi
        attempt=$((attempt + 1))
    done
    swift tools/flatten-png.swift "$dir/$name.raw.png" "$dir/$name.png" >/dev/null
    rm -f "$dir/$name.raw.png"
    python3 tools/strip-png-metadata.py "$dir/$name.png" >/dev/null
}

iphone() {
    ensure_device "$IPHONE"
    echo "==> iPhone ($IPHONE, $locale)"
    ensure_region "$IPHONE" "$region"
    local d="screenshots/$locale/iphone"
    rm -f "$d"/*.png 2>/dev/null || true

    # A complete month reads better than the three days elapsed so far, so the
    # shots step one period back.
    capture "$IPHONE" "$d" 01-dashboard stats \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all -screenshotOffset -1
    capture "$IPHONE" "$d" 02-day stats \
        -screenshotTab stats -screenshotPeriod day -screenshotScope all \
        -screenshotOffset -1 -screenshotSection charts -screenshotSelect peak
    capture "$IPHONE" "$d" 03-progress stats \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all \
        -screenshotOffset -1 -screenshotSection progress -screenshotSelect peak
    # The 1.1 headline: a workout as the Health app shows it, with its route.
    capture "$IPHONE" "$d" 04-workout-detail detail \
        -screenshotTab activities -screenshotWorkout 0
    capture "$IPHONE" "$d" 05-activity-log activities \
        -screenshotTab activities
    # The workout-only view is most legible unscrolled, where the switch itself
    # and the smaller numbers are both visible.
    capture "$IPHONE" "$d" 06-activities-only stats \
        -screenshotTab stats -screenshotPeriod month -screenshotScope activities \
        -screenshotOffset -1
    capture "$IPHONE" "$d" 07-settings settings \
        -screenshotTab settings
}

ipad() {
    ensure_device "$IPAD"
    echo "==> iPad ($IPAD, $locale)"
    ensure_region "$IPAD" "$region"
    local d="screenshots/$locale/ipad"
    rm -f "$d"/*.png 2>/dev/null || true

    capture "$IPAD" "$d" 01-dashboard stats \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all -screenshotOffset -1
    capture "$IPAD" "$d" 02-day stats \
        -screenshotTab stats -screenshotPeriod day -screenshotScope all \
        -screenshotOffset -1 -screenshotSection charts -screenshotSelect peak
    capture "$IPAD" "$d" 03-progress stats \
        -screenshotTab stats -screenshotPeriod month -screenshotScope all \
        -screenshotOffset -1 -screenshotSection progress -screenshotSelect peak
    capture "$IPAD" "$d" 04-workout-detail detail \
        -screenshotTab activities -screenshotWorkout 0
    capture "$IPAD" "$d" 05-activity-log activities \
        -screenshotTab activities
}

case "$which" in
    iphone) iphone ;;
    ipad) ipad ;;
    all) iphone; ipad ;;
    *) echo "usage: $0 [iphone|ipad|all] [en|cs]" >&2; exit 2 ;;
esac

echo "==> Done"
