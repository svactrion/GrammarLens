#!/usr/bin/env bash
set -euo pipefail

# Regenerates lib/widgets/monthly_climb/climb_trail_table.dart (the trail's
# center line, its horizontal widths and the 28-31-day step table) from the
# trail extracted from Green Slope's image,
# docs/design/scene-art/batch0/trail_green.json (scene art S2, decision D3).
#
# Run it again whenever that JSON changes (tool/scene_art/extract_trail.py);
# test/climb_trail_table_test.dart fails until the table matches it.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter test tool/climb_table/generate_climb_trail_test.dart
echo "Climb trail table written to lib/widgets/monthly_climb/climb_trail_table.dart"
