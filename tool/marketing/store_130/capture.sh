#!/bin/zsh
# 1.4.0: build 7 only, dedicated job simulators, no uninstall/erase.
set -euo pipefail
cd "$(dirname "$0")/../../.."
FAMILY=${1:?Use iphone or ipad}
LANGUAGE=${2:?Use en, tr, de, es, pt-BR, ja, ko or ar}
MODE=${3:-full}
[[ "$(git rev-parse --short HEAD)" == c37757a ]] || { print -u2 'Capture requires detached build 7 c37757a'; exit 2; }
[[ "$(git symbolic-ref -q HEAD || true)" == '' ]] || exit 2
git checkout main -- tool/
SOURCE_DIFF=$(git diff --stat c37757a -- lib ios assets pubspec.yaml)
[[ -z "$SOURCE_DIFF" ]] || { print -u2 "$SOURCE_DIFF"; exit 2; }
print 'Build 7 source check: clean (lib ios assets pubspec.yaml)'
case "$LANGUAGE" in
 en) APPLE_LANGUAGE=en-US; APPLE_LOCALE=en_US ;;
 tr) APPLE_LANGUAGE=tr; APPLE_LOCALE=tr_TR ;;
 de) APPLE_LANGUAGE=de; APPLE_LOCALE=de_DE ;;
 es) APPLE_LANGUAGE=es-MX; APPLE_LOCALE=es_MX ;;
 pt-BR) APPLE_LANGUAGE=pt-BR; APPLE_LOCALE=pt_BR ;;
 ja) APPLE_LANGUAGE=ja; APPLE_LOCALE=ja_JP ;;
 ko) APPLE_LANGUAGE=ko; APPLE_LOCALE=ko_KR ;;
 ar) APPLE_LANGUAGE=ar; APPLE_LOCALE=ar_SA ;;
 *) exit 2 ;;
esac
case "$FAMILY" in
 iphone) CAPTURE_DEVICE=4B3BE06E-07D8-4449-8FCB-DA1F2794FC02 ;;
 ipad) CAPTURE_DEVICE=790AEE6E-7212-4829-A190-C96C31826B75 ;;
 *) exit 2 ;;
esac
if ! xcrun simctl list devices booted | rg -q "$CAPTURE_DEVICE"; then
 xcrun simctl boot "$CAPTURE_DEVICE"
fi
xcrun simctl bootstatus "$CAPTURE_DEVICE" -b
xcrun simctl spawn "$CAPTURE_DEVICE" defaults write -g AppleLanguages -array "$APPLE_LANGUAGE"
xcrun simctl spawn "$CAPTURE_DEVICE" defaults write -g AppleLocale -string "$APPLE_LOCALE"
xcrun simctl shutdown "$CAPTURE_DEVICE"
xcrun simctl boot "$CAPTURE_DEVICE"
xcrun simctl bootstatus "$CAPTURE_DEVICE" -b
xcrun simctl ui "$CAPTURE_DEVICE" appearance light
xcrun simctl status_bar "$CAPTURE_DEVICE" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
EXTRA_DEFINES=()
# A universal simulator app may be reused only when the capture sources match.
RIG_HASH=$(shasum -a 256 tool/marketing/store_130/capture_app.dart tool/screenshots/seed.dart pubspec.lock | shasum -a 256 | cut -d' ' -f1)
STAMP=build/ios/store-140-rig.sha256
if [[ "$MODE" == full && -f "$STAMP" && "$(cat "$STAMP")" == "$RIG_HASH" && -d build/ios/iphonesimulator/Runner.app ]]; then
 EXTRA_DEFINES+=(--use-application-binary="$PWD/build/ios/iphonesimulator/Runner.app")
 print 'Reusing the identical build 7 capture binary'
fi
[[ "$MODE" != onboarding ]] || EXTRA_DEFINES+=(--dart-define=CAPTURE_ONBOARDING_ONLY=true)
SCREENSHOT_UDID="$CAPTURE_DEVICE" SCREENSHOT_FAMILY="$FAMILY" SCREENSHOT_MODE="$MODE" SCREENSHOT_LANGUAGE="$LANGUAGE" \
 SCREENSHOT_OUT="${STORE_CAPTURE_OUT:-/private/tmp/grammarlens-140-captures/$LANGUAGE/raw/$FAMILY}" \
 flutter drive --no-pub -d "$CAPTURE_DEVICE" "${EXTRA_DEFINES[@]}" \
 --driver=tool/marketing/store_130/capture_driver.dart \
 --target=tool/marketing/store_130/capture_app.dart

[[ "$MODE" != full ]] || print -r -- "$RIG_HASH" > "$STAMP"
