// Batch 6 step B: the real month card (MonthCardSheet, opened by Home
// itself through MonthTransition) over the real Home, after the M21 scroll,
// with the climb card in K-c behind the sheet's barrier. 1 November 2026
// (Ember Peak). Summary card at its fullest (Silver, steps, points, the
// near-miss line, next month and theme, the button) and the fresh-start
// card; 320 × 568, 375 × 812, 430 × 932 (safe areas 20/0, 47/34, 59/34);
// light and dark; Small / Medium / Large (buildAppTheme(textSize:) only).
// Writes one PNG per combination (2x) and month_card_real_numbers.txt.
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch6_card \
//     flutter test tool/design_measure/batch6/month_card_real_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch6_card_sheet.py
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;

/// A returning user on 1 November 2026: October with [steps] steps and
/// [score] points (frozen), or no step (fresh start).
class _CardStorage extends StorageService {
  final int steps, score;
  _CardStorage({required this.steps, required this.score});

  @override
  Future<bool> hasOneTimeFlag(String key) async => false;
  @override
  Future<bool> claimOneTimeFlag(String key) async => true;
  @override
  Future<bool> hasClimbHistoryBefore(int year, int month) async => true;
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: month == 10 ? steps : 0, correct: 0, wrong: 0, skipped: 0);
  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => [
        MonthlyMedalResult(
            year: 2026,
            month: 10,
            score: score,
            maxScore: MonthlyMedalRules.maxScore(2026, 10),
            activeDays: steps,
            correct: 0,
            wrong: 0,
            skipped: 0,
            tier:
                MonthlyMedalRules.tierFor(year: 2026, month: 10, score: score),
            ruleVersion: 1,
            finalizedAt: DateTime(2026, 11, 1)),
      ];
  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => null;
  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => null;
  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      const [];
}

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
  tearDownAll(() => File('$out/month_card_real_numbers.txt').writeAsStringSync([
        'Batch 6 step B: the real month card over the real Home after the M21 '
            'scroll (1 November 2026, Ember Peak). Points.',
        'sheet: top and height (share of the screen); content: the card\'s '
            'natural height; room: what the sheet gives it (default modal '
            'sheet, at most 9/16 of the screen); scroll: content > room; '
            'Today: the Today card\'s height showing between the list top and '
            'the tab bar; window: the 350 pt mountain window showing above the '
            'sheet (and below the list top); START: the K-c avatar (298.5 pt '
            'into the window) above the sheet.',
        '',
        'card     screen    mode  text    sheet top  sheet h (share)  content  room   scroll  overflow  Today  window above sheet  START',
        ...rows,
      ].join('\n')));

  for (final card in ['summary', 'fresh']) {
    for (final (w, h, top, bottom) in _screens) {
      for (final b in Brightness.values) {
        for (final size in AppTextSize.values) {
          final name = 'card_${card}_${w.toInt()}_${b.name}_${size.name}';
          testWidgets(name, (tester) async {
            tester.view.physicalSize = Size(w, h) * 2;
            tester.view.devicePixelRatio = 2;
            tester.view.padding =
                FakeViewPadding(top: top * 2, bottom: bottom * 2);
            addTearDown(tester.view.reset);
            final key = GlobalKey();
            // Silver at 228 of 310: 5 short of Gold, the near-miss line.
            final storage = card == 'summary'
                ? _CardStorage(steps: 24, score: 228)
                : _CardStorage(steps: 0, score: 0);
            await tester.pumpWidget(RepaintBoundary(
                key: key,
                child: designHome(
                    clock: DateTime(2026, 11, 1, 9),
                    storage: storage,
                    brightness: b,
                    textSize: size)));
            await tester.runAsync(() async {
              await Future.wait([
                for (final asset in [
                  Avatar.values.first.assetPath,
                  ClimbThemes.emberPeak.backgroundFor(b),
                  for (final p in ClimbSavePoints.all) p.asset,
                  ClimbSavePoints.assetFor('summit_flag'),
                ])
                  precacheImage(AssetImage(asset), key.currentContext!),
              ]);
            });
            await tester.pumpAndSettle();
            final exceptions = <Object>[];
            for (Object? e = tester.takeException();
                e != null;
                e = tester.takeException()) {
              exceptions.add(e);
            }
            expect(find.byType(MonthCardSheet), findsOneWidget);
            final sheet = tester.getRect(find.byType(BottomSheet));
            final content =
                tester.getSize(find.byKey(MonthCardSheet.contentKey)).height;
            final room =
                tester.getSize(find.byKey(MonthCardSheet.scrollKey)).height;
            final scrolls = tester
                    .state<ScrollableState>(find.descendant(
                        of: find.byKey(MonthCardSheet.scrollKey),
                        matching: find.byType(Scrollable)))
                    .position
                    .maxScrollExtent >
                0;
            final list = tester.getRect(find
                .ancestor(
                    of: find.byType(ClimbCard),
                    matching: find.byType(Scrollable))
                .first);
            final bar = tester.getRect(find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_FloatingNavBar'));
            final today = tester.getRect(find
                .ancestor(
                    of: find.text('Daily Test'), matching: find.byType(Card))
                .first);
            final todayShown = (today.bottom.clamp(list.top, bar.top) -
                    today.top.clamp(list.top, bar.top))
                .clamp(0.0, today.height);
            final window = tester.getRect(find.byType(MonthlyMountain));
            final above = (sheet.top.clamp(window.top, window.bottom) -
                    window.top.clamp(list.top, h))
                .clamp(0.0, 350.0);
            String f(double v) => v.toStringAsFixed(1);
            rows.add(
                '${card.padRight(8)} ${'${w.toInt()}×${h.toInt()}'.padRight(9)} '
                '${b.name.padRight(5)} ${size.name.padRight(6)}  '
                '${f(sheet.top).padLeft(9)}  '
                '${'${f(sheet.height)} (${(sheet.height * 100 / h).round()} %)'.padLeft(15)}  '
                '${f(content).padLeft(7)}  ${f(room).padLeft(5)}  '
                '${(scrolls ? 'yes' : 'no').padLeft(6)}  '
                '${(exceptions.isEmpty ? 'none' : '${exceptions.length}').padLeft(8)}  '
                '${f(todayShown).padLeft(5)}  '
                '${'${f(above)} (${(above * 100 / 350).round()} %)'.padLeft(18)}  '
                '${window.top + 298.5 < sheet.top ? 'yes' : 'no'}');
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
