// Batch 3b report, R5: header text widths at each text size.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';
import 'layouts.dart';

void main() {
  setUpAll(loadFont);
  final out = StringBuffer();
  tearDownAll(() =>
      File('${outDir()}/header_width.txt').writeAsStringSync(out.toString()));
  for (final ts in AppTextSize.values) {
    testWidgets('$ts', (tester) async {
      final theme = buildAppTheme(Brightness.light, textSize: ts);
      for (final t in [
        'Monthly Climb · September 2026',
        'Mountain of Learning · September 2026',
        'Mountain of Learning · October 2026',
        '31 / 31 steps'
      ]) {
        final tp = TextPainter(
            text: TextSpan(
                text: t,
                style: t.contains('steps')
                    ? theme.textTheme.labelLarge
                    : theme.textTheme.titleMedium),
            textDirection: TextDirection.ltr)
          ..layout();
        out.writeln(
            '${ts.name} "$t" width ${tp.width.toStringAsFixed(1)} height ${tp.height.toStringAsFixed(1)}');
      }
    });
  }
}
