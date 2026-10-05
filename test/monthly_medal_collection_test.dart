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

/// Batch 5 (N10, N33) and 1.2.0 Batch 7 (Q7, N9, N10): Profile's strip.
/// The running month first, then the months newest to oldest, one medal
/// each (the highest tier, in the month's theme), the Welcome badge last;
/// the running month marked in progress, its theme's Bronze at .38 while it
/// has no tier; no past month without a medal. A tap opens the medal's
/// detail, a tap outside closes it. The running month's progress card takes
/// every number from `MonthlyMedalRules`.
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
              child: Column(children: [
                MonthlyMedalCollection(
                  welcomeBadge: welcomeBadge,
                  currentProgress: currentProgress,
                  results: results,
                  themeIds: themeIds,
                ),
                if (currentProgress != null)
                  MonthlyProgressCard(
                    progress: currentProgress,
                    theme: MonthlyMedalCollection.themeFor(
                        currentProgress.year, currentProgress.month, themeIds,
                        running: true),
                  ),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The strip's medals, left to right, as (slot key, theme or 'welcome',
  /// tier, earned).
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
        expect(shelf(tester), hasLength(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'twelve months and the Welcome badge fit 320 pt in $brightness at '
          '$size on one scrolling strip, the detail too', (tester) async {
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
        // One row: every slot at the same top.
        final tops = {
          for (final e in find
              .byWidgetPredicate((w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>)
                      .value
                      .startsWith('medal_shelf_') &&
                  w.key != MonthlyMedalCollection.detailKey &&
                  w.key != MonthlyMedalCollection.stripKey)
              .evaluate())
            tester.getTopLeft(find.byKey(e.widget.key!)).dy
        };
        expect(tops, hasLength(1));
        await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 11)));
        await tester.pumpAndSettle();
        expect(find.byKey(MonthlyMedalCollection.detailKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'Q7: the running month first, then the months newest to oldest, the '
      'Welcome badge last; each in its theme with its highest tier',
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
      ('medal_shelf_2026-11', 'ember_peak', MedalTier.bronze, true),
      ('medal_shelf_2026-10', 'red_canyon', MedalTier.gold, true),
      // Before themes were stored: Green Slope.
      ('medal_shelf_2026-9', 'green_slope', MedalTier.bronze, true),
      ('medal_shelf_2026-7', 'green_slope', MedalTier.silver, true),
      ('medal_shelf_welcome', 'welcome', null, true),
    ]);
  });

  testWidgets(
      'the strip has no background: no card, disc or fill behind the medals',
      (tester) async {
    await pumpCollection(tester,
        width: 430,
        welcomeBadge: welcomeBadgeFixture,
        currentProgress: november(score: 80),
        results: [goldOctober]);
    final strip = find.byKey(MonthlyMedalCollection.stripKey);
    expect(
        find.descendant(of: strip, matching: find.byType(Card)), findsNothing);
    for (final box in tester.widgetList<DecoratedBox>(
        find.descendant(of: strip, matching: find.byType(DecoratedBox)))) {
      final d = box.decoration;
      expect(
          d is BoxDecoration && (d.color != null || d.shape == BoxShape.circle),
          isFalse);
    }
    expect(find.descendant(of: strip, matching: find.byType(ColoredBox)),
        findsNothing);
  });

  testWidgets('the running month is marked in progress, and only it',
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
      "Q7: with no tier yet, the running month shows its theme's Bronze at "
      'about .38 opacity; its text is not faded', (tester) async {
    final bronze = MonthlyMedalRules.threshold(2026, 11, MedalTier.bronze);
    await pumpCollection(tester,
        currentProgress: november(score: bronze - 1), themeIds: storedThemes);
    expect(shelf(tester).first,
        ('medal_shelf_2026-11', 'ember_peak', MedalTier.bronze, false));
    final slot = find.byKey(MonthlyMedalCollection.slotKey(2026, 11));
    final badge = tester.widget<MedalBadge>(
        find.descendant(of: slot, matching: find.byType(MedalBadge)));
    expect(badge.fadedOpacity, MonthlyMedalCollection.runningFade);
    expect(MonthlyMedalCollection.runningFade, closeTo(.38, .001));
    final filter = tester.widget<ColorFiltered>(
        find.descendant(of: slot, matching: find.byType(ColorFiltered)));
    expect(filter.colorFilter, ColorFilter.matrix(MedalBadge.fadedMatrix(.38)));
    // The label and the mark are drawn in full: nothing fades them.
    for (final text in ['Nov 2026', MonthlyMedalCollection.inProgress]) {
      final label = find.descendant(of: slot, matching: find.text(text));
      expect(find.ancestor(of: label, matching: find.byType(Opacity)),
          findsNothing);
      expect(find.ancestor(of: label, matching: find.byType(ColorFiltered)),
          findsNothing);
      expect(tester.widget<Text>(label).style!.color!.a, 1);
    }
    expect(
        find.bySemanticsLabel(
            'November 2026, Ember Peak, No medal yet, in progress.'),
        findsOneWidget);

    // The moment the score crosses Bronze, it lights (N8: certain).
    await pumpCollection(tester,
        currentProgress: november(score: bronze), themeIds: storedThemes);
    expect(shelf(tester).first,
        ('medal_shelf_2026-11', 'ember_peak', MedalTier.bronze, true));
  });

  testWidgets(
      'a past month without a medal is not on the strip; a running month '
      'passed as a result is not drawn twice', (tester) async {
    await pumpCollection(tester,
        width: 430,
        currentProgress: november(score: 42),
        results: [
          noMedalAugust,
          bronzeSeptember,
          result(2026, 11, MedalTier.gold, 300),
        ]);
    expect(shelf(tester).map((s) => s.$1), [
      'medal_shelf_2026-11',
      'medal_shelf_2026-9',
      'medal_shelf_welcome',
    ]);
    expect(find.byKey(MonthlyMedalCollection.slotKey(2026, 8)), findsNothing);
  });

  testWidgets(
      'a finalized month keeps its frozen tier: it is never recomputed from '
      'the score', (tester) async {
    await pumpCollection(tester, results: [
      result(2026, 9, MedalTier.bronze, 0),
    ]);
    expect(shelf(tester).first,
        ('medal_shelf_2026-9', 'green_slope', MedalTier.bronze, true));
  });

  testWidgets('N10: the Welcome badge is faded while locked', (tester) async {
    await pumpCollection(tester, results: [bronzeSeptember]);
    expect(shelf(tester).last, ('medal_shelf_welcome', 'welcome', null, false));
    expect(find.bySemanticsLabel('Welcome badge, locked.'), findsOneWidget);
  });

  test('earnedCount: the Welcome badge and every month with a tier', () {
    expect(const MonthlyMedalCollection().earnedCount, 0);
    expect(
        MonthlyMedalCollection(currentProgress: november(score: 0)).earnedCount,
        0);
    expect(
        MonthlyMedalCollection(
          welcomeBadge: welcomeBadgeFixture,
          currentProgress: november(score: 80),
          results: [goldOctober, noMedalAugust, bronzeSeptember],
        ).earnedCount,
        4);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
        'N10: a tap opens the detail with the month, its status, theme, tier, '
        'steps and points; a tap outside closes it'
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
        'Earned',
        'Red Canyon · Gold medal',
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

      // A tap outside the card: the screen's corner.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(MonthlyMedalCollection.detailKey), findsNothing);
    });
  }

  for (final reduceMotion in [false, true]) {
    testWidgets(
        'N10: the medal grows in over 240 ms ease-out; with Reduce Motion it '
        'does not move (fade only)${reduceMotion ? ' (Reduce Motion)' : ''}',
        (tester) async {
      await pumpCollection(tester,
          reduceMotion: reduceMotion,
          results: [goldOctober],
          themeIds: storedThemes);
      await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final detail = find.byKey(MonthlyMedalCollection.detailKey);
      final grow = find.descendant(
          of: detail,
          matching: find.ancestor(
              of: find.byType(MedalBadge),
              matching: find.byType(ScaleTransition)));
      if (reduceMotion) {
        expect(grow, findsNothing);
      } else {
        final scale = tester.widget<ScaleTransition>(grow.first).scale.value;
        expect(scale, closeTo(.5 + .5 * Curves.easeOut.transform(.5), .02));
      }
      final route = ModalRoute.of(tester.element(detail))!;
      expect(route.transitionDuration, const Duration(milliseconds: 240));
      await tester.pump(const Duration(milliseconds: 130));
      await tester.pump();
      if (!reduceMotion) {
        expect(tester.widget<ScaleTransition>(grow.first).scale.value, 1);
      }
      expect(route.animation!.status, AnimationStatus.completed);
    });
  }

  testWidgets(
      'N10: the focus moves into the detail and comes back to the medal that '
      'opened it', (tester) async {
    await pumpCollection(tester,
        results: [goldOctober], themeIds: storedThemes);
    final slot = find.byKey(MonthlyMedalCollection.slotKey(2026, 10));
    await tester.tap(slot);
    await tester.pumpAndSettle();
    final detail = find.byKey(MonthlyMedalCollection.detailKey);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
        find.descendant(
            of: detail,
            matching: find.byWidgetPredicate(
                (w) => identical(w, focused.widget),
                skipOffstage: false)),
        findsWidgets,
        reason: 'the focus is inside the detail');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(detail, findsNothing);
    final back = FocusManager.instance.primaryFocus!.context!;
    expect(
        find.descendant(
            of: slot,
            matching: find.byWidgetPredicate((w) => identical(w, back.widget))),
        findsOneWidget,
        reason: 'the focus is back on the slot');
  });

  testWidgets('the running month and the Welcome badge have their details',
      (tester) async {
    final silver = MonthlyMedalRules.threshold(2026, 11, MedalTier.silver);
    final bronze = MonthlyMedalRules.threshold(2026, 11, MedalTier.bronze);
    await pumpCollection(tester,
        welcomeBadge: welcomeBadgeFixture,
        currentProgress: november(score: 42),
        themeIds: storedThemes);
    await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 11)));
    await tester.pumpAndSettle();
    var detail = find.byKey(MonthlyMedalCollection.detailKey);
    for (final line in [
      'November 2026',
      'Not earned yet',
      'Ember Peak · in progress',
      '6 / 30 steps · 42 points',
      'Reach $bronze points to earn Bronze.',
      '${bronze - 42} points to go.',
    ]) {
      expect(find.descendant(of: detail, matching: find.text(line)),
          findsOneWidget,
          reason: line);
    }
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    // Past Bronze: earned, the next medal is Silver.
    await pumpCollection(tester,
        currentProgress: november(score: bronze + 3), themeIds: storedThemes);
    await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 11)));
    await tester.pumpAndSettle();
    detail = find.byKey(MonthlyMedalCollection.detailKey);
    for (final line in [
      'Earned',
      'Ember Peak · Bronze medal · in progress',
      'Reach $silver points to earn Silver.',
      '${silver - bronze - 3} points to go.',
    ]) {
      expect(find.descendant(of: detail, matching: find.text(line)),
          findsOneWidget,
          reason: line);
    }
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    // At Gold: no next medal, nothing to go.
    await pumpCollection(tester,
        currentProgress: november(score: 300), themeIds: storedThemes);
    await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 11)));
    await tester.pumpAndSettle();
    detail = find.byKey(MonthlyMedalCollection.detailKey);
    expect(find.descendant(of: detail, matching: find.textContaining('to go')),
        findsNothing);
    expect(find.descendant(of: detail, matching: find.textContaining('Reach')),
        findsNothing);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await pumpCollection(tester,
        welcomeBadge: welcomeBadgeFixture,
        currentProgress: november(score: 42),
        themeIds: storedThemes);
    await tester.tap(find.byKey(MonthlyMedalCollection.welcomeSlotKey));
    await tester.pumpAndSettle();
    detail = find.byKey(MonthlyMedalCollection.detailKey);
    for (final line in [
      'Welcome',
      'Earned',
      'The beginning of your journey.',
      'Earned in August 2026',
    ]) {
      expect(find.descendant(of: detail, matching: find.text(line)),
          findsOneWidget,
          reason: line);
    }
  });

  group('N9: the progress card', () {
    String text(WidgetTester tester, Key key) {
      final w = tester.widget(find.byKey(key));
      return w is Text ? (w.data ?? w.textSpan!.toPlainText()) : '';
    }

    String goal(WidgetTester tester) => [
          for (final t in tester.widgetList<Text>(find.descendant(
              of: find.byKey(MonthlyProgressCard.goalKey),
              matching: find.byType(Text))))
            t.data ?? t.textSpan!.toPlainText()
        ].join(' | ');

    double bar(WidgetTester tester) => tester
        .widget<LinearProgressIndicator>(find.descendant(
            of: find.byKey(MonthlyProgressCard.cardKey),
            matching: find.byType(LinearProgressIndicator)))
        .value!;

    for (final (year, month) in [(2026, 11), (2027, 2)]) {
      testWidgets(
          'the four states for $year-$month, every number from '
          'MonthlyMedalRules, never a negative count', (tester) async {
        int th(MedalTier t) => MonthlyMedalRules.threshold(year, month, t);
        final max = MonthlyMedalRules.maxScore(year, month);
        MonthlyMedalProgress at(int score) => MonthlyMedalProgress(
              year: year,
              month: month,
              score: score,
              maxScore: max,
              activeDays: 1,
              correct: 0,
              wrong: 0,
              skipped: 0,
            );
        final cases = <int, (String, String, double)>{
          // Before Bronze.
          7: (
            'Next medal Bronze | 7 / ${th(MedalTier.bronze)} pts',
            '${th(MedalTier.bronze) - 7} points to your first monthly medal',
            7 / th(MedalTier.bronze),
          ),
          // Bronze exactly: the next medal is Silver.
          th(MedalTier.bronze): (
            'Next medal Silver | ${th(MedalTier.bronze)} / '
                '${th(MedalTier.silver)} pts',
            'Bronze earned · ${th(MedalTier.silver) - th(MedalTier.bronze)} '
                'points to Silver',
            th(MedalTier.bronze) / th(MedalTier.silver),
          ),
          // Silver: the next is Gold.
          th(MedalTier.silver) + 1: (
            'Next medal Gold | ${th(MedalTier.silver) + 1} / '
                '${th(MedalTier.gold)} pts',
            'Silver earned · ${th(MedalTier.gold) - th(MedalTier.silver) - 1} '
                'points to Gold',
            (th(MedalTier.silver) + 1) / th(MedalTier.gold),
          ),
          // Gold and beyond: a completion line, nothing left.
          max: (
            'Top medal Gold | $max / $max pts',
            "Gold earned. That's this month's top medal.",
            1.0,
          ),
        };
        for (final MapEntry(key: score, value: (g, toGo, value))
            in cases.entries) {
          await pumpCollection(tester, width: 375, currentProgress: at(score));
          expect(goal(tester), g, reason: '$score');
          expect(text(tester, MonthlyProgressCard.toGoKey), toGo,
              reason: '$score');
          expect(bar(tester), closeTo(value, 1e-9), reason: '$score');
          expect(text(tester, MonthlyProgressCard.totalKey),
              'Monthly total: $score / $max points');
          for (final tier in MedalTier.values) {
            expect(text(tester, MonthlyProgressCard.thresholdKey(tier)),
                '${th(tier)} pts');
          }
          // No negative number anywhere on the card.
          for (final t in tester.widgetList<Text>(find.descendant(
              of: find.byKey(MonthlyProgressCard.cardKey),
              matching: find.byType(Text)))) {
            expect(
                (t.data ?? t.textSpan!.toPlainText()).contains('-'), isFalse);
          }
          expect(
              tester
                  .widget<Text>(find
                      .descendant(
                          of: find.byKey(MonthlyProgressCard.pointsKey),
                          matching: find.byType(Text))
                      .first)
                  .data,
              '$score');
        }
      });
    }

    testWidgets(
        'the month, theme and active days head it; the orange label holds '
        'the points', (tester) async {
      await pumpCollection(tester,
          width: 375,
          currentProgress: november(score: 80),
          themeIds: storedThemes);
      expect(find.text('November progress'), findsOneWidget);
      expect(find.text('Ember Peak · 6 active days'), findsOneWidget);
      final label =
          tester.widget<Container>(find.byKey(MonthlyProgressCard.pointsKey));
      final context = tester.element(find.byKey(MonthlyProgressCard.pointsKey));
      expect((label.decoration! as BoxDecoration).color,
          Theme.of(context).colorScheme.primary);
      expect(
          find.bySemanticsLabel(RegExp(r'^November progress, Ember Peak, '
              r'6 active days\. Next medal Silver, 80 of \d+ points\.')),
          findsOneWidget);
    });

    testWidgets('it sits under the strip, as a card of its own',
        (tester) async {
      await pumpCollection(tester,
          width: 375,
          welcomeBadge: welcomeBadgeFixture,
          currentProgress: november(score: 80),
          results: [goldOctober],
          themeIds: storedThemes);
      final card = tester.getRect(find.byKey(MonthlyProgressCard.cardKey));
      expect(
          card.top,
          greaterThan(tester
                  .getRect(find.byKey(MonthlyMedalCollection.stripKey))
                  .bottom -
              1));
      expect(
          find.descendant(
              of: find.byKey(MonthlyMedalCollection.stripKey),
              matching: find.byKey(MonthlyProgressCard.cardKey)),
          findsNothing);
    });
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
