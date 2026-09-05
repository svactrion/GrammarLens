#!/usr/bin/env bash
set -euo pipefail

# Runs the app with the local Anthropic API key from config/dev.json (see
# README's "Local setup" section). cd's to the repo root first so this
# works regardless of the caller's current directory.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter run --dart-define-from-file=config/dev.json "$@"
