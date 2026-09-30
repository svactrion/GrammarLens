#!/usr/bin/env bash
set -euo pipefail

# Regenerates lib/widgets/monthly_climb/climb_table.dart, the normalized
# step coordinates for 28-31-day months, from the frozen curve in
# lib/widgets/monthly_climb/climb_route.dart (design decision D3).
#
# Run it again whenever the curve changes; test/climb_table_test.dart fails
# until the table matches the curve.
#
# cd's to the repo root first so this works regardless of the caller's
# current directory (same convention as scripts/dev.sh).
cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter test tool/climb_table/generate_climb_table_test.dart
echo "Climb table written to lib/widgets/monthly_climb/climb_table.dart"
