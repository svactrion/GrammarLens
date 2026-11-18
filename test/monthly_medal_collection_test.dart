import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
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

import 'support/l10n_support.dart';

/// Profile's medal shelf (V23, UI polish fix round 1; before it, Batch 5 and
/// 1.2.0 Batch 7's strip): at most three medals standing on the shelf,
/// newest first — the running month (a locked slot until it has a tier),
/// then the past medals and the earned Welcome badge by month; one medal
/// per month (the highest tier, in the month's theme); no past month
/// without a medal. A tap opens the medal's detail (its medal flies in, its
/// numbers count up), a tap outside closes it. The running month's
/// progress card takes every number from `MonthlyMedalRules`.
void main() {
  // The card's marks are measured in the app's font (fix round 4, V23 v12).
  setUpAll(() async {
    await (FontLoader('NunitoSans')
          ..addFont(rootBundle.load('assets/fonts/NunitoSans-Variable.ttf')))
        .load();
  });

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
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (reduceMotion) {
      // Also for the routes the shelf opens, outside the MediaQuery below.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
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
    if (settle) await tester.pumpAndSettle();
  }

  bool isSlot(Widget w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('medal_shelf_') &&
      w.key != MonthlyMedalCollection.detailKey &&
      w.key != MonthlyMedalCollection.lockedKey;

  /// The shelf's slots, start to end, as (slot key, theme, 'welcome' or
  /// 'locked', tier, earned).
  List<(String, String, MedalTier?, bool)> shelf(WidgetTester tester) {
    final out = <(String, String, MedalTier?, bool, double)>[];
    for (final e in find.byWidgetPredicate(isSlot).evaluate()) {
      final key = (e.widget.key! as ValueKey<String>).value;
      final slot = find.byKey(e.widget.key!);
      final x = tester.getTopLeft(slot).dx;
      if (find
          .descendant(
              of: slot, matching: find.byKey(MonthlyMedalCollection.lockedKey))
          .evaluate()
          .isNotEmpty) {
        out.add((key, 'locked', null, false, x));
        continue;
      }
      final badge = tester.widget<MedalBadge>(
          find.descendant(of: slot, matching: find.byType(MedalBadge)));
      final m = RegExp(r'medal_(\w+?)_(gold|silver|bronze)\.webp')
          .firstMatch(badge.asset);
      out.add((
        key,
        m?.group(1) ?? 'welcome',
        m == null ? null : MedalTier.values.byName(m.group(2)!),
        badge.earned,
        x,
      ));
    }
    out.sort((a, b) => a.$5.compareTo(b.$5));
    return [for (final s in out) (s.$1, s.$2, s.$3, s.$4)];
  }

  for (final brightness in Brightness.values) {
    for (final size in AppTextSize.values) {
      testWidgets(
          'the running month alone, and three of twelve months, fit 320 pt '
          'in $brightness at $size; the detail too', (tester) async {
        await pumpCollection(tester,
            brightness: brightness,
            textSize: size,
            currentProgress: november(score: 0));
        expect(shelf(tester), hasLength(1));
        expect(tester.takeException(), isNull);

        await pumpCollection(
          tester,
          brightness: brightness,
          textSize: size,
          welcomeBadge: welcomeBadgeFixture,
          currentProgress: november(score: 160),
          results: twelveMonths,
          themeIds: storedThemes,
        );
        expect(shelf(tester), hasLength(MonthlyMedalCollection.shelfMax));
        // One row: every slot at the same top.
        final tops = {
          for (final e in find.byWidgetPredicate(isSlot).evaluate())
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
      'V23: newest first, at most three: the running month, then the past '
      'months newest to oldest; each in its theme with its highest tier',
      (tester) async {
    await pumpCollection(
      tester,
      width: 430,
      // Earned in August: older than the three newest.
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
    ]);
    expect(find.byKey(MonthlyMedalCollection.slotKey(2026, 7)), findsNothing);
    expect(find.byKey(MonthlyMedalCollection.welcomeSlotKey), findsNothing);
  });

  testWidgets(
      'the Welcome badge stands by the month it was earned in, after that '
      "month's own medal", (tester) async {
    await pumpCollection(tester,
        width: 430,
        welcomeBadge: welcomeBadgeFixture,
        currentProgress: november(score: 0),
        results: [goldOctober, silverJuly]);
    expect(shelf(tester).map((s) => s.$1), [
      'medal_shelf_2026-11',
      'medal_shelf_2026-10',
      'medal_shelf_welcome',
    ]);
    await pumpCollection(tester,
        width: 430,
        welcomeBadge: WelcomeBadge(
            earnedAt: DateTime(2026, 9, 3), ruleVersion: 1, backfilled: false),
        results: [bronzeSeptember, silverJuly]);
    expect(shelf(tester).map((s) => s.$1), [
      'medal_shelf_2026-9',
      'medal_shelf_welcome',
      'medal_shelf_2026-7',
    ]);
    // A new user: this month, then the badge.
    await pumpCollection(tester,
        width: 430,
        welcomeBadge: WelcomeBadge(
            earnedAt: DateTime(2026, 11, 2), ruleVersion: 1, backfilled: false),
        currentProgress: november(score: 9));
    expect(shelf(tester), [
      ('medal_shelf_2026-11', 'locked', null, false),
      ('medal_shelf_welcome', 'welcome', null, true),
    ]);
    expect(
        find.descendant(
            of: find.byKey(MonthlyMedalCollection.welcomeSlotKey),
            matching: find.text('Nov 2026')),
        findsOneWidget);
  });

  testWidgets(
      'the medals stand on the shelf image: their bottoms on its top surface, '
      'the labels under its front face', (tester) async {
    await pumpCollection(tester,
        width: 390,
        currentProgress: november(score: 80),
        results: [goldOctober, bronzeSeptember],
        themeIds: storedThemes);
    final image = find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == MonthlyMedalCollection.shelfAsset);
    expect(image, findsOneWidget);
    final shelfRect = tester.getRect(image);
    expect(shelfRect.width / shelfRect.height,
        closeTo(MonthlyMedalCollection.shelfAspect, .01));
    final slot = find.byKey(MonthlyMedalCollection.slotKey(2026, 10));
    final medal = tester
        .getRect(find.descendant(of: slot, matching: find.byType(MedalBadge)));
    expect(
        medal.bottom,
        closeTo(
            shelfRect.top + shelfRect.height * MonthlyMedalCollection.standAt,
            .5));
    final label = tester
        .getRect(find.descendant(of: slot, matching: find.text('Oct 2026')));
    expect(
        label.top,
        closeTo(
            shelfRect.top + shelfRect.height * MonthlyMedalCollection.labelsAt,
            .5));
  });

  testWidgets(
      'the running month is a locked slot until its first tier, with the way '
      'to it; then its medal, with the way to the next; Gold reads in '
      'progress', (tester) async {
    final bronze = MonthlyMedalRules.threshold(2026, 11, MedalTier.bronze);
    final silver = MonthlyMedalRules.threshold(2026, 11, MedalTier.silver);
    final gold = MonthlyMedalRules.threshold(2026, 11, MedalTier.gold);
    await pumpCollection(tester,
        currentProgress: november(score: bronze - 9), themeIds: storedThemes);
    final slot = find.byKey(MonthlyMedalCollection.slotKey(2026, 11));
    expect(
        shelf(tester).single, ('medal_shelf_2026-11', 'locked', null, false));
    expect(
        find.descendant(
            of: slot, matching: find.byIcon(Icons.lock_outline_rounded)),
        findsOneWidget);
    for (final text in ['Nov 2026', '9 pts to Bronze']) {
      expect(
          find.descendant(of: slot, matching: find.text(text)), findsOneWidget,
          reason: text);
    }
    expect(
        find.bySemanticsLabel(
            'November 2026, Ember Peak, No medal yet, in progress.'),
        findsOneWidget);

    // The moment the score crosses Bronze, it lights (N8: certain).
    await pumpCollection(tester,
        currentProgress: november(score: bronze), themeIds: storedThemes);
    expect(shelf(tester).single,
        ('medal_shelf_2026-11', 'ember_peak', MedalTier.bronze, true));
    expect(find.text('${silver - bronze} pts to Silver'), findsOneWidget);
    expect(
        find.bySemanticsLabel(
            'November 2026, Ember Peak, Bronze medal, in progress.'),
        findsOneWidget);

    await pumpCollection(tester,
        currentProgress: november(score: gold), themeIds: storedThemes);
    expect(shelf(tester).single,
        ('medal_shelf_2026-11', 'ember_peak', MedalTier.gold, true));
    expect(find.text(en.medalInProgress), findsOneWidget);
  });

  testWidgets("a past month's line is its tier", (tester) async {
    await pumpCollection(tester,
        width: 430, results: [goldOctober, bronzeSeptember]);
    for (final (key, tier) in [
      (MonthlyMedalCollection.slotKey(2026, 10), 'Gold'),
      (MonthlyMedalCollection.slotKey(2026, 9), 'Bronze'),
    ]) {
      expect(find.descendant(of: find.byKey(key), matching: find.text(tier)),
          findsOneWidget);
    }
  });

  testWidgets(
      'a past month without a medal is not on the shelf; a running month '
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

  testWidgets('an unearned Welcome badge is not on the shelf (PF02 has it)',
      (tester) async {
    await pumpCollection(tester, results: [bronzeSeptember]);
    expect(find.byKey(MonthlyMedalCollection.welcomeSlotKey), findsNothing);
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
        'V23: the medals settle on the shelf 80 ms apart'
        '${reduceMotion ? ' (Reduce Motion: they are just there)' : ''}',
        (tester) async {
      await pumpCollection(tester,
          width: 430,
          reduceMotion: reduceMotion,
          settle: false,
          currentProgress: november(score: 80),
          results: [goldOctober, bronzeSeptember],
          themeIds: storedThemes);
      double opacity(Key key) => tester
          .widget<Opacity>(find
              .ancestor(
                  of: find.descendant(
                      of: find.byKey(key), matching: find.byType(MedalBadge)),
                  matching: find.byType(Opacity))
              .first)
          .opacity;
      final keys = [
        MonthlyMedalCollection.slotKey(2026, 11),
        MonthlyMedalCollection.slotKey(2026, 10),
        MonthlyMedalCollection.slotKey(2026, 9),
      ];
      await tester.pump(const Duration(milliseconds: 120));
      final mid = [for (final k in keys) opacity(k)];
      if (reduceMotion) {
        expect(mid, [1, 1, 1]);
      } else {
        expect(mid[0], greaterThan(mid[1]));
        expect(mid[1], greaterThan(mid[2]));
      }
      await tester.pumpAndSettle();
      expect([for (final k in keys) opacity(k)], [1, 1, 1]);
    });

    testWidgets(
        'N34 / PF03: a tap opens the detail with the month, theme, tier, '
        'steps and points (counting up); a tap outside closes it'
        '${reduceMotion ? ' (Reduce Motion)' : ''}', (tester) async {
      await pumpCollection(tester,
          reduceMotion: reduceMotion,
          currentProgress: november(score: 42),
          results: [goldOctober],
          themeIds: storedThemes);
      expect(find.byKey(MonthlyMedalCollection.detailKey), findsNothing);

      await tester.tap(find.byKey(MonthlyMedalCollection.slotKey(2026, 10)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final counted = find.text('10 / 31 steps · 251 points');
      expect(counted, reduceMotion ? findsOneWidget : findsNothing,
          reason: 'the numbers count up unless motion is reduced');
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
      // The medal flies in under the shelf slot's tag; not under Reduce
      // Motion.
      final hero = tester.widget<Hero>(
          find.ancestor(of: find.byWidget(big), matching: find.byType(Hero)));
      expect(hero.tag, MonthlyMedalCollection.heroTag(2026, 10));
      expect(
          tester
              .widget<HeroMode>(find
                  .ancestor(
                      of: find.byWidget(big), matching: find.byType(HeroMode))
                  .first)
              .enabled,
          !reduceMotion);

      // A tap outside the medal: the screen's corner.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(MonthlyMedalCollection.detailKey), findsNothing);
    });
  }

  testWidgets('the running month and the Welcome badge have their details',
      (tester) async {
    await pumpCollection(tester,
        welcomeBadge: WelcomeBadge(
            earnedAt: DateTime(2026, 11, 2), ruleVersion: 1, backfilled: false),
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
            of: detail, matching: find.text('Earned in November 2026')),
        findsOneWidget);
  });

  // Fix round 5, item 3 (SPEC V23 v13, board V23p): the points large with
  // "/ 300" and the distance, the 0–300 bar in four parts split at the
  // thresholds, the medals over the gaps, the dot at the points; every
  // number from MonthlyMedalRules (a month with other numbers too). The
  // states one by one: test/fix5_progress_card_test.dart.
  group('N9 / V23 v13: the progress card', () {
    for (final (year, month) in [(2026, 11), (2027, 2)]) {
      testWidgets(
          '$year-$month: 0, mid-month and every tier passed: the parts, '
          'the points, the medals and the dot from MonthlyMedalRules',
          (tester) async {
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
        for (final score in [
          0,
          max ~/ 6,
          th(MedalTier.bronze),
          th(MedalTier.silver) + 1,
          th(MedalTier.gold),
          max,
        ]) {
          await pumpCollection(tester, width: 375, currentProgress: at(score));
          final bar = tester.getRect(find.byKey(MonthlyProgressCard.barKey));
          final bounds = MonthlyProgressCard.bounds(at(score));
          expect(bounds, [
            th(MedalTier.bronze),
            th(MedalTier.silver),
            th(MedalTier.gold),
            max
          ]);
          for (var i = 0; i < MonthlyProgressCard.parts; i++) {
            final part =
                tester.getRect(find.byKey(MonthlyProgressCard.partKey(i)));
            final fill =
                tester.getRect(find.byKey(MonthlyProgressCard.partFillKey(i)));
            expect(fill.width / part.width,
                closeTo(MonthlyProgressCard.partFill(i, score, bounds), .02),
                reason: '$score, part $i');
          }
          // The gaps at the thresholds, each medal over its gap.
          for (final (i, tier) in MedalTier.values.indexed) {
            final place = bar.left + th(tier) / max * bar.width;
            final left =
                tester.getRect(find.byKey(MonthlyProgressCard.partKey(i)));
            final right =
                tester.getRect(find.byKey(MonthlyProgressCard.partKey(i + 1)));
            expect((left.right + right.left) / 2, closeTo(place, .5));
            expect(
                right.left - left.right, closeTo(MonthlyProgressCard.gap, .5));
            expect(
                tester
                    .getRect(find.byKey(MonthlyProgressCard.medalKey(tier)))
                    .center
                    .dx,
                closeTo(place, .5));
            expect(find.byKey(MonthlyProgressCard.tickKey(tier)),
                score >= th(tier) ? findsOneWidget : findsNothing);
          }
          expect(
              tester.getRect(find.byKey(MonthlyProgressCard.dotKey)).center.dx,
              closeTo(bar.left + score / max * bar.width, .5));
          expect(
              tester
                  .widget<Text>(find.byKey(MonthlyProgressCard.pointsKey))
                  .textSpan!
                  .toPlainText(),
              '$score / $max');
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets(
        'the month, theme and active days head it; the points at the top '
        'right; VoiceOver reads the bar', (tester) async {
      await pumpCollection(tester,
          width: 375,
          currentProgress: november(score: 80),
          themeIds: storedThemes);
      expect(find.text('November progress'), findsOneWidget);
      expect(find.text('Ember Peak · 6 active days'), findsOneWidget);
      final card = tester.getRect(find.byKey(MonthlyProgressCard.cardKey));
      final points = tester.getRect(find.byKey(MonthlyProgressCard.pointsKey));
      final title = tester.getRect(find.text('November progress'));
      expect(points.right, closeTo(card.right - 18, 1));
      expect(points.top, lessThan(title.bottom));
      final max = MonthlyMedalRules.maxScore(2026, 11);
      expect(find.bySemanticsLabel(RegExp('^80 of $max points; Bronze at ')),
          findsOneWidget);
    });

    for (final brightness in Brightness.values) {
      testWidgets('renders in ${brightness.name}', (tester) async {
        await pumpCollection(tester,
            width: 390,
            brightness: brightness,
            currentProgress: november(score: 120),
            themeIds: storedThemes);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('it sits under the shelf, as a card of its own',
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
