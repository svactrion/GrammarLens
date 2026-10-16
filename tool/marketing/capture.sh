#!/bin/zsh
# Dedicated simulator only. Never uninstalls or erases a user's app/data.
set -euo pipefail
cd "$(dirname "$0")/../.."
CAPTURE_DEVICE=7EB79F5A-B0D4-4EAC-89B6-E46CEB91286D
xcrun simctl spawn "$CAPTURE_DEVICE" defaults write -g AppleLanguages -array en-US
xcrun simctl spawn "$CAPTURE_DEVICE" defaults write -g AppleLocale -string en_US
xcrun simctl ui "$CAPTURE_DEVICE" appearance light
xcrun simctl status_bar "$CAPTURE_DEVICE" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
SCREENSHOT_UDID="$CAPTURE_DEVICE" SCREENSHOT_OUT="$PWD/docs/product/marketing/2026-10-09/raw" \
  flutter drive --no-pub -d "$CAPTURE_DEVICE" --driver=tool/marketing/capture_driver.dart --target=tool/marketing/capture_app.dart
