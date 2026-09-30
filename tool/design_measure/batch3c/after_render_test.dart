// Batch 3c-B "after" images: the real Home as it opens (no scroll) and the
// real climb card
// (ClimbCard, MonthlyMountain, ClimbScoreBar), 31-day month, days 3 and 25,
// the snail (the one side-facing avatar), never mirrored (D4, K2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadIconFont, writePng;
import 'common.dart';

final _snail = Avatar.values[1];

Widget _card(double w, int day) => SizedBox(
      width: w,
      child: ClimbCard(
        month: DateTime(2026, 10),
        steps: day,
        days: 31,
        mountain: MonthlyMountain(
            days: 31,
            completedDays: day,
            avatar: _snail,
            allowUserScroll: false),
        scoreBar: ClimbScoreBar(
          score: day * 7,
          maxScore: MonthlyMedalRules.maxScore(2026, 10),
          thresholds: {
            for (final t in MedalTier.values)
              t: MonthlyMedalRules.threshold(2026, 10, t)
          },
        ),
      ),
    );

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFonts();
    await loadIconFont();
  });

  for (final screen in [320.0, 375.0]) {
    for (final b in Brightness.values) {
      final cardName = 'after_card_${screen.toInt()}_${b.name}_31d.png';
      testWidgets(cardName, (tester) async {
        final w = cardWidth(screen);
        final theme = buildAppTheme(b);
        tester.view.physicalSize = Size(2 * (w + 16) + 28, 520) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: theme.colorScheme.surfaceContainerLow,
                padding: const EdgeInsets.all(14),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final day in [3, 25]) ...[
                        SizedBox(
                          width: w,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                    height: 30,
                                    child: Caption(
                                        '${screen.toInt()} pt · ${b.name} · day $day of 31',
                                        theme.colorScheme.onSurface)),
                                _card(w, day),
                              ]),
                        ),
                        const SizedBox(width: 16),
                      ]
                    ]),
              ),
            ),
          ),
        ));
        await tester.runAsync(() =>
            precacheImage(AssetImage(_snail.assetPath), key.currentContext!));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await writePng(tester, key, '$out/$cardName');
      });

      for (final day in [3, 25]) {
        final homeName = 'after_home_${screen.toInt()}_${b.name}_day$day.png';
        testWidgets(homeName, (tester) async {
          final size = Size(screen, screen == 320 ? 568 : 667);
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          tester.view.padding = const FakeViewPadding(top: 60);
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: designHome(
                clock: DateTime(2026, 10, 25, 9),
                storage:
                    DesignStorage(steps: day, correct: day * 3, wrong: day),
                brightness: b,
                avatar: _snail),
          ));
          await tester.runAsync(() =>
              precacheImage(AssetImage(_snail.assetPath), key.currentContext!));
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          await writePng(tester, key, '$out/$homeName');
        });
      }
    }
  }
}
