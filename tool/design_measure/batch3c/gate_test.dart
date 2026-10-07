// Batch 3c K3 gate: the mountain above the fold with the plaque shell,
// before any product change. Measured on the real Home: where the climb
// section starts, where the mountain window starts, and the fold. Only the
// climb section changes (the two header rows give way to a plaque that
// sits half above the frame), so the new window top is the section's top
// plus half the plaque's height, with the plaque measured from the shell at
// that text size.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import 'common.dart';

const _screens = [
  (Size(320, 568), 20.0, 0.0),
  (Size(375, 667), 20.0, 0.0),
  (Size(430, 932), 59.0, 34.0),
];

/// A short name and a long one; 14:00 ("Good afternoon", the longest
/// greeting word). At 320 pt both put the greeting on two lines.
const _names = ['Ada', 'Mary Anne Smith'];

String _f(double v) => v.toStringAsFixed(1);

void main() {
  final out = StringBuffer();
  setUpAll(loadFonts);
  tearDownAll(
      () => File('${outDir()}/gate.txt').writeAsStringSync(out.toString()));
  for (final (size, top, bottom) in _screens) {
    for (final ts in AppTextSize.values) {
      for (final name in _names) {
        testWidgets('${size.width.toInt()} ${ts.name} $name', (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          tester.view.padding =
              FakeViewPadding(top: top * 3, bottom: bottom * 3);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(designHome(
              clock: DateTime(2026, 9, 15, 14),
              storage: DesignStorage(steps: 8),
              textSize: ts,
              userName: name));
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          final sectionTop =
              tester.getRect(find.text('Mountain of Learning')).top;
          final windowTop = tester.getRect(find.byType(MonthlyMountain)).top;
          final fold = tester.getRect(find.byType(BackdropFilter).first).top;
          final theme = Theme.of(tester.element(find.byType(MonthlyMountain)));
          // The shell's plaque and label row, as in shell.dart.
          final plaqueH = (TextPainter(
                      text: TextSpan(
                          text: 'Mountain of Learning',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      textDirection: TextDirection.ltr)
                    ..layout())
                  .height +
              12;
          final labelH = (TextPainter(
                  text: TextSpan(
                      text: 'October',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  textDirection: TextDirection.ltr)
                ..layout())
              .height;
          final newWindowTop = sectionTop + plaqueH / 2;
          // Chip row: 6 pt under the plaque's lower edge, 2 pt chip padding.
          final labelsBottom = newWindowTop + plaqueH / 2 + 6 + labelH + 4;
          double visible(double from) =>
              (fold - from).clamp(0.0, 350.0 - (from - newWindowTop));
          out.writeln('${size.width.toInt()}x${size.height.toInt()} '
              '${ts.name.padRight(6)} ${name.padRight(15)} '
              'now=${_f((fold - windowTop).clamp(0, 350))} '
              'shell=${_f((fold - newWindowTop).clamp(0, 350))} '
              'gain=${_f(windowTop - newWindowTop)} '
              'belowLabels=${_f(visible(labelsBottom))} '
              'plaque=${_f(plaqueH)} fold=${_f(fold)}');
        });
      }
    }
  }
}
