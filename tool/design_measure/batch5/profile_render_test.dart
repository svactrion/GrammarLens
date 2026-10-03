// Batch 5 step 4 (N17): the real MonthlyMedalCollection, at Profile's
// width, with sample months: November 2026 running (Ember Peak, Silver
// reached), October Gold (Green Slope, stored), September Bronze and August
// no medal (before themes were stored: Green Slope), the Welcome badge
// earned. 320 / 375 / 430 pt, light and dark, Small / Medium / Large (only
// through buildAppTheme(textSize:)). One PNG per combination and
// profile_numbers.txt (the collection's height).
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch5_profile \
//     flutter test tool/design_measure/batch5/profile_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py profile
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir, writePng;

MonthlyMedalResult _result(int month, int score) => MonthlyMedalResult(
    year: 2026,
    month: month,
    score: score,
    maxScore: MonthlyMedalRules.maxScore(2026, month),
    activeDays: 20,
    correct: 0,
    wrong: 0,
    skipped: 0,
    tier: MonthlyMedalRules.tierFor(year: 2026, month: month, score: score),
    ruleVersion: 1,
    finalizedAt: DateTime(2026, month + 1, 1));

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/profile_numbers.txt').writeAsStringSync([
        'Batch 5 step 4 (N17): the real MonthlyMedalCollection at Profile\'s '
            'width (the list\'s padding: 4.5 % of the width, 16-28 pt). '
            'Height in points; light and dark lay out the same.',
        '',
        'width  text    height',
        ...rows,
      ].join('\n')));

  for (final w in [320.0, 375.0, 430.0]) {
    for (final b in Brightness.values) {
      for (final size in AppTextSize.values) {
        final name = 'profile_${w.toInt()}_${b.name}_${size.name}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = Size(w, 1400) * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          final collection = GlobalKey();
          final hPad = (w * 0.045).clamp(16.0, 28.0);
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(b, textSize: size),
            home: Builder(
              builder: (context) => Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: key,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: SizedBox(
                        width: w,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
                          // Unbounded in height, as in Profile's list.
                          child: UnconstrainedBox(
                            constrainedAxis: Axis.horizontal,
                            alignment: Alignment.topLeft,
                            child: MonthlyMedalCollection(
                              key: collection,
                              welcomeBadge: WelcomeBadge(
                                  earnedAt: DateTime(2026, 8, 3),
                                  ruleVersion: 1,
                                  backfilled: false),
                              currentProgress: MonthlyMedalProgress(
                                  year: 2026,
                                  month: 11,
                                  score: 160,
                                  maxScore:
                                      MonthlyMedalRules.maxScore(2026, 11),
                                  activeDays: 18,
                                  correct: 0,
                                  wrong: 0,
                                  skipped: 0),
                              results: [
                                _result(10, 251),
                                _result(9, 96),
                                _result(8, 41)
                              ],
                              themeIds: const {
                                (2026, 11): 'ember_peak',
                                (2026, 10): 'green_slope',
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
          expect(tester.takeException(), isNull);
          if (b == Brightness.light) {
            rows.add('${w.toInt().toString().padRight(6)} '
                '${size.name.padRight(7)} '
                '${tester.getSize(find.byKey(collection)).height.toStringAsFixed(1)}');
          }
          await writePng(tester, key, '$out/$name.png');
        });
      }
    }
  }
}
