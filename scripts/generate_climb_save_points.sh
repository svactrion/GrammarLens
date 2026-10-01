#!/usr/bin/env bash
set -euo pipefail

# Regenerates lib/widgets/monthly_climb/climb_save_point_table.dart (the
# save points on their clearings, the summit flag, the objects' aspects and
# the dark-mode gain) from docs/design/scene-art/stage2/placement.json and
# objects.json (tool/scene_art/place_save_points.py, export_objects.py).
# test/climb_save_point_table_test.dart fails until the table matches them.
cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter test tool/climb_table/generate_climb_save_points_test.dart
echo "Save point table written to lib/widgets/monthly_climb/climb_save_point_table.dart"
