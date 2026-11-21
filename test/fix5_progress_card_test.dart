import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

import 'support/fix3_render.dart';

/// Fix round 5, item 3 (SPEC V23 "Month progress card (v13)", board V23p,
/// §1.28): the points large with "/ 300" and the distance to the next
/// medal, the 0–300 bar in four parts split at 75 / 150 / 225, the medals
/// standing over the gaps (earned: colour, green ring, tick; not yet:
/// muted, grey ring), their names and points under the bar, the navy dot
/// at the points. With `FIX5_CAPTURE=1` the renders go to
/// `build/fix5-captures/(dark/)V23-progress-<score>.png`.
void main() {
  MonthlyMedalProgress at(int score) => MonthlyMedalProgress(
        year: 2026,
        month: 11,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(2026, 11),
        activeDays: 12,
        correct: 0,
        wrong: 0,
        skipped: 0,
      );

  Widget card(int score) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: MonthlyProgressCard(
                progress: at(score), theme: ClimbThemes.emberPeak),
          ),
        ),
      );

  test('November 2026: 300 points, Bronze 75, Silver 150, Gold 225', () {
    expect(MonthlyMedalRules.maxScore(2026, 11), 300);
    expect(MonthlyProgressCard.bounds(at(0)), [75, 150, 225, 300]);
  });

  // The listed states: (points, the distance line, the medals earned).
  const states = [
    (0, '75 to Bronze', 0),
    (9, '66 to Bronze', 0),
    (75, '75 to Silver', 1),
    (120, '30 to Silver', 1),
    (150, '75 to Gold', 2),
    (225, 'Gold reached', 3),
    (240, 'Gold reached', 3),
    (300, 'Gold reached', 3),
  ];

  for (final brightness in Brightness.values) {
    for (final (score, distance, earned) in states) {
      testWidgets(
          '${brightness.name}, $score points: "$distance", $earned '
          'medal(s) earned, the dot at $score / 300', (tester) async {
        await pumpFix3(tester, card(score), brightness: brightness);
        expect(tester.takeException(), isNull);
        final c = AppColors.of(
            tester.element(find.byKey(MonthlyProgressCard.cardKey)));
        // The points large with "/ 300", the distance under them.
        expect(
            tester
                .widget<Text>(find.byKey(MonthlyProgressCard.pointsKey))
                .textSpan!
                .toPlainText(),
            '$score / 300');
        final line =
            tester.widget<Text>(find.byKey(MonthlyProgressCard.distanceKey));
        expect(line.data, distance);
        expect(line.style!.color, earned == 3 ? c.greenText : c.orangeText);
        // The parts: filled by the points, tinted toward their medal.
        final bar = tester.getRect(find.byKey(MonthlyProgressCard.barKey));
        for (var i = 0; i < MonthlyProgressCard.parts; i++) {
          final part =
              tester.getRect(find.byKey(MonthlyProgressCard.partKey(i)));
          final fill =
              tester.getRect(find.byKey(MonthlyProgressCard.partFillKey(i)));
          final from = i == 0 ? 0 : [75, 150, 225][i - 1];
          final to = [75, 150, 225, 300][i];
          expect(fill.width / part.width,
              closeTo(((score - from) / (to - from)).clamp(0, 1), .02),
              reason: 'part $i');
          final tint = tester
              .widget<ColoredBox>(find.descendant(
                  of: find.byKey(MonthlyProgressCard.partKey(i)),
                  matching: find.byType(ColoredBox)))
              .color;
          expect(tint, MonthlyProgressCard.tint(i, brightness));
        }
        // The medals: earned with a green ring and a tick, the rest muted
        // with a grey ring; the next one's name (and an earned one's) dark.
        final next = earned < 3 ? MedalTier.values[earned] : null;
        for (final (i, tier) in MedalTier.values.indexed) {
          final medal = find.byKey(MonthlyProgressCard.medalKey(tier));
          final isEarned = i < earned;
          expect(find.byKey(MonthlyProgressCard.tickKey(tier)),
              isEarned ? findsOneWidget : findsNothing,
              reason: '$tier tick');
          final ring = tester.widget<Container>(find
              .descendant(of: medal, matching: find.byType(Container))
              .first);
          final border = (ring.decoration! as BoxDecoration).border! as Border;
          expect(border.top.color, isEarned ? c.green : c.line,
              reason: '$tier ring');
          expect(find.descendant(of: medal, matching: find.byType(Opacity)),
              isEarned ? findsNothing : findsOneWidget,
              reason: '$tier muted');
          final name = tester.widget<Text>(find
              .descendant(
                  of: find.byKey(MonthlyProgressCard.labelKey(tier)),
                  matching: find.byType(Text))
              .first);
          expect(name.style!.color, isEarned || tier == next ? c.text : c.muted,
              reason: '$tier name');
          // Over its gap, its name under the bar.
          final place = bar.left + [75, 150, 225][i] / 300 * bar.width;
          expect(tester.getRect(medal).center.dx, closeTo(place, .5));
          final label =
              tester.getRect(find.byKey(MonthlyProgressCard.labelKey(tier)));
          expect(label.center.dx, closeTo(place, .5));
          expect(label.top, greaterThan(bar.top));
        }
        // The dot at the points: navy (light blue in dark).
        final dot = find.byKey(MonthlyProgressCard.dotKey);
        expect(tester.getRect(dot).center.dx,
            closeTo(bar.left + score / 300 * bar.width, .5));
        final dotColor = (tester
                .widget<DecoratedBox>(find.descendant(
                    of: dot, matching: find.byType(DecoratedBox)))
                .decoration as BoxDecoration)
            .color;
        expect(dotColor, brightness == Brightness.dark ? c.navyText : c.navy);
        // The screen reader's label.
        expect(
            find.bySemanticsLabel('$score of 300 points; Bronze at 75, '
                'Silver at 150, Gold at 225'),
            findsOneWidget);
        // No 10-segment bar, no "Monthly total" line.
        expect(find.textContaining('Monthly total'), findsNothing);
        await fix5Capture(tester, 'V23-progress-$score',
            dark: brightness == Brightness.dark);
      });
    }
  }

  for (final textSize in AppTextSize.values) {
    testWidgets('${textSize.name} text: nothing overflows or leaves the card',
        (tester) async {
      for (final (score, _, _) in states) {
        await pumpFix3(tester, card(score), textSize: textSize);
        expect(tester.takeException(), isNull, reason: '$score');
        final box = tester.getRect(find.byKey(MonthlyProgressCard.cardKey));
        for (final tier in MedalTier.values) {
          final label =
              tester.getRect(find.byKey(MonthlyProgressCard.labelKey(tier)));
          expect(label.bottom, lessThanOrEqualTo(box.bottom));
          expect(label.left, greaterThanOrEqualTo(box.left));
          expect(label.right, lessThanOrEqualTo(box.right));
        }
      }
    });
  }

  double shown(WidgetTester tester, int i) =>
      tester.getSize(find.byKey(MonthlyProgressCard.partFillKey(i))).width /
      tester.getSize(find.byKey(MonthlyProgressCard.partKey(i))).width;

  testWidgets(
      'the fill runs part by part (200 ms each); a medal passed pops '
      'and gets its tick', (tester) async {
    await pumpFix3(tester, card(120), settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    // Half of the first part; the second not yet; no tick yet.
    expect(shown(tester, 0), closeTo(.5, .1));
    expect(shown(tester, 1), 0);
    expect(find.byKey(MonthlyProgressCard.tickKey(MedalTier.bronze)),
        findsNothing);
    await tester.pump(const Duration(milliseconds: 150));
    // The first part full: Bronze passed, its tick on, popping.
    expect(shown(tester, 0), 1);
    expect(shown(tester, 1), greaterThan(0));
    expect(find.byKey(MonthlyProgressCard.tickKey(MedalTier.bronze)),
        findsOneWidget);
    final medal = find.byKey(MonthlyProgressCard.medalKey(MedalTier.bronze));
    final scale = tester
        .widget<Transform>(
            find.descendant(of: medal, matching: find.byType(Transform)).first)
        .transform
        .getMaxScaleOnAxis();
    expect(scale, greaterThan(1));
    // The dot follows the fill's front.
    final bar = tester.getRect(find.byKey(MonthlyProgressCard.barKey));
    expect(tester.getRect(find.byKey(MonthlyProgressCard.dotKey)).center.dx,
        lessThan(bar.left + 120 / 300 * bar.width));
    await tester.pumpAndSettle();
    expect(shown(tester, 1), closeTo(.6, .02));
    expect(shown(tester, 2), 0);
    expect(tester.getRect(find.byKey(MonthlyProgressCard.dotKey)).center.dx,
        closeTo(bar.left + 120 / 300 * bar.width, .5));
  });

  testWidgets('Reduce Motion: filled at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpFix3(tester, card(240), settle: false);
    await tester.pump();
    expect(shown(tester, 0), 1);
    expect(shown(tester, 1), 1);
    expect(shown(tester, 2), 1);
    expect(shown(tester, 3), closeTo(.2, .02));
    for (final tier in MedalTier.values) {
      expect(find.byKey(MonthlyProgressCard.tickKey(tier)), findsOneWidget);
    }
  });

  testWidgets('Arabic: the bar runs from the right', (tester) async {
    await pumpFix3(tester, card(120), locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byKey(MonthlyProgressCard.barKey));
    expect(tester.getRect(find.byKey(MonthlyProgressCard.dotKey)).center.dx,
        closeTo(bar.right - 120 / 300 * bar.width, .5));
    expect(
        tester
            .getRect(find.byKey(MonthlyProgressCard.medalKey(MedalTier.bronze)))
            .center
            .dx,
        closeTo(bar.right - 75 / 300 * bar.width, .5));
    // The first part (0–75) at the right end, full.
    final first = tester.getRect(find.byKey(MonthlyProgressCard.partKey(0)));
    expect(first.right, closeTo(bar.right, .5));
    expect(shown(tester, 0), 1);
  });
}
