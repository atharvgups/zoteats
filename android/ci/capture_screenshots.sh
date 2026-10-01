#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-android-screenshots}"
mkdir -p "$OUT"

PACKAGE="com.atharvgupta.anteats"
ACTIVITY="$PACKAGE/.MainActivity"
APK="${APK_PATH:-app/build/outputs/apk/release/app-release.apk}"

adb wait-for-device
adb install -r -t "$APK"

launch() {
  local extra="$1"
  local dark="${2:-false}"
  adb shell am force-stop "$PACKAGE" || true
  adb shell cmd uimode night "$([[ "$dark" == true ]] && echo yes || echo no)"
  if [[ "$extra" == "eat" ]]; then
    adb shell am start -n "$ACTIVITY" --ez dark "$dark"
  else
    adb shell am start -n "$ACTIVITY" --es screenshot "$extra" --ez dark "$dark"
  fi
  sleep 18
}

snap() {
  adb exec-out screencap -p > "$1"
}

launch eat false
snap "$OUT/eat_light.png"

launch dish false
snap "$OUT/dish_light.png"

launch plate false
snap "$OUT/plate_light.png"

launch eat true
snap "$OUT/eat_dark.png"

adb shell cmd uimode night no || true
ls -la "$OUT"
