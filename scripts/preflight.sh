#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Pre-launch checks before taking a release/submission build (see README's
# "Local setup" section: run this before `flutter build ipa`). Only one
# check today; more pre-launch gates land here over time rather than each
# living as its own separate script.

app_links_file="lib/utils/app_links.dart"
failed=0

check_app_link() {
  local field="$1"
  local value
  value=$(grep -o "$field = '[^']*'" "$app_links_file" | sed -E "s/.*= '([^']*)'/\1/")
  if [[ -z "$value" ]]; then
    echo "✗ AppLinks.$field is empty — set a real hosted URL in $app_links_file before a release build."
    failed=1
  else
    echo "✓ AppLinks.$field = $value"
  fi
}

check_app_link "privacyPolicyUrl"
check_app_link "termsUrl"

if [[ "$failed" -ne 0 ]]; then
  echo
  echo "Preflight failed — fix the above before running flutter build ipa."
  exit 1
fi

echo
echo "Preflight passed."
