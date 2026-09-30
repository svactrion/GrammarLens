// Home's vertical layout at each screen size and text size (Batch 0 item 13,
// Batch 3b report R4).
//
// Text size is applied the way the app applies it, through
// buildAppTheme(textSize:), and nowhere else: no MediaQuery.textScaler on
// top. (Batch 3a's tool added one and measured every size one step too
// large; see the Batch 3b report, R4.)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'home_fakes.dart';
import 'layouts.dart';

/// Inputs, the same as Batch 0 unless overridden: `DESIGN_MEASURE_CLOCK`
/// (ISO date-time, default 2026-09-15T09:00), `DESIGN_MEASURE_STEPS`
/// (default 8) and `DESIGN_MEASURE_NAME` (below).
final _clock = DateTime.parse(
    Platform.environment['DESIGN_MEASURE_CLOCK'] ?? '2026-09-15T09:00:00');
final _steps = int.parse(Platform.environment['DESIGN_MEASURE_STEPS'] ?? '8');

/// The user's name, `DESIGN_MEASURE_NAME` (default "Ada").
final _name = Platform.environment['DESIGN_MEASURE_NAME'] ?? 'Ada';

String _f(double v) => v.toStringAsFixed(1);
String _r(Rect r) => '${_f(r.top)}..${_f(r.bottom)}';

/// Screen sizes with their status bar / home indicator insets.
const screens = [
  (Size(320, 568), 20.0, 0.0),
  (Size(375, 667), 20.0, 0.0),
  (Size(375, 812), 44.0, 34.0),
  (Size(430, 932), 59.0, 34.0),
];

void main() {
  final out = StringBuffer();
  setUpAll(loadFont);
  tearDownAll(() =>
      File('${outDir()}/home_layout.txt').writeAsStringSync(out.toString()));
  for (final (size, top, bottom) in screens) {
    for (final ts in AppTextSize.values) {
      testWidgets('$size ${ts.name}', (tester) async {
        tester.view.physicalSize = size * 3.0;
        tester.view.devicePixelRatio = 3.0;
        tester.view.padding =
            FakeViewPadding(top: top * 3.0, bottom: bottom * 3.0);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(designHome(
            clock: _clock,
            storage: DesignStorage(steps: _steps),
            textSize: ts,
            userName: _name));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        Rect r(Finder x) => tester.getRect(x.first);
        final titleFinder =
            find.textContaining('Mountain of Learning').evaluate().isNotEmpty
                ? find.textContaining('Mountain of Learning')
                : find.textContaining('Monthly Climb');
        final title = r(titleFinder);
        final steps = r(find.textContaining(' steps'));
        final today = r(find.ancestor(
            of: find.text('Daily Test'), matching: find.byType(Card)));
        final mountain = r(find.byType(MonthlyMountain));
        final fold = r(find.byType(BackdropFilter)).top;
        final avatar = r(find.descendant(
            of: find.byType(MonthlyMountain), matching: find.byType(Image)));
        // One day's step on screen: the median distance between two
        // consecutive days of this month, at the scene's scale (the avatar
        // image is 58 scene units wide).
        final days = DateTime(_clock.year, _clock.month + 1, 0).day;
        final route = ClimbRoute(days);
        final chords = [
          for (var d = 1; d <= days; d++)
            (route.pointAt(d.toDouble()) - route.pointAt(d - 1.0)).distance
        ]..sort();
        final dailyStep = chords[days ~/ 2] * avatar.width / 58;
        out.writeln('${size.width.toInt()}x${size.height.toInt()} '
            '${ts.name.padRight(6)} '
            'todayCard=${_r(today)} header=${_f(title.top)}..${_f(steps.bottom)} '
            'rows=${steps.top > title.top + 2 ? 2 : 1} '
            'mountain=${_f(mountain.left)},${_f(mountain.top)} '
            '${mountain.width.toStringAsFixed(2)}x${_f(mountain.height)} '
            'fold=${_f(fold)} aboveFold=${_f(fold - mountain.top)} '
            'avatarImage=${_f(avatar.width)}x${_f(avatar.height)} '
            'dailyStep=${_f(dailyStep)}');
      });
    }
  }
}
