#!/usr/bin/env bash
set -euo pipefail

# Runs lib/preview/monthly_medal_preview.dart directly — a standalone,
# debug-only visual fixture for every Monthly Medal state (In progress,
# each finalized tier, "No medal", several finalized months at once), with
# its own dark-mode toggle and Small/Medium/Large text-size control. See
# that file's own doc comment and docs/gamification-handoff.md §9/§10.5.
#
# Deliberately does not initialize StorageService or any other app
# service — no config/dev.json, no proxy, no signed-in account needed, and
# nothing it does can read or write a real device's grammar_lens.db.
#
# cd's to the repo root first so this works regardless of the caller's
# current directory (same convention as scripts/dev.sh).
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Run `flutter devices` first to find a physical iPhone's id if you have
# more than one device/simulator attached — pass it as -d <device-id>.
# Any extra arguments (e.g. -d <device-id>, --release) pass straight
# through to `flutter run`.
flutter run -t lib/preview/monthly_medal_preview.dart "$@"
