// Batch 5 step 6 (N33, N34): the real MonthlyMedalCollection, the shelf and
// the running month's bar, at Profile's width, in three cases:
//   empty   only the running month (November 2026, Ember Peak, no tier
//           yet: its Bronze faded), the Welcome badge locked;
//   three   the Welcome badge earned, September Bronze (Green Slope, before
//           themes were stored), October Gold (Red Canyon), November running
//           at Silver (Ember Peak); August finalized without a medal, so
//           not on the shelf;
//   twelve  the Welcome badge, December 2025 to October 2026 finalized with
//           every tier and theme, November running: twelve months.
// 320 / 375 / 430 pt, light and dark, Medium text, and the twelve months at
// 320 in Small and Large (only through buildAppTheme(textSize:)). Then the
// detail open on October Gold and on the running month, on a whole screen
// (320 x 568, 375 x 812, 430 x 932), light and dark. One PNG per image and
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

MonthlyMedalResult _result(int year, int month, int score,
        {int activeDays = 20}) =>
    MonthlyMedalResult(
        year: year,
        month: month,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(year, month),
        activeDays: activeDays,
        correct: 0,
        wrong: 0,
        skipped: 0,
        tier: MonthlyMedalRules.tierFor(year: year, month: month, score: score),
        ruleVersion: 1,
        finalizedAt: DateTime(year, month + 1, 1));

MonthlyMedalProgress _november(int score, int activeDays) =>
    MonthlyMedalProgress(
        year: 2026,
        month: 11,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(2026, 11),
        activeDays: activeDays,
        correct: 0,
        wrong: 0,
        skipped: 0);

final _welcome = WelcomeBadge(
    earnedAt: DateTime(2026, 8, 3), ruleVersion: 1, backfilled: false);

const _themes = [
  'green_slope', 'ember_peak', 'glacier_peak', 'red_canyon', //
];

/// The three cases.
final _cases = <String, MonthlyMedalCollection>{
  'empty': MonthlyMedalCollection(
    currentProgress: _november(30, 3),
    themeIds: const {(2026, 11): 'ember_peak'},
  ),
  'three': MonthlyMedalCollection(
    welcomeBadge: _welcome,
    currentProgress: _november(160, 18),
    results: [
      _result(2026, 10, 251, activeDays: 27),
      _result(2026, 9, 96),
      _result(2026, 8, 41),
    ],
    themeIds: const {
      (2026, 11): 'ember_peak',
      (2026, 10): 'red_canyon',
    },
  ),
  'twelve': MonthlyMedalCollection(
    welcomeBadge: _welcome,
    currentProgress: _november(160, 18),
    results: [
      for (var i = 0; i < 11; i++)
        _result(
            2025 + (i + 11) ~/ 12, (i + 11) % 12 + 1, [96, 170, 251][i % 3]),
    ],
    themeIds: {
      for (var i = 0; i < 11; i++)
        (2025 + (i + 11) ~/ 12, (i + 11) % 12 + 1): _themes[i % 4],
      (2026, 11): 'ember_peak',
    },
  ),
};

final _screens = {320.0: 568.0, 375.0: 812.0, 430.0: 932.0};

Future<void> _precache(WidgetTester tester, BuildContext context) => tester
    .runAsync(() => Future.wait([
          for (final t in ClimbThemes.all)
            for (final tier in MedalTier.values)
              precacheImage(AssetImage(MedalArt.monthly(t.id, tier)), context),
          precacheImage(const AssetImage(MedalArt.welcome), context),
        ]))
    .then((_) {});

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/profile_numbers.txt').writeAsStringSync([
        'Batch 5 step 6 (N33, N34): the real MonthlyMedalCollection at '
            'Profile\'s width (the list\'s padding: 4.5 % of the width, '
            '16-28 pt). Height in points; light and dark lay out the same.',
        '',
        'case    width  text    height',
        ...rows,
      ].join('\n')));

  for (final MapEntry(key: name, value: collection) in _cases.entries) {
    for (final w in _screens.keys) {
      for (final b in Brightness.values) {
        for (final size in AppTextSize.values) {
          if (size != AppTextSize.medium && (name != 'twelve' || w != 320)) {
            continue;
          }
          final file = 'profile_${name}_${w.toInt()}_${b.name}_${size.name}';
          testWidgets(file, (tester) async {
            tester.view.physicalSize = Size(w, 1400) * 2;
            tester.view.devicePixelRatio = 2;
            addTearDown(tester.view.reset);
            final key = GlobalKey();
            final box = GlobalKey();
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
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        child: SizedBox(
                          width: w,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
                            // Unbounded in height, as in Profile's list.
                            child: UnconstrainedBox(
                              constrainedAxis: Axis.horizontal,
                              alignment: Alignment.topLeft,
                              child: KeyedSubtree(key: box, child: collection),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ));
            await _precache(tester, key.currentContext!);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (b == Brightness.light) {
              rows.add(
                  '${name.padRight(7)} ${w.toInt().toString().padRight(6)} '
                  '${size.name.padRight(7)} '
                  '${tester.getSize(find.byKey(box)).height.toStringAsFixed(1)}');
            }
            await writePng(tester, key, '$out/$file.png');
          });
        }
      }
    }
  }

  // The detail open, on a whole screen.
  for (final (slot, label) in [
    (MonthlyMedalCollection.slotKey(2026, 10), 'october'),
    (MonthlyMedalCollection.slotKey(2026, 11), 'running'),
  ]) {
    for (final MapEntry(key: w, value: h) in _screens.entries) {
      for (final b in Brightness.values) {
        final file = 'profile_detail_${label}_${w.toInt()}_${b.name}';
        testWidgets(file, (tester) async {
          tester.view.physicalSize = Size(w, h) * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(b),
            builder: (context, child) =>
                RepaintBoundary(key: key, child: child),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all((w * 0.045).clamp(16.0, 28.0)),
                child: _cases['three']!,
              ),
            ),
          ));
          await _precache(tester, key.currentContext!);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(slot));
          await tester.pumpAndSettle();
          expect(find.byKey(MonthlyMedalCollection.detailKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          await writePng(tester, key, '$out/$file.png');
        });
      }
    }
  }
}
