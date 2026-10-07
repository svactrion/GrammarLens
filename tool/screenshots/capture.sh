#!/bin/zsh
# App Store screenshots (1.2.0): captures the raw frames from the real app
# in the simulator. Framing is a separate step (frame.py).
#
#   tool/screenshots/capture.sh            # iPhone and iPad
#   tool/screenshots/capture.sh iphone     # one of them
#   RUNS=free tool/screenshots/capture.sh iphone   # some runs only
#
# Simulators (override with IPHONE_SIM / IPAD_SIM, a name or a UDID):
#   iPhone 14 Plus         -> 1284 x 2778, App Store 6.5"
#   iPad Pro 13-inch (M5)  -> 2064 x 2752, App Store 13"
# on the runtime in SIM_RUNTIME (default iOS 26.5).
#
# Each device: boots the simulator, sets English (US), light mode and a
# fixed status bar (9:41, full battery, full signal), then for each run
# removes the app (a fresh install, so the seeded data is the only data)
# and runs `flutter drive` (a debug build) with capture_app.dart and
# capture_driver.dart:
#   iPhone: free, premium (CAPTURE_PREMIUM), welcome (CAPTURE_WELCOME),
#           practice (CAPTURE_PRACTICE_USED);
#   iPad:   free.
# RUNS (default "free premium welcome practice") limits the runs; the iPad has
# free. Only the runs taken replace their frames.
# Raw PNGs go to build/screenshots/1.2.0/raw/<device>/ (not kept in the
# repository).
set -euo pipefail
cd "$(dirname "$0")/../.."

RUNTIME="${SIM_RUNTIME:-iOS 26.5}"
RAW=build/screenshots/1.2.0/raw
RUNS=(${=RUNS:-free premium welcome practice})
BUNDLE=com.ahmettayfur.grammarlens
typeset -A SIMS
SIMS=(iphone "${IPHONE_SIM:-iPhone 14 Plus}" ipad "${IPAD_SIM:-iPad Pro 13-inch (M5)}")

udid_for() {
  # A UDID as given, or the available device of that exact name on RUNTIME.
  if [[ "$1" =~ ^[0-9A-F-]{36}$ ]]; then echo "$1"; return; fi
  xcrun simctl list devices available | awk -v rt="-- $RUNTIME --" -v name="$1" '
    $0 == rt {inrt=1; next} /^-- / {inrt=0}
    inrt { line=$0; sub(/^ +/, "", line); n=line; sub(/ \([0-9A-F-]{36}\).*/, "", n)
           if (n == name) { match(line, /[0-9A-F-]{36}/); print substr(line, RSTART, RLENGTH); exit } }'
}

# One `flutter drive` on a fresh install; extra arguments are defines.
drive() {
  local udid=$1 device=$2; shift 2
  xcrun simctl uninstall "$udid" "$BUNDLE" 2>/dev/null || true
  SCREENSHOT_UDID="$udid" SCREENSHOT_OUT="$RAW/$device" SCREENSHOT_DEVICE="$device" \
    flutter drive --no-pub -d "$udid" "$@" \
      --driver=tool/screenshots/capture_driver.dart \
      --target=tool/screenshots/capture_app.dart
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
  # keyboard in the question frame: marked as already shown.
  # The keyboard reads com.apple.keyboard.preferences (a new simulator
  # showed the introduction with only com.apple.Preferences set).
  for domain in com.apple.Preferences com.apple.keyboard.preferences; do
    xcrun simctl spawn "$udid" defaults write "$domain" \
      DidShowContinuousPathIntroduction -bool true
  done
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState discharging --batteryLevel 100
  # Plain ifs: a false test at the end of an `&&` list would end the
  # script under errexit.
  if (( ${RUNS[(Ie)free]} )); then drive "$udid" "$device"; fi
  if [[ "$device" == iphone ]]; then
    if (( ${RUNS[(Ie)premium]} )); then
      drive "$udid" "$device" --dart-define=CAPTURE_PREMIUM=true
    fi
    if (( ${RUNS[(Ie)welcome]} )); then
      drive "$udid" "$device" --dart-define=CAPTURE_WELCOME=true
    fi
    if (( ${RUNS[(Ie)practice]} )); then
      drive "$udid" "$device" --dart-define=CAPTURE_PRACTICE_USED=true
    fi
  fi
done
