// Writes lib/widgets/monthly_climb/climb_trail_table.dart from the
// extracted trail. Run through scripts/generate_climb_trail.sh, not as part
// of `flutter test` (which only runs test/).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'climb_trail_generator.dart';

void main() {
  test('writes the climb trail table', () {
    File(climbTrailTablePath).writeAsStringSync(generateClimbTrailTable());
  });
}
