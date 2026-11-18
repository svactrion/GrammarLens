import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import 'support/fix3_render.dart';

/// Fix round 4, item 4 (SPEC V23 v12): Profile's month progress card at a
/// phone's width in the app's font, light and dark, at 0, mid-month and
/// past each tier. With `FIX4_CAPTURE=1` the renders go to
/// `build/fix4-captures/(dark/)V23-progress-<score>.png`.
void main() {
  MonthlyMedalProgress at(int score) => MonthlyMedalProgress(
        year: 2026,
        month: 11,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(2026, 11),
        activeDays: 6,
        correct: 0,
        wrong: 0,
        skipped: 0,
      );

  for (final brightness in Brightness.values) {
    for (final textSize in [AppTextSize.medium, AppTextSize.large]) {
      testWidgets(
          'V23 v12 card, ${brightness.name}, ${textSize.name} text: '
          'nothing overflows at 0, mid-month and every tier', (tester) async {
        for (final score in [0, 42, 80, 160, 240, 300]) {
          await pumpFix3(
              tester,
              Scaffold(
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: MonthlyProgressCard(
                        progress: at(score), theme: ClimbThemes.emberPeak),
                  ),
                ),
              ),
              size: const Size(390, 844),
              brightness: brightness,
              textSize: textSize);
          expect(tester.takeException(), isNull, reason: '$score');
          final card = tester.getRect(find.byKey(MonthlyProgressCard.cardKey));
          for (final tier in MedalTier.values) {
            final mark = tester
                .getRect(find.byKey(MonthlyProgressCard.thresholdKey(tier)));
            expect(mark.left, greaterThanOrEqualTo(card.left));
            expect(mark.right, lessThanOrEqualTo(card.right));
          }
          if (textSize == AppTextSize.medium) {
            await fix4Capture(tester, 'V23-progress-$score',
                dark: brightness == Brightness.dark);
          }
        }
      });
    }
  }
}
