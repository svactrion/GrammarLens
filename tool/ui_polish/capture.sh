#!/bin/zsh
# UI polish board gallery capture (PROGRESS.md D0-4).
#
#   tool/ui_polish/capture.sh                 # every board
#   BOARDS=V14-Home,V15-HomeNextDay tool/ui_polish/capture.sh
#   BOARDS=SY03-DarkHome:dark tool/ui_polish/capture.sh
#
# The simulator: UDID or name in UI_SIM (default iPhone 18 Pro, booted).
# PNGs go to build/ui-polish-captures/ (not committed). A debug build, run
# with `flutter drive`; nothing is sent anywhere.
set -euo pipefail
cd "$(dirname "$0")/../.."
SIM="${UI_SIM:-iPhone 18 Pro}"
if [[ "$SIM" =~ ^[0-9A-F-]{36}$ ]]; then UDID="$SIM"; else
  UDID=$(xcrun simctl list devices booted | grep -F "$SIM (" | head -1 | grep -oE '[0-9A-F-]{36}')
fi
[[ -n "${UDID:-}" ]] || { echo "boot the simulator first ($SIM)"; exit 1; }
CAPTURE_UDID="$UDID" CAPTURE_OUT="build/ui-polish-captures" \
  CAPTURE_BOARDS="${BOARDS:-}" \
  flutter drive --no-pub -d "$UDID" \
    --driver=tool/ui_polish/gallery_driver.dart \
    --target=tool/ui_polish/gallery_app.dart
