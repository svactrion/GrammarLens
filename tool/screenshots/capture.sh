#!/bin/zsh
# App Store screenshots (1.1.0 release, P4, P5): captures the nine frames
# from the real app in the simulator, then frames them.
#
#   tool/screenshots/capture.sh            # iPhone and iPad
#   tool/screenshots/capture.sh iphone     # one of them
#
# Simulators (override with IPHONE_SIM / IPAD_SIM, a name or a UDID):
#   iPhone 17 Pro Max  -> 1320 x 2868, App Store 6.9"
#   iPad Pro 13-inch (M5) -> 2064 x 2752, App Store 13"
# on the runtime in SIM_RUNTIME (default iOS 26.5).
#
# Each run: boots the simulator, sets English (US), light mode and a fixed status bar
# (9:41, full battery, full signal), removes the app (a fresh install, so
# the seeded data is the only data), runs `flutter drive` (a debug build)
# with capture_app.dart and capture_driver.dart, and writes the raw PNGs
# to build/screenshots/raw/<device>/ (not kept in the repository, P8). Then
# frame.py builds the framed set and the overview.
set -euo pipefail
cd "$(dirname "$0")/../.."

RUNTIME="${SIM_RUNTIME:-iOS 26.5}"
OUT=docs/design/release-1.1.0/screenshots
# P8: the raw captures stay out of the repository (build/ is ignored).
RAW=build/screenshots/raw
BUNDLE=com.ahmettayfur.grammarlens
typeset -A SIMS
SIMS=(iphone "${IPHONE_SIM:-iPhone 17 Pro Max}" ipad "${IPAD_SIM:-iPad Pro 13-inch (M5)}")

udid_for() {
  # A UDID as given, or the available device of that exact name on RUNTIME.
  if [[ "$1" =~ ^[0-9A-F-]{36}$ ]]; then echo "$1"; return; fi
  xcrun simctl list devices available | awk -v rt="-- $RUNTIME --" -v name="$1" '
    $0 == rt {inrt=1; next} /^-- / {inrt=0}
    inrt { line=$0; sub(/^ +/, "", line); n=line; sub(/ \([0-9A-F-]{36}\).*/, "", n)
           if (n == name) { match(line, /[0-9A-F-]{36}/); print substr(line, RSTART, RLENGTH); exit } }'
}

if [[ $# -eq 0 ]]; then devices=(iphone ipad); else devices=("$@"); fi
for device in "${devices[@]}"; do
  name="${SIMS[$device]}"
  udid="$(udid_for "$name")"
  [[ -n "$udid" ]] || { echo "No available simulator '$name' on $RUNTIME" >&2; exit 1; }
  echo "== $device: $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # English (US) on the simulator, so the iPad's status bar shows the date
  # in English; takes effect after a restart.
  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array en-US
  xcrun simctl spawn "$udid" defaults write -g AppleLocale -string en_US
  # The keyboard's one-time "slide to type" introduction would cover the
  # keyboard in frame 06: marked as already shown.
  xcrun simctl spawn "$udid" defaults write com.apple.Preferences \
    DidShowContinuousPathIntroduction -bool true
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState discharging --batteryLevel 100
  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  rm -rf "$RAW/$device"
  # Frames 01-08 on seeded data.
  SCREENSHOT_UDID="$udid" SCREENSHOT_OUT="$RAW/$device" \
    flutter drive --no-pub -d "$udid" \
      --driver=tool/screenshots/capture_driver.dart \
      --target=tool/screenshots/capture_app.dart
  # Frame 09: Welcome on a fresh install.
  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  SCREENSHOT_UDID="$udid" SCREENSHOT_OUT="$RAW/$device" \
    flutter drive --no-pub -d "$udid" --dart-define=CAPTURE_WELCOME=true \
      --driver=tool/screenshots/capture_driver.dart \
      --target=tool/screenshots/capture_app.dart
done

build/scene_art_venv/bin/python tool/screenshots/frame.py
