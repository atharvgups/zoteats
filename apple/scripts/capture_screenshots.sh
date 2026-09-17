#!/usr/bin/env bash
# Capture App Store listing screenshots from a Debug iOS Simulator build.
# Picks a 6.7" device (1290x2796) when the runner has one.
set -euo pipefail

APP_PATH=""
OUT_DIR="screenshots"
BUNDLE_ID="com.atharvgupta.zoteats"

usage() {
  echo "Usage: $0 --app PATH [--out DIR] [--bundle-id ID]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP_PATH="${2:-}"; shift 2 ;;
    --out) OUT_DIR="${2:-}"; shift 2 ;;
    --bundle-id) BUNDLE_ID="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "Missing or invalid --app (got: ${APP_PATH:-})" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

pick_device() {
  local names want
  names=$(xcrun simctl list devices available | grep -E "^[[:space:]]+iPhone" | sed -E 's/^ +//; s/ \([-0-9A-F]+\).*$//')
  # 6.7" / 1290x2796 App Store slot. Avoid 16 Pro Max (6.9").
  for want in "iPhone 16 Plus" "iPhone 15 Plus" "iPhone 15 Pro Max" "iPhone 14 Pro Max" "iPhone 16 Pro" "iPhone 16"; do
    if echo "$names" | grep -Fxq "$want"; then
      echo "$want"
      return 0
    fi
  done
  echo "$names" | head -1
}

DEVICE=$(pick_device)
if [ -z "$DEVICE" ]; then
  echo "No available iPhone simulator" >&2
  exit 1
fi
echo "Using simulator: $DEVICE"
echo "$DEVICE" > "$OUT_DIR/device.txt"

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar booted override \
  --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4
xcrun simctl install booted "$APP_PATH"

launch_tab() {
  xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" "$@"
}

# Prime Waitz / LibCal so the first Study listing shot isn't skeletons.
xcrun simctl ui booted appearance light
launch_tab -initialTab busyness
sleep 14

for mode in light dark; do
  xcrun simctl ui booted appearance "$mode"
  # Gym tab is not in shipping builds.
  launch_tab -initialTab dining -preferLiveHall
  sleep 14
  xcrun simctl io booted screenshot "$OUT_DIR/dining_${mode}.png"

  launch_tab -initialTab campus
  sleep 12
  xcrun simctl io booted screenshot "$OUT_DIR/campus_${mode}.png"

  launch_tab -initialTab busyness
  sleep 20
  xcrun simctl io booted screenshot "$OUT_DIR/busyness_${mode}.png"

  launch_tab -initialTab dining -showSettings
  sleep 10
  xcrun simctl io booted screenshot "$OUT_DIR/settings_${mode}.png"

  launch_tab -initialTab campus -campusMenu halal-shack
  sleep 12
  xcrun simctl io booted screenshot "$OUT_DIR/campus_menu_${mode}.png"

  launch_tab -initialTab dining -showDishDetail
  sleep 18
  xcrun simctl io booted screenshot "$OUT_DIR/dish_nutrition_${mode}.png"

  launch_tab -initialTab dining -showPlate
  sleep 18
  xcrun simctl io booted screenshot "$OUT_DIR/plate_${mode}.png"
done

xcrun simctl ui booted appearance light

LISTING="$OUT_DIR/listing"
mkdir -p "$LISTING"
cp "$OUT_DIR/dining_light.png" "$LISTING/eat_light.png"
cp "$OUT_DIR/campus_light.png" "$LISTING/campus.png"
cp "$OUT_DIR/busyness_light.png" "$LISTING/study.png"
cp "$OUT_DIR/settings_light.png" "$LISTING/settings.png"
cp "$OUT_DIR/dining_dark.png" "$LISTING/eat_dark.png"
cp "$OUT_DIR/campus_menu_light.png" "$LISTING/campus_menu.png"
cp "$OUT_DIR/plate_light.png" "$LISTING/plate_light.png"
cp "$OUT_DIR/dish_nutrition_light.png" "$LISTING/dish_nutrition_light.png"

echo "Captured listing screenshots in $LISTING"
ls -la "$LISTING"
