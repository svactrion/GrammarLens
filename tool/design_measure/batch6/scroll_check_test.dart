// Batch 6 step 5's stop condition (M10): after Home scrolls to the climb
// card for the month card, is the Daily Test entry (the Today card) still
// on screen? Real Home (shell, HomeScreen) at 320 × 568, 375 × 812 and
// 430 × 932, Small / Medium / Large (buildAppTheme(textSize:) only), light.
//
// Two scrolls:
// - card:  the climb card's top at the top of the list (M10 as written;
//          Batch 0's "scrolled to the card");
// - today: the Today card's top at the top of the list (the smallest
//          scroll that keeps the Daily Test entry whole), for comparison;
// - peek:  "card", then 68 pt back up: the Today card's last 56 pt (a
//          44 pt tap target plus margin) show above the climb card's 12 pt
//          gap, for comparison.
//
// For each: the Today card's visible height (between the list's top and
// the floating tab bar), and, with Batch 0's fullest summary-card
// prototype open as a modal sheet, how much of the 350 pt mountain window
// shows above the sheet and whether the avatar on START (K-c, 298.5 pt
// into the window) does. Writes scroll_check.txt and, at Medium, PNGs.
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch6_scroll \
//     flutter test tool/design_measure/batch6/scroll_check_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;
import 'month_card_prototype.dart';

const _screens = [
  (320.0, 568.0, 20.0, 0.0),
  (375.0, 812.0, 47.0, 34.0),
  (430.0, 932.0, 59.0, 34.0),
];

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/scroll_check.txt').writeAsStringSync([
        'Batch 6 step 5 stop condition: the Daily Test entry after the '
            'scroll (real Home, light; points).',
        'visible area: from the list\'s top to the floating tab bar\'s top. '
            'Today: the Today card\'s visible height / its height. Window: the '
            'mountain window shown above Batch 0\'s fullest summary-card sheet. '
            'START: the K-c avatar above that sheet.',
        '',
        'screen    text    scroll  visible area  Today visible  window above sheet  START',
        ...rows,
      ].join('\n')));

  final theme = ClimbThemeRotation.shownFor(2026, 11);
  final summary = SummaryData(
      month: 'October',
      nextMonth: 'November',
      tier: MedalTier.silver,
      steps: 24,
      days: 31,
      points: 228,
      nearMiss: (MedalTier.gold, 5),
      nextTheme: theme);

  for (final (w, h, top, bottom) in _screens) {
    for (final size in AppTextSize.values) {
      for (final scroll in ['card', 'peek', 'today']) {
        final name = 'scroll_${w.toInt()}_${size.name}_$scroll';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = Size(w, h) * 2;
          tester.view.devicePixelRatio = 2;
          tester.view.padding =
              FakeViewPadding(top: top * 2, bottom: bottom * 2);
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
              key: key,
              child: designHome(
                  clock: DateTime(2026, 11, 1, 9),
                  storage: DesignStorage(steps: 0),
                  textSize: size)));
          await tester.pump(const Duration(seconds: 1));
          final today = find
              .ancestor(
                  of: find.text('Daily Test'), matching: find.byType(Card))
              .first;
          await Scrollable.ensureVisible(tester
              .element(scroll == 'today' ? today : find.byType(ClimbCard)));
          await tester.pumpAndSettle();
          if (scroll == 'peek') {
            final position =
                Scrollable.of(tester.element(find.byType(ClimbCard))).position;
            position.jumpTo((position.pixels - 68).clamp(0.0, position.pixels));
            await tester.pumpAndSettle();
          }
          final list = tester.getRect(find.byType(Scrollable).first);
          final bar = tester.getRect(find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_FloatingNavBar'));
          final areaTop = list.top, areaBottom = bar.top;
          final t = tester.getRect(today);
          final todayShown = (t.bottom.clamp(areaTop, areaBottom) -
                  t.top.clamp(areaTop, areaBottom))
              .clamp(0.0, t.height);
          final window = tester.getRect(find.byType(MonthlyMountain));
          final context = tester.element(find.byType(ClimbCard));
          showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => sheetBody(SummaryCard(data: summary)));
          await tester.pumpAndSettle();
          final sheet = tester.getRect(find.byType(BottomSheet));
          final above = (sheet.top.clamp(window.top, window.bottom) -
                  window.top.clamp(areaTop, h))
              .clamp(0.0, 350.0);
          String f(double v) => v.toStringAsFixed(1);
          rows.add('${'${w.toInt()}×${h.toInt()}'.padRight(9)} '
              '${size.name.padRight(6)}  ${scroll.padRight(6)}  '
              '${'${f(areaTop)}–${f(areaBottom)}'.padLeft(12)}  '
              '${'${f(todayShown)} / ${f(t.height)}'.padLeft(13)}  '
              '${'${f(above)} (${(above * 100 / 350).round()} %)'.padLeft(18)}  '
              '${window.top + 298.5 < sheet.top ? 'yes' : 'no'}');
          if (size != AppTextSize.medium) return;
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            File('$out/$name.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        });
      }
    }
  }
}
