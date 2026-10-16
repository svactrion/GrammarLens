#!/bin/zsh
# Dedicated new store simulators ONLY. No uninstall, erase or user devices.
set -euo pipefail
cd "$(dirname "$0")/../../.."
FAMILY=${1:?Use iphone or ipad}
MODE=${2:-full}
EXTRA_DEFINES=()
if [[ "$MODE" == onboarding ]]; then
  EXTRA_DEFINES+=(--dart-define=CAPTURE_ONBOARDING_ONLY=true)
fi
case "$FAMILY" in
  iphone) CAPTURE_DEVICE=40E58DFD-CBBD-44D0-8FF6-FE1961AE18AA ;;
  ipad) CAPTURE_DEVICE=1DB726C6-8844-4791-B3CA-DCC2F671CCD9 ;;
  *) exit 2 ;;
esac
if ! xcrun simctl list devices booted | rg -q "$CAPTURE_DEVICE"; then
  xcrun simctl boot "$CAPTURE_DEVICE"
fi
xcrun simctl bootstatus "$CAPTURE_DEVICE" -b
xcrun simctl spawn "$CAPTURE_DEVICE" defaults write -g AppleLanguages -array en-US
xcrun simctl spawn "$CAPTURE_DEVICE" defaults write -g AppleLocale -string en_US
xcrun simctl ui "$CAPTURE_DEVICE" appearance light
xcrun simctl status_bar "$CAPTURE_DEVICE" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
SCREENSHOT_UDID="$CAPTURE_DEVICE" SCREENSHOT_FAMILY="$FAMILY" SCREENSHOT_MODE="$MODE" \
SCREENSHOT_OUT="${STORE_CAPTURE_OUT:-$PWD/docs/product/marketing/2026-10-16-app-store/raw/$FAMILY}" \
flutter drive --no-pub -d "$CAPTURE_DEVICE" \
  "${EXTRA_DEFINES[@]}" \
  --driver=tool/marketing/store_130/capture_driver.dart \
  --target=tool/marketing/store_130/capture_app.dart
