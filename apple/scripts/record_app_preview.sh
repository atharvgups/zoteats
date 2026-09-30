#!/usr/bin/env bash
# Record a 15-30s App Store preview from the already-booted simulator.
# No overlay text. Light mode. Eat (B/L/D) then Campus then Study.
set -euo pipefail

OUT_DIR="demo"
DEVICE=""
BUNDLE_ID="com.atharvgupta.zoteats"

usage() {
  echo "Usage: $0 [--out DIR] [--device NAME] [--bundle-id ID]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="${2:-}"; shift 2 ;;
    --device) DEVICE="${2:-}"; shift 2 ;;
    --bundle-id) BUNDLE_ID="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1" >&2; usage ;;
  esac
done

mkdir -p "$OUT_DIR"

if [ -z "$DEVICE" ]; then
  DEVICE=$(xcrun simctl list devices booted | grep -E "iPhone" | head -1 | sed -E 's/^ +//; s/ \([-0-9A-F]+\).*$//' || true)
fi
if [ -z "$DEVICE" ]; then
  echo "No booted iPhone simulator" >&2
  exit 1
fi

xcrun simctl ui booted appearance light
xcrun simctl status_bar booted override \
  --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
sleep 1

MOV="$OUT_DIR/app_preview.mov"
MP4="$OUT_DIR/app_preview.mp4"
rm -f "$MOV" "$MP4"

xcrun simctl io "$DEVICE" recordVideo --codec h264 --force "$MOV" &
RECORD_PID=$!
sleep 2

# Prefer the short XCUITest tour when the test bundle is already built.
if [ -n "${DERIVED_DATA:-}" ] && [ -d "${DERIVED_DATA}" ]; then
  set +e
  xcodebuild \
    -project apple/ZotEats.xcodeproj \
    -scheme ZotEats \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:ZotEatsUITests/AppPreviewUITests/testAppPreview \
    CODE_SIGNING_ALLOWED=NO \
    test-without-building
  TEST_STATUS=$?
  set -e
  if [ "$TEST_STATUS" -ne 0 ]; then
    echo "::warning::App preview UI test exited $TEST_STATUS; using launch-arg fallback"
    xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" -initialTab dining -preferLiveHall
    sleep 8
    xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" -initialTab campus
    sleep 6
    xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" -initialTab busyness
    sleep 6
  fi
else
  xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" -initialTab dining -preferLiveHall
  sleep 8
  xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" -initialTab campus
  sleep 6
  xcrun simctl launch --terminate-running-process booted "$BUNDLE_ID" -initialTab busyness
  sleep 6
fi

kill -INT "$RECORD_PID"
wait "$RECORD_PID" || true

if command -v ffmpeg >/dev/null 2>&1; then
  DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$MOV" | cut -d. -f1)
  TRIM=30
  if [ -n "$DURATION" ] && [ "$DURATION" -lt 30 ]; then
    TRIM="$DURATION"
  fi
  if [ -n "$DURATION" ] && [ "$DURATION" -lt 15 ]; then
    echo "::warning::Preview is ${DURATION}s (Apple wants 15-30). Leaving full clip."
    TRIM="$DURATION"
  fi
  ffmpeg -y -loglevel error -i "$MOV" -t "$TRIM" -pix_fmt yuv420p -c:v libx264 -an "$MP4"
  rm -f "$MOV"
else
  echo "ffmpeg missing; leaving $MOV" >&2
fi

FRAMES="$OUT_DIR/preview_frames"
mkdir -p "$FRAMES"
if [ -f "$MP4" ]; then
  ffmpeg -y -loglevel error -i "$MP4" -vf "fps=1/5" "$FRAMES/frame_%03d.png"
elif [ -f "$MOV" ]; then
  ffmpeg -y -loglevel error -i "$MOV" -vf "fps=1/5" "$FRAMES/frame_%03d.png" || true
fi

echo "Recorded App Store preview in $OUT_DIR"
ls -la "$OUT_DIR"
