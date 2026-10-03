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

/// Batch 5 (N10, N33, N34): Profile's shelf. The Welcome badge first, then
/// the months oldest to newest, one medal each (the highest tier, in the
/// month's theme); the running month marked in progress, its theme's Bronze
/// faded while it has no tier; no past month without a medal. A tap opens
/// the medal's detail, a tap anywhere closes it. The running month's bar
/// writes each threshold under its mark, from `MonthlyMedalRules`.
void main() {
  Future<void> pumpCollection(
    WidgetTester tester, {
    double width = 320,
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    WelcomeBadge? welcomeBadge,
    MonthlyMedalProgress? currentProgress,
    List<MonthlyMedalResult> results = const [],
    Map<(int, int), String> themeIds = const {},
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = Size(width, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 568), disableAnimations: reduceMotion),
        child: Scaffold(
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
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The shelf's medals, left to right then top to bottom, as
  /// (slot key, theme or 'welcome', tier, earned).
  List<(String, String, MedalTier?, bool)> shelf(WidgetTester tester) {
    final slots = find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('medal_shelf_') &&
        w.key != MonthlyMedalCollection.detailKey);
    final out = <(String, String, MedalTier?, bool, Offset)>[];
    for (final e in slots.evaluate()) {
      final key = (e.widget.key! as ValueKey<String>).value;
      final badge = tester.widget<MedalBadge>(find.descendant(
          of: find.byKey(e.widget.key!), matching: find.byType(MedalBadge)));
      final m = RegExp(r'medal_(\w+?)_(gold|silver|bronze)\.webp')
          .firstMatch(badge.asset);
      out.add((
        key,
        m?.group(1) ?? 'welcome',
        m == null ? null : MedalTier.values.byName(m.group(2)!),
        badge.earned,
        tester.getTopLeft(find.byKey(e.widget.key!)),
      ));
    }
    out.sort((a, b) => a.$5.dy != b.$5.dy
        ? a.$5.dy.compareTo(b.$5.dy)
        : a.$5.dx.compareTo(b.$5.dx));
    return [for (final s in out) (s.$1, s.$2, s.$3, s.$4)];
  }

  for (final brightness in Brightness.values) {
    for (final size in AppTextSize.values) {
      testWidgets('only the running month fits 320 pt in $brightness at $size',
          (tester) async {
        await pumpCollection(tester,
            brightness: brightness,
            textSize: size,
            currentProgress: november(score: 0));
        expect(find.text('Your medals will appear here once earned.'),
            findsOneWidget);
        expect(shelf(tester), hasLength(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'twelve months and the Welcome badge fit 320 pt in $brightness at '
          '$size, the detail too', (tester) async {
        await pumpCollection(
          tester,
          brightness: brightness,
          textSize: size,
          welcomeBadge: welcomeBadgeFixture,
          currentProgress: november(score: 160),
          results: twelveMonths,
          themeIds: storedThemes,
        );
        expect(shelf(tester), hasLength(13));
        await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 11)));
        await tester.pumpAndSettle();
        expect(find.byKey(MonthlyMedalCollection.detailKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'N34: the Welcome badge first, then the months oldest to newest, the '
      'running month last; each in its theme with its highest tier',
      (tester) async {
    await pumpCollection(
      tester,
      width: 430,
      welcomeBadge: welcomeBadgeFixture,
      currentProgress: november(score: 80),
      // Stored in any order.
      results: [goldOctober, silverJuly, bronzeSeptember],
      themeIds: storedThemes,
    );
    expect(shelf(tester), [
      ('medal_shelf_welcome', 'welcome', null, true),
      ('medal_shelf_2026-7', 'green_slope', MedalTier.silver, true),
      // Before themes were stored: Green Slope.
      ('medal_shelf_2026-9', 'green_slope', MedalTier.bronze, true),
      ('medal_shelf_2026-10', 'red_canyon', MedalTier.gold, true),
      ('medal_shelf_2026-11', 'ember_peak', MedalTier.bronze, true),
    ]);
  });

  testWidgets('N34: the running month is marked in progress, and only it',
      (tester) async {
    await pumpCollection(tester,
        width: 430,
        currentProgress: november(score: 80),
        results: [goldOctober, bronzeSeptember],
        themeIds: storedThemes);
    expect(find.text(MonthlyMedalCollection.inProgress), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(MonthlyMedalCollection.slotKey(2026, 11)),
            matching: find.text(MonthlyMedalCollection.inProgress)),
        findsOneWidget);
    expect(
        find.bySemanticsLabel(
            'November 2026, Ember Peak, Bronze medal, in progress.'),
        findsOneWidget);
  });

  testWidgets(
      "N34: with no tier yet, the running month shows its theme's Bronze "
      'faded', (tester) async {
    final bronze = MonthlyMedalRules.threshold(2026, 11, MedalTier.bronze);
    await pumpCollection(tester,
        currentProgress: november(score: bronze - 1), themeIds: storedThemes);
    expect(shelf(tester).last,
        ('medal_shelf_2026-11', 'ember_peak', MedalTier.bronze, false));
    expect(
        find.bySemanticsLabel(
            'November 2026, Ember Peak, No medal yet, in progress.'),
        findsOneWidget);

    // The moment the score crosses Bronze, it lights (N8: certain).
    await pumpCollection(tester,
        currentProgress: november(score: bronze), themeIds: storedThemes);
    expect(shelf(tester).last,
        ('medal_shelf_2026-11', 'ember_peak', MedalTier.bronze, true));
  });

  testWidgets(
      'N34: a past month without a medal is not on the shelf; a running '
      'month passed as a result is not drawn twice', (tester) async {
    await pumpCollection(tester,
        width: 430,
        currentProgress: november(score: 42),
        results: [
          noMedalAugust,
          bronzeSeptember,
          result(2026, 11, MedalTier.gold, 300),
        ]);
    expect(shelf(tester).map((s) => s.$1), [
      'medal_shelf_welcome',
      'medal_shelf_2026-9',
      'medal_shelf_2026-11',
    ]);
    expect(find.byKey(MonthlyMedalCollection.slotKey(2026, 8)), findsNothing);
  });

  testWidgets(
      'a finalized month keeps its frozen tier: it is never recomputed from '
      'the score', (tester) async {
    await pumpCollection(tester, results: [
      result(2026, 9, MedalTier.bronze, 0),
    ]);
    expect(shelf(tester).last,
        ('medal_shelf_2026-9', 'green_slope', MedalTier.bronze, true));
  });

  testWidgets('N10: the Welcome badge is faded while locked', (tester) async {
    await pumpCollection(tester, results: [bronzeSeptember]);
    expect(
        shelf(tester).first, ('medal_shelf_welcome', 'welcome', null, false));
    expect(find.bySemanticsLabel('Welcome badge, locked.'), findsOneWidget);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
        'N34: a tap opens the detail with the month, theme, tier, steps and '
        'points; a tap outside closes it'
        '${reduceMotion ? ' (Reduce Motion)' : ''}', (tester) async {
      await pumpCollection(tester,
          reduceMotion: reduceMotion,
          currentProgress: november(score: 42),
          results: [goldOctober],
          themeIds: storedThemes);
      expect(find.byKey(MonthlyMedalCollection.detailKey), findsNothing);

      await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 10)));
      await tester.pumpAndSettle();
      final detail = find.byKey(MonthlyMedalCollection.detailKey);
      expect(detail, findsOneWidget);
      for (final line in [
        'October 2026',
        'Red Canyon',
        'Gold medal',
        '10 / 31 steps · 251 points',
      ]) {
        expect(find.descendant(of: detail, matching: find.text(line)),
            findsOneWidget,
            reason: line);
      }
      final big = tester.widget<MedalBadge>(
          find.descendant(of: detail, matching: find.byType(MedalBadge)));
      expect(big.disc, MonthlyMedalCollection.detailDisc);
      expect(big.asset, contains('medal_red_canyon_gold'));

      // A tap outside the medal: the screen's corner.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(MonthlyMedalCollection.detailKey), findsNothing);
    });
  }

  testWidgets('the running month and the Welcome badge have their details',
      (tester) async {
    await pumpCollection(tester,
        welcomeBadge: welcomeBadgeFixture,
        currentProgress: november(score: 42),
        themeIds: storedThemes);
    await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 11)));
    await tester.pumpAndSettle();
    var detail = find.byKey(MonthlyMedalCollection.detailKey);
    for (final line in [
      'November 2026',
      'Ember Peak',
      'No medal yet · in progress',
      '6 / 30 steps · 42 points',
    ]) {
      expect(find.descendant(of: detail, matching: find.text(line)),
          findsOneWidget,
          reason: line);
    }
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MonthlyMedalCollection.welcomeSlotKey));
    await tester.pumpAndSettle();
    detail = find.byKey(MonthlyMedalCollection.detailKey);
    expect(
        find.descendant(
            of: detail, matching: find.text('Earned in August 2026')),
        findsOneWidget);
  });

  testWidgets(
      'N33: each threshold under its mark, from MonthlyMedalRules, and the '
      'current score', (tester) async {
    for (final (year, month) in [(2026, 11), (2027, 2)]) {
      final progress = MonthlyMedalProgress(
        year: year,
        month: month,
        score: 77,
        maxScore: MonthlyMedalRules.maxScore(year, month),
        activeDays: 9,
        correct: 0,
        wrong: 0,
        skipped: 0,
      );
      await pumpCollection(tester, width: 375, currentProgress: progress);
      final bar = tester.getRect(find.byType(LinearProgressIndicator));
      for (final tier in MedalTier.values) {
        final v = MonthlyMedalRules.threshold(year, month, tier);
        final label = find.byKey(MedalProgressBar.thresholdKey(tier));
        expect(tester.widget<Text>(label).data, '$v');
        // Under its mark, at the threshold's place on the bar.
        final x = bar.left + bar.width * v / progress.maxScore;
        expect(tester.getCenter(label).dx, closeTo(x, 1));
        expect(tester.getTopLeft(label).dy, greaterThan(bar.bottom));
      }
      expect(tester.widget<Text>(find.byKey(MedalProgressBar.scoreKey)).data,
          '77 points');
    }
  });

  testWidgets(
      'N38: "This month" labels the bar, under the shelf; the theme with '
      'the points under the bar', (tester) async {
    await pumpCollection(tester,
        width: 375,
        welcomeBadge: welcomeBadgeFixture,
        currentProgress: november(score: 80),
        results: [goldOctober],
        themeIds: storedThemes);
    final label = find.byKey(MedalProgressBar.thisMonthKey);
    expect(tester.widget<Text>(label).data, 'This month');
    final shelfBottom =
        tester.getRect(find.byKey(MonthlyMedalCollection.slotKey(2026, 11)));
    final bar = tester.getRect(find.byType(LinearProgressIndicator));
    expect(tester.getRect(label).top, greaterThan(shelfBottom.bottom));
    expect(tester.getRect(label).bottom, lessThan(bar.top));
    expect(find.text('Ember Peak · 80 / 300 points · 6 active days'),
        findsOneWidget);
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

const storedThemes = {(2026, 11): 'ember_peak', (2026, 10): 'red_canyon'};

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
final silverJuly = result(2026, 7, MedalTier.silver, 170);

/// Twelve finalized months with a medal, December 2025 to October 2026
/// (and November running): every tier, every theme.
final twelveMonths = [
  for (var i = 0; i < 12; i++)
    result(2025 + (i + 11) ~/ 12, (i + 11) % 12 + 1, MedalTier.values[i % 3],
        100 + i * 15),
]..removeWhere((r) => (r.year, r.month) == (2026, 11));
