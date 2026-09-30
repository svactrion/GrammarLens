import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../tool/climb_table/climb_table_generator.dart' show markerBox;

/// Design decision D2: a stop marker within the month's last 2 steps is not
/// drawn; the summit takes its place.
void main() {
  const expected = {
    28: [7, 14, 21], // day 28 is the summit: the lookout merges with it
    29: [7, 14, 21], // day 28 is 1 step before the summit: hidden
    30: [7, 14, 21], // day 28 is 2 steps before the summit: hidden
    31: [7, 14, 21, 28], // day 28 is 3 steps before the summit: shown
  };

  double distance(Rect r, Offset p) {
    final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
    final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
    return math.sqrt(dx * dx + dy * dy);
  }

  for (final MapEntry(key: days, value: shown) in expected.entries) {
    group('$days-day month', () {
      final route = ClimbRoute(days);

      test('shows the markers on days $shown', () {
        expect([for (final m in route.markers) m.day], shown);
        for (final day in ClimbRoute.markerDays) {
          expect(ClimbRoute.markerShown(day, days), shown.contains(day));
        }
      });

      test('every marker is clear of the trail band and the steps', () {
        final metric = route.path.computeMetrics().single;
        for (final m in route.markers) {
          final box = markerBox.shift(m.origin);
          for (var s = 0.0; s <= metric.length; s += 1) {
            final p = metric.getTangentForOffset(s)!.position;
            expect(distance(box, p), greaterThanOrEqualTo(13 + 4 - .01),
                reason: 'day ${m.day} marker at ${m.origin}');
          }
          for (var d = 0; d <= days; d++) {
            expect(
                box.overlaps(Rect.fromCenter(
                    center: route.stepAt(d), width: 20, height: 13)),
                isFalse,
                reason: 'day ${m.day} marker covers step $d');
          }
        }
      });

      testWidgets('the VoiceOver label names only the shown markers',
          (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: Scaffold(
                body: SizedBox(
                    width: 320,
                    child: MonthlyMountain(
                        days: days,
                        completedDays: 3,
                        avatar: Avatar.values.first)))));
        final label = tester
            .getSemantics(find.byType(MonthlyMountain))
            .getSemanticsData()
            .label;
        expect(label, contains('day 21 mountain cabin'));
        expect(label.contains('lookout terrace'), shown.contains(28));
        expect(label, contains('Summit at $days steps.'));
        semantics.dispose();
      });
    });
  }
}
