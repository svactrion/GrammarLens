// Batch 3c-B after the build: the real Home and the product's trail.
// - The mountain above the fold, under the gate's conditions (Step 3): the
//   window (fold − window top) and, stricter, below the month/steps chips.
// - The trail at 320 pt (F1): a day's step, the smallest gap between
//   neighbouring step markers, and the days the resting avatar covers
//   another part of the trail (Batch 3a's rule).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import 'common.dart';

const _screens = [
  (Size(320, 568), 20.0, 0.0),
  (Size(375, 667), 20.0, 0.0),
  (Size(430, 932), 59.0, 34.0),
];
const _names = ['Ada', 'Mary Anne Smith'];

String _f(double v) => v.toStringAsFixed(1);

double _rectDistance(Rect r, Offset p) {
  final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
  final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  final fold = StringBuffer(), trail = StringBuffer();
  setUpAll(loadFonts);
  tearDownAll(() {
    File('${outDir()}/after_above_fold.txt').writeAsStringSync(fold.toString());
    File('${outDir()}/after_trail.txt').writeAsStringSync(trail.toString());
  });

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
          final window = tester.getRect(find.byType(MonthlyMountain));
          final foldY = tester.getRect(find.byType(BackdropFilter).first).top;
          final chips = math.max(
              tester.getRect(find.byKey(ClimbCard.monthKey)).bottom,
              tester.getRect(find.byKey(ClimbCard.stepsKey)).bottom);
          fold.writeln('${size.width.toInt()}x${size.height.toInt()} '
              '${ts.name.padRight(6)} ${name.padRight(15)} '
              'window=${_f((foldY - window.top).clamp(0, 350))} '
              'belowChips=${_f((foldY - chips - 2).clamp(0, 350))}');
        });
      }
    }
  }

  test('trail', () {
    const scale = ClimbCamera.windowHeight / ClimbCamera.unitsTall;
    for (final days in [31, 30, 29, 28]) {
      final route = ClimbRoute(days);
      final metric = route.path.computeMetrics().single;
      var gap = double.infinity;
      for (var d = 0; d < days; d++) {
        for (final p in route.stepMarkerOutline(d)) {
          for (final q in route.stepMarkerOutline(d + 1)) {
            gap = math.min(gap, (p - q).distance);
          }
        }
      }
      final covered = <int>[];
      for (var d = 0; d <= days; d++) {
        final box = const Rect.fromLTRB(-29, -55, 29, 3)
            .shift(route.stepAt(d))
            .deflate(4);
        final s0 = metric.length * d / days;
        for (var s = 0.0; s <= metric.length; s += 1) {
          if ((s - s0).abs() < 70) continue;
          if (_rectDistance(box, metric.getTangentForOffset(s)!.position) <
              13) {
            covered.add(d);
            break;
          }
        }
      }
      trail.writeln('$days d: step ${_f(metric.length / days * scale)} pt, '
          'closest neighbouring markers ${(gap * scale).toStringAsFixed(2)} pt, '
          'covered days ${covered.length} $covered');
    }
  });
}
