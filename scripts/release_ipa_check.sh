#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Checks a release IPA after `flutter build ipa --release` and before the
# upload (see "Local setup" in docs/development.md). Prints the version and
# build from the app's Info.plist, and fails if any developer tool's text is
# in the compiled Dart code (App Review audit, finding #10: the tools sit
# behind kDebugMode / kReleaseMode, so a release build should not carry
# them). From 1.5.0 it also fails if the widget extension is missing, if its
# version or build differ from the app's, or if the app or the extension is
# not signed with the shared App Group.
#
# Usage: scripts/release_ipa_check.sh [path/to/App.ipa]
# Without a path it takes the one .ipa in build/ios/ipa/.

# Text that only the debug and profile builds' developer tools show
# (lib/screens/settings_screen.dart, lib/services/subscription_service.dart).
debug_patterns=(
  "Entitlement override"
  "debug preview fixture"
  "Preview pricing"
  "Reset first-launch"
)

# Text every release build carries (ClaudeService's notConfigured message).
# If it is not found, the scan itself is not reading the strings, and an
# empty result would prove nothing.
release_control="Practice is not available right now"

ipa="${1:-}"
if [[ -z "$ipa" ]]; then
  shopt -s nullglob
  candidates=(build/ios/ipa/*.ipa)
  shopt -u nullglob
  if [[ ${#candidates[@]} -ne 1 ]]; then
    echo "✗ Expected exactly one .ipa in build/ios/ipa/, found ${#candidates[@]};" \
      "pass its path: scripts/release_ipa_check.sh path/to/App.ipa"
    exit 1
  fi
  ipa="${candidates[0]}"
fi
if [[ ! -f "$ipa" ]]; then
  echo "✗ $ipa does not exist."
  exit 1
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
unzip -q "$ipa" -d "$work_dir"

app_dir=$(find "$work_dir/Payload" -maxdepth 1 -name '*.app' -type d | head -n 1)
if [[ -z "$app_dir" ]]; then
  echo "✗ No Payload/*.app inside $ipa."
  exit 1
fi

plist="$app_dir/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")
echo "✓ $ipa: version $version, build $build"

# The home-screen widget extension (1.5.0). App Store Connect rejects an
# upload whose extension's version or build differ from the app's, and a
# widget without the shared App Group reads no data. A missing extension
# fails the check: every build from 1.5.0 on carries it.
app_group="group.com.ahmettayfur.grammarlens"
appex="$app_dir/PlugIns/GrammarLensWidgets.appex"
if [[ ! -d "$appex" ]]; then
  echo "✗ $(basename "$app_dir")/PlugIns/GrammarLensWidgets.appex is missing: the widget extension is not in the IPA."
  exit 1
fi
appex_plist="$appex/Info.plist"
appex_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$appex_plist")
appex_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$appex_plist")
if [[ "$appex_version" != "$version" || "$appex_build" != "$build" ]]; then
  echo "✗ Widget extension: version $appex_version, build $appex_build; the app has $version ($build). They must be equal."
  exit 1
fi
echo "✓ Widget extension: version $appex_version, build $appex_build (equal to the app's)"

# The App Group, read from each bundle's signature (an IPA exported for the
# store is signed; an unsigned bundle has nothing to read and fails here).
for bundle in "$app_dir" "$appex"; do
  name=$(basename "$bundle")
  entitlements=$(codesign -d --entitlements - --xml "$bundle" 2>/dev/null || true)
  if [[ "$entitlements" == *"$app_group"* ]]; then
    echo "✓ $name is signed with the App Group $app_group"
  else
    echo "✗ $name: the App Group $app_group is not in its signed entitlements (unsigned, or signed without it)."
    exit 1
  fi
done

binary="$app_dir/Frameworks/App.framework/App"
if [[ ! -f "$binary" ]]; then
  echo "✗ $binary is missing; is this a Flutter release IPA?"
  exit 1
fi

strings_file="$work_dir/strings.txt"
strings -a "$binary" > "$strings_file"

# Dart stores a string that has any character outside Latin-1 as UTF-16
# (the em dash in "… — debug preview fixture"), which `strings` does not
# read; so each pattern is also searched for as UTF-16LE.
binary_contains() {
  local pattern="$1"
  grep -qF -- "$pattern" "$strings_file" && return 0
  perl -0777 -ne '
    BEGIN { $p = shift @ARGV; $u = join("", map { $_ . "\0" } split(//, $p)); }
    exit(index($_, $u) >= 0 ? 0 : 1);
  ' "$pattern" "$binary"
}

if binary_contains "$release_control"; then
  echo "✓ Control string found (\"$release_control\"): the scan reads the binary"
else
  echo "✗ Control string \"$release_control\" not found: the scan cannot be trusted."
  exit 1
fi

failed=0
for pattern in "${debug_patterns[@]}"; do
  if binary_contains "$pattern"; then
    echo "✗ Found \"$pattern\" in App.framework/App: a developer tool's text is in the release build."
    failed=1
  else
    echo "✓ \"$pattern\" not found"
  fi
done

if [[ "$failed" -ne 0 ]]; then
  echo
  echo "Release IPA check failed — do not upload this build."
  exit 1
fi

echo
echo "Release IPA check passed."
