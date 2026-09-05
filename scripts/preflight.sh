#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Pre-launch checks before taking a release/submission build (see README's
# "Local setup" section: run this before `flutter build ipa`). More
# pre-launch gates land here over time rather than each living as its own
# separate script.

app_links_file="lib/utils/app_links.dart"
release_config_file="config/prod.json"
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

# The Anthropic API key no longer lives in the client at all (see
# docs/build-log.md's Cloudflare Workers proxy decision) — but a release
# build still needs to know where the proxy is and its app token, via
# --dart-define-from-file=config/prod.json. An empty/missing value here
# means every Daily Test/Topic Practice call in the shipped build fails
# outright, so this is exactly as much a release blocker as the Privacy
# Policy/Terms URLs above.
check_release_config_value() {
  local field="$1"
  if [[ ! -f "$release_config_file" ]]; then
    return
  fi
  local value
  value=$(grep -o "\"$field\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$release_config_file" \
    | sed -E 's/.*: *"([^"]*)"/\1/')
  if [[ -z "$value" ]]; then
    echo "✗ \"$field\" is empty in $release_config_file — fill in the real value before a release build."
    failed=1
  else
    echo "✓ $field is set in $release_config_file"
  fi
}

if [[ ! -f "$release_config_file" ]]; then
  echo "✗ $release_config_file does not exist — copy config/prod.example.json to" \
    "$release_config_file and fill in the real proxy URL/app token before a release build."
  failed=1
else
  check_release_config_value "PROXY_BASE_URL"
  check_release_config_value "APP_TOKEN"
fi

if [[ "$failed" -ne 0 ]]; then
  echo
  echo "Preflight failed — fix the above before running flutter build ipa."
  exit 1
fi

echo
echo "Preflight passed."
