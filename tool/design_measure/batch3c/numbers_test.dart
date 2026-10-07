import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'common.dart';
import 'geometry.dart';
import 'measure.dart';

void main() {
  test('numbers', () {
    final all = {for (final c in candidates) c.id: measureCandidate(c)};
    File('${outDir()}/candidate_numbers.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(all));
  });
}
