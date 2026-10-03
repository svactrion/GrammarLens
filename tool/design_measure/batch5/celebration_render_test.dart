// Batch 5 step 5 (N15; N28 since the device check): the real MedalCelebration over the real Daily Test
// result screen, for the Welcome badge and for each tier (October 2026,
// Green Slope; Silver also on Ember Peak), at 320 × 568, 375 × 812 and
// 430 × 932, light and dark, Small / Medium / Large (buildAppTheme
// (textSize:) only), after the opening (confetti finished). Writes one PNG
// per combination and celebration_numbers.txt (the layer's card height
// against the screen).
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch5_celebration \
//     flutter test tool/design_measure/batch5/celebration_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py celebration
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir, writePng;

/// A save that earns the Welcome badge ([welcome]) or crosses [tier] in
/// the set's month.
class _Storage extends StorageService {
  final bool welcome;
  final MedalTier? tier;
  _Storage({this.welcome = false, this.tier});

  @override
  Future<bool> completeDailyTest(
          Map<String, String> answers, List<ErrorEntry> errorEntries,
          {String? day, DateTime? completedAt}) async =>
      welcome;
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
      int year, int month) async {
    final score = MonthlyMedalRules.threshold(year, month, tier!);
    return (steps: 20, correct: score ~/ 2, wrong: score % 2, skipped: 0);
  }

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;
}

class _NoPrefetch extends DailyTestService {
  _NoPrefetch(StorageService storage)
      : super(claudeService: ClaudeService(), storageService: storage);
  @override
  Future<void> prefetchSet(String day) async {}
}

const _screens = {
  '320x568': (320.0, 568.0, 20.0, 0.0),
  '375x812': (375.0, 812.0, 47.0, 34.0),
  '430x932': (430.0, 932.0, 59.0, 34.0),
};

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/celebration_numbers.txt').writeAsStringSync([
        'Batch 5 step 5 (N15): the celebration layer over the real result '
            'screen. The card\'s height and its top and bottom room on the '
            'screen (safe areas included in the screen). Points. Since N28 '
            '"card" is the group of the medal, its rays and the text.',
        '',
        'what            screen    text    card h   room above  room below',
        ...rows,
      ].join('\n')));

  final cases = {
    'welcome': ('2026-10-14', _Storage(welcome: true)),
    'bronze': ('2026-10-14', _Storage(tier: MedalTier.bronze)),
    'silver': ('2026-10-14', _Storage(tier: MedalTier.silver)),
    'gold': ('2026-10-14', _Storage(tier: MedalTier.gold)),
    'silver_ember': ('2026-11-14', _Storage(tier: MedalTier.silver)),
  };
  for (final MapEntry(key: what, value: (day, storage)) in cases.entries) {
    for (final MapEntry(key: screen, value: (w, h, top, bottom))
        in _screens.entries) {
      for (final b in Brightness.values) {
        for (final size in AppTextSize.values) {
          final name = 'celebration_${what}_${screen}_${b.name}_${size.name}';
          testWidgets(name, (tester) async {
            tester.view.physicalSize = Size(w, h) * 2;
            tester.view.devicePixelRatio = 2;
            tester.view.padding =
                FakeViewPadding(top: top * 2, bottom: bottom * 2);
            addTearDown(tester.view.reset);
            final key = GlobalKey();
            await tester.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(b, textSize: size),
                home: DailyTestResultScreen(
                  dailyTestSet: DailyTestSet(
                      day: day,
                      questions: kDayZeroQuestions,
                      source: DailyTestSource.shared),
                  answers: {
                    for (final q in kDayZeroQuestions)
                      q.item.id: q.correctAnswer
                  },
                  dailyTestService: _NoPrefetch(storage),
                  analyticsService: AnalyticsService(),
                  isDay0: what == 'welcome',
                  onDone: () {},
                ),
              ),
            ));
            await tester.runAsync(() => Future.wait([
                  for (final t in ClimbThemes.all)
                    for (final tier in MedalTier.values)
                      precacheImage(AssetImage(MedalArt.monthly(t.id, tier)),
                          key.currentContext!),
                  precacheImage(
                      const AssetImage(MedalArt.welcome), key.currentContext!),
                ]));
            await tester.pumpAndSettle();
            expect(find.byType(MedalCelebration), findsOneWidget);
            expect(tester.takeException(), isNull);
            // N28: the group of medal and text (no card any more).
            final card = tester.getRect(find
                .descendant(
                    of: find.byType(MedalCelebration),
                    matching: find.byType(Column))
                .first);
            if (b == Brightness.light) {
              String f(double v) => v.toStringAsFixed(1).padLeft(7);
              rows.add('${what.padRight(15)} ${screen.padRight(9)} '
                  '${size.name.padRight(7)} ${f(card.height)}  '
                  '${f(card.top - top)}     ${f(h - bottom - card.bottom)}');
            }
            await writePng(tester, key, '$out/$name.png');
          });
        }
      }
    }
  }
}
