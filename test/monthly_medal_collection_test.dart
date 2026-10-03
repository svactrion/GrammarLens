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

/// Batch 5 (N10, N17): one row per month in its own theme, the running
/// month on top and in progress, tiers lit as they become certain; the
/// Gold ladder within a month; unearned medals faded.
void main() {
  Future<void> pumpCollection(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    WelcomeBadge? welcomeBadge,
    MonthlyMedalProgress? currentProgress,
    List<MonthlyMedalResult> results = const [],
    Map<(int, int), String> themeIds = const {},
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MonthlyMedalCollection(
              welcomeBadge: welcomeBadge,
              currentProgress: currentProgress,
              results: results,
              themeIds: themeIds,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Each month's three medals, top to bottom, as (theme, earned flags).
  List<(String, List<bool>)> months(WidgetTester tester) => [
        for (final row
            in tester.widgetList<MonthMedals>(find.byType(MonthMedals)))
          (
            row.theme.id,
            [
              for (final b in tester.widgetList<MedalBadge>(find.descendant(
                  of: find.byWidget(row), matching: find.byType(MedalBadge))))
                b.earned
            ]
          ),
      ];

  for (final brightness in Brightness.values) {
    for (final size in AppTextSize.values) {
      testWidgets('an empty collection fits 320 pt in $brightness at $size',
          (tester) async {
        await pumpCollection(tester, brightness: brightness, textSize: size);
        expect(find.text('Your monthly medals will appear here once earned.'),
            findsOneWidget);
        expect(find.text('Not earned'), findsOneWidget);
        expect(find.byType(MonthMedals), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'the running month, history and the Welcome badge fit 320 pt in '
          '$brightness at $size', (tester) async {
        await pumpCollection(
          tester,
          brightness: brightness,
          textSize: size,
          welcomeBadge: welcomeBadgeFixture,
          currentProgress: november(score: 160),
          results: [goldOctober, bronzeSeptember, noMedalAugust],
          themeIds: storedThemes,
        );
        expect(find.text('In progress'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.bySemanticsLabel('Welcome badge, earned.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'N17: the running month is on top, marked in progress, then the '
      'finalized months newest first, each in its own theme', (tester) async {
    await pumpCollection(
      tester,
      currentProgress: november(score: 42),
      // Stored in any order.
      results: [noMedalAugust, goldOctober, bronzeSeptember],
      themeIds: storedThemes,
    );
    expect(months(tester).map((m) => m.$1), [
      'ember_peak', // November, stored
      'green_slope', // October, stored
      'green_slope', // September: before themes were stored
      'green_slope', // August
    ]);
    final inProgress = tester.getTopLeft(find.text('In progress')).dy;
    expect(inProgress, lessThan(tester.getTopLeft(find.text('History')).dy));
    expect(find.text('This month · Ember Peak'), findsOneWidget);
    expect(find.text('42 / 300 points · 6 active days'), findsOneWidget);
  });

  testWidgets('a running month with no stored theme yet: its calendar theme',
      (tester) async {
    await pumpCollection(tester, currentProgress: november(score: 0));
    expect(months(tester).single.$1, 'ember_peak');
  });

  testWidgets('a past month with no stored theme is Green Slope',
      (tester) async {
    await pumpCollection(tester, results: [
      result(2026, 12, MedalTier.gold, 300),
    ]);
    expect(months(tester).single.$1, 'green_slope');
  });

  testWidgets('N17: a tier lights the moment the score crosses it',
      (tester) async {
    final silver = MonthlyMedalRules.threshold(2026, 11, MedalTier.silver);
    await pumpCollection(tester, currentProgress: november(score: silver - 1));
    expect(months(tester).single.$2, [true, false, false]);
    expect(
        find.bySemanticsLabel(RegExp('Bronze medal earned')), findsOneWidget);

    await pumpCollection(tester, currentProgress: november(score: silver));
    expect(months(tester).single.$2, [true, true, false]);
    expect(
        find.bySemanticsLabel(RegExp('Silver medal earned')), findsOneWidget);
  });

  testWidgets('below Bronze the running month shows all three faded',
      (tester) async {
    await pumpCollection(tester, currentProgress: november(score: 10));
    expect(months(tester).single.$2, [false, false, false]);
    expect(find.text('Your monthly medals will appear here once earned.'),
        findsOneWidget);
  });

  testWidgets('a Gold month lights Bronze and Silver too; Silver lights two',
      (tester) async {
    await pumpCollection(tester, results: [
      goldOctober,
      result(2026, 9, MedalTier.silver, 160),
      noMedalAugust,
    ]);
    expect(months(tester).map((m) => m.$2), [
      [true, true, true],
      [true, true, false],
      [false, false, false],
    ]);
  });

  testWidgets(
      'a finalized month keeps its frozen tier: it is never recomputed from '
      'the score', (tester) async {
    // Frozen at Bronze with a score a later rule would read differently.
    await pumpCollection(tester, results: [
      result(2026, 9, MedalTier.bronze, 0),
    ]);
    expect(months(tester).single.$2, [true, false, false]);
    expect(
        find.bySemanticsLabel(
            'September 2026, Green Slope, Bronze medal, 0 of 300 points.'),
        findsOneWidget);
  });

  testWidgets(
      'the running month is not drawn twice if a result for it is passed',
      (tester) async {
    await pumpCollection(tester,
        currentProgress: november(score: 42),
        results: [result(2026, 11, MedalTier.gold, 300), goldOctober]);
    expect(find.byType(MonthMedals), findsNWidgets(2));
  });

  testWidgets(
      'N10: unearned medals are faded; the Welcome badge too while locked',
      (tester) async {
    await pumpCollection(tester, results: [bronzeSeptember]);
    final faded = tester
        .widgetList<MedalBadge>(find.byType(MedalBadge))
        .where((b) => !b.earned);
    // Silver, Gold and the locked Welcome badge.
    expect(faded, hasLength(3));
    expect(find.bySemanticsLabel('Welcome badge, locked.'), findsOneWidget);
    expect(find.text('Not earned'), findsOneWidget);
  });

  test('themeFor: stored, else the calendar (running) or Green Slope', () {
    expect(
        MonthlyMedalCollection.themeFor(2027, 1, {(2027, 1): 'glacier_peak'}),
        ClimbThemes.glacierPeak);
    expect(MonthlyMedalCollection.themeFor(2027, 1, const {}, running: true),
        ClimbThemes.redCanyon);
    expect(MonthlyMedalCollection.themeFor(2027, 1, const {}),
        ClimbThemes.greenSlope);
    expect(MonthlyMedalCollection.themeFor(2026, 5, const {}, running: true),
        ClimbThemes.greenSlope);
  });
}

final welcomeBadgeFixture = WelcomeBadge(
  earnedAt: DateTime(2026, 8, 15),
  ruleVersion: 1,
  backfilled: false,
);

const storedThemes = {(2026, 11): 'ember_peak', (2026, 10): 'green_slope'};

MonthlyMedalProgress november({required int score}) => MonthlyMedalProgress(
      year: 2026,
      month: 11,
      score: score,
      maxScore: MonthlyMedalRules.maxScore(2026, 11),
      activeDays: 6,
      correct: 0,
      wrong: 0,
      skipped: 0,
    );

MonthlyMedalResult result(int year, int month, MedalTier? tier, int score) =>
    MonthlyMedalResult(
      year: year,
      month: month,
      score: score,
      maxScore: MonthlyMedalRules.maxScore(year, month),
      activeDays: 10,
      correct: 0,
      wrong: 0,
      skipped: 0,
      tier: tier,
      ruleVersion: 1,
      finalizedAt: DateTime(year, month + 1, 1),
    );

final goldOctober = result(2026, 10, MedalTier.gold, 251);
final bronzeSeptember = result(2026, 9, MedalTier.bronze, 96);
final noMedalAugust = result(2026, 8, null, 41);
