import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';

/// Design decision D9: the month's score against the medal thresholds, in a
/// strip under the mountain window, read aloud by VoiceOver.
void main() {
  // The real font, so label widths are the device's, not the test font's
  // square glyphs.
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  // One month of each length: 28 (Feb 2027), 29 (Feb 2028), 30 (Nov 2026),
  // 31 (Oct 2026).
  const months = [(2027, 2), (2028, 2), (2026, 11), (2026, 10)];

  Map<MedalTier, int> thresholds(int year, int month) => {
        for (final tier in MedalTier.values)
          tier: MonthlyMedalRules.threshold(year, month, tier),
      };

  Future<void> pumpBar(WidgetTester tester,
      {required int score,
      required int year,
      required int month,
      double width = 288,
      AppTextSize textSize = AppTextSize.medium}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light, textSize: textSize),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: ClimbScoreBar(
              score: score,
              maxScore: MonthlyMedalRules.maxScore(year, month),
              thresholds: thresholds(year, month),
            ),
          ),
        ),
      ),
    ));
  }

  for (final (year, month) in months) {
    final days = DateTime(year, month + 1, 0).day;
    testWidgets('$days-day month: ticks at the rule\'s thresholds',
        (tester) async {
      await pumpBar(tester, score: 0, year: year, month: month);
      final max = MonthlyMedalRules.maxScore(year, month);
      expect(max, days * 10);
      final bar = tester.getRect(find.byType(ClimbScoreBar));
      // The track spans the bar minus its 16 pt side padding.
      final trackLeft = bar.left + 16, trackWidth = bar.width - 32;
      final ticks = find.descendant(
          of: find.byType(ClimbScoreBar),
          matching: find.byWidgetPredicate((w) =>
              w is Positioned && w.width == 3 && w.child is DecoratedBox));
      expect(ticks, findsNWidgets(3));
      for (final (i, tier) in MedalTier.values.indexed) {
        final tick = tester.getRect(ticks.at(i));
        final expected =
            trackLeft + trackWidth * thresholds(year, month)[tier]! / max;
        expect(tick.center.dx, closeTo(expected, .01), reason: tier.label);
      }
    });
  }

  testWidgets('the fill follows the score, empty to full', (tester) async {
    double fill() => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;
    await pumpBar(tester, score: 0, year: 2026, month: 10);
    expect(fill(), 0);
    await pumpBar(tester, score: 155, year: 2026, month: 10);
    expect(fill(), closeTo(.5, 1e-9));
    await pumpBar(tester, score: 310, year: 2026, month: 10);
    expect(fill(), 1);
  });

  testWidgets('VoiceOver reads the score, the thresholds and the tier reached',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBar(tester, score: 160, year: 2026, month: 10);
    expect(
        find.bySemanticsLabel('Monthly score: 160 of 310 points. Bronze at '
            '78, Silver at 155, Gold at 233. Silver reached.'),
        findsOneWidget);
    await pumpBar(tester, score: 12, year: 2026, month: 10);
    expect(
        find.bySemanticsLabel('Monthly score: 12 of 310 points. Bronze at '
            '78, Silver at 155, Gold at 233.'),
        findsOneWidget);
    semantics.dispose();
  });

  for (final textSize in AppTextSize.values) {
    testWidgets(
        '288 pt, ${textSize.name} text: the three labels stay apart '
        'and inside the bar', (tester) async {
      await pumpBar(tester,
          score: 0, year: 2026, month: 10, textSize: textSize);
      final bar = tester.getRect(find.byType(ClimbScoreBar));
      final labels = [
        for (final tier in MedalTier.values)
          tester.getRect(find.text(tier.label))
      ];
      // Measure the glyphs, not the 80 pt centering boxes.
      final widths = [
        for (final tier in MedalTier.values)
          (TextPainter(
                  text: TextSpan(
                      text: tier.label,
                      style: tester.widget<Text>(find.text(tier.label)).style),
                  textDirection: TextDirection.ltr)
                ..layout())
              .width
      ];
      for (var i = 0; i < 3; i++) {
        final left = labels[i].center.dx - widths[i] / 2;
        final right = labels[i].center.dx + widths[i] / 2;
        expect(left, greaterThanOrEqualTo(bar.left));
        expect(right, lessThanOrEqualTo(bar.right));
        if (i > 0) {
          final previousRight = labels[i - 1].center.dx + widths[i - 1] / 2;
          expect(left - previousRight, greaterThan(4));
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
