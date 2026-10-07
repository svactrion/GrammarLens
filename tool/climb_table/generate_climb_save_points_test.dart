// Writes lib/widgets/monthly_climb/climb_save_point_table.dart. Run through
// scripts/generate_climb_save_points.sh, not as part of `flutter test`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'climb_save_point_generator.dart';

void main() {
  test('writes the climb save point table', () {
    File(climbSavePointTablePath)
        .writeAsStringSync(generateClimbSavePointTable());
  });
}
