// Writes lib/widgets/monthly_climb/climb_table.dart from the frozen curve.
// Run through scripts/generate_climb_table.sh, not as part of `flutter test`
// (which only runs test/).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'climb_table_generator.dart';

void main() {
  test('writes the climb step table', () {
    File(climbTablePath).writeAsStringSync(generateClimbTable());
  });
}
