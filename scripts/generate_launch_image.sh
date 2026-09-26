#!/usr/bin/env bash
set -euo pipefail

# Regenerates the iOS static launch image (LaunchImage.imageset) from the
# app's own logo widget (lib/widgets/launch_splash.dart's LaunchLogo, drawn
# by BrandMark), at the launch splash's first-frame scale: @1x/@2x/@3x, a
# light and a dark variant, and the asset catalog's Contents.json.
#
# Run it again whenever BrandMark, its colors or LaunchSplashLayout change;
# test/launch_image_test.dart fails if the images and the layout disagree.
#
# cd's to the repo root first so this works regardless of the caller's
# current directory (same convention as scripts/dev.sh).
cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter test tool/launch_image/generate_launch_image_test.dart
rm -f ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md
echo "Launch image written to ios/Runner/Assets.xcassets/LaunchImage.imageset"
