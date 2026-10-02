// Batch 6 Batch 0, §5: the month transition card's prototype
// (month_card_prototype.dart) as a real modal bottom sheet over the real
// Home (navigation shell, HomeScreen, ClimbCard), with the climb card
// redrawn in the K-c framing under the sheet's barrier. November 2026
// (Ember Peak), first open of the month, Home scrolled to its top.
//
// Two cards: the summary card at its fullest (Silver, steps, points, the
// near-miss line, the theme name, the button) and the fresh-start card;
// 320 × 568, 375 × 812 and 430 × 932; light and dark; Small, Medium and
// Large text (only through buildAppTheme(textSize:)). Writes one PNG per
// combination (2x) and `month_card_numbers.txt`.
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch6_sheet \
//     flutter test tool/design_measure/batch6/month_card_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch6_sheet_sheet.py
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;
import 'month_card_prototype.dart';

/// Screen sizes with their safe areas (status bar; home indicator).
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
  tearDownAll(() => File('$out/month_card_numbers.txt').writeAsStringSync([
        'Batch 6 Batch 0 §5: the month card prototype as a modal bottom '
            'sheet over the real Home (November 2026, Ember Peak, Home at '
            'its scroll top). All in points.',
        'sheet: the sheet\'s top and height (share of the screen); content: '
            'the card\'s natural height; room: the height the sheet gives it '
            '(default modal sheet, max 9/16 of the screen); scroll: content '
            '> room; window above sheet: how much of the 350 pt mountain '
            'window shows above the sheet; START: whether the avatar on START '
            '(K-c, 298.5 pt into the window) is above the sheet.',
        '',
        'Home  card     screen    mode  text    sheet top  sheet h (share)  '
            'content  room   scroll  overflow  window above sheet  START',
        ...rows,
      ].join('\n')));

  final clock = DateTime(2026, 11, 1, 9);
  final theme = ClimbThemeRotation.shownFor(2026, 11);
  // October 2026: Silver at 228 of 310, 5 short of Gold (233): near-miss
  // candidate A (≤ 5) shows the line (medal_numbers.txt).
  final gold = MonthlyMedalRules.threshold(2026, 10, MedalTier.gold);
  final summary = SummaryData(
      month: 'October',
      nextMonth: 'November',
      tier: MedalTier.silver,
      steps: 24,
      days: 31,
      points: 228,
      nearMiss: (MedalTier.gold, gold - 228),
      nextTheme: theme);

  // top: Home at its scroll top, as it opens. card: Home scrolled so the
  // climb card's top is at the top of the list first (an option, §5).
  for (final scrollTo in ['top', 'card']) {
    for (final card in ['summary', 'fresh']) {
      for (final (w, h, top, bottom) in _screens) {
        for (final b in Brightness.values) {
          for (final size in AppTextSize.values) {
            final name =
                '${card}_${w.toInt()}_${b.name}_${size.name}_scroll$scrollTo';
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
                      clock: clock,
                      storage: DesignStorage(steps: 0),
                      brightness: b,
                      textSize: size)));
              await tester.runAsync(() async {
                await Future.wait([
                  for (final asset in [
                    Avatar.values.first.assetPath,
                    theme.backgroundFor(b),
                    for (final p in ClimbSavePoints.all) p.asset,
                    ClimbSavePoints.assetFor('summit_flag'),
                  ])
                    precacheImage(AssetImage(asset), key.currentContext!),
                ]);
              });
              await tester.pump(const Duration(seconds: 1));
              if (scrollTo == 'card') {
                await Scrollable.ensureVisible(
                    tester.element(find.byType(ClimbCard)));
                await tester.pumpAndSettle();
              }
              final cardRect = tester.getRect(find.byType(ClimbCard));
              final window = tester.getRect(find.byType(MonthlyMountain));
              final context = tester.element(find.byType(ClimbCard));
              showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => sheetBody(card == 'summary'
                      ? SummaryCard(data: summary)
                      : FreshCard(
                          nextMonth: 'November',
                          nextTheme: theme,
                          avatar: Avatar.values.first)));
              await tester.pumpAndSettle();
              // M4: the climb card in K-c, drawn over Home's own and under
              // the sheet's barrier (a route's entries go right above the
              // route below it, so it is placed below the sheet's own).
              final sheetRoute =
                  ModalRoute.of(tester.element(find.byType(BottomSheet)))!
                      as OverlayRoute;
              Overlay.of(context).insert(
                  OverlayEntry(
                      builder: (_) => Positioned(
                          left: cardRect.left,
                          top: cardRect.top,
                          width: cardRect.width,
                          child: kcClimbCard(
                              month: DateTime(2026, 11),
                              theme: theme,
                              avatar: Avatar.values.first,
                              scoreBar: ClimbScoreBar(
                                score: 0,
                                maxScore: MonthlyMedalRules.maxScore(2026, 11),
                                thresholds: {
                                  for (final t in MedalTier.values)
                                    t: MonthlyMedalRules.threshold(2026, 11, t),
                                },
                              )))),
                  below: sheetRoute.overlayEntries.first);
              await tester.pump();
              final exceptions = <Object>[];
              for (Object? e = tester.takeException();
                  e != null;
                  e = tester.takeException()) {
                exceptions.add(e);
              }
              final sheet = tester.getRect(find.byType(BottomSheet));
              final content = tester
                  .getSize(find.byKey(const ValueKey('month_card_content')))
                  .height;
              final room = tester
                  .getSize(find.byKey(const ValueKey('month_card_scroll')))
                  .height;
              final scroll = tester
                  .state<ScrollableState>(find.descendant(
                      of: find.byKey(const ValueKey('month_card_scroll')),
                      matching: find.byType(Scrollable)))
                  .position;
              final above = (sheet.top.clamp(window.top, window.bottom) -
                      window.top.clamp(top, h))
                  .clamp(0.0, 350.0);
              final startVisible = window.top + 298.5 < sheet.top;
              String f(double v) => v.toStringAsFixed(1);
              rows.add(
                  '${scrollTo.padRight(4)}  ${card.padRight(8)} ${'${w.toInt()}×${h.toInt()}'.padRight(9)} '
                  '${b.name.padRight(5)} ${size.name.padRight(6)}  '
                  '${f(sheet.top).padLeft(9)}  '
                  '${'${f(sheet.height)} (${(sheet.height * 100 / h).round()} %)'.padLeft(15)}  '
                  '${f(content).padLeft(7)}  ${f(room).padLeft(5)}  '
                  '${(scroll.maxScrollExtent > 0 ? 'yes' : 'no').padLeft(6)}  '
                  '${(exceptions.isEmpty ? 'none' : '${exceptions.length}').padLeft(8)}  '
                  '${'${f(above)} (${(above * 100 / 350).round()} %)'.padLeft(18)}  '
                  '${startVisible ? 'yes' : 'no'}');
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
  }
}
