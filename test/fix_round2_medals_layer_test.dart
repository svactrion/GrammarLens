import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/medals_layer.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

/// Fix round 2, item 6: PF02's order across a year boundary. Correct
/// behaviour: the tier counters on top; year headers, newest year first;
/// under each year a 3-column grid, newest at the top left, read left to
/// right and top to bottom; the running month first ("in progress"); the
/// Welcome badge at the month it was earned.
void main() {
  MonthlyMedalResult result(int year, int month, MedalTier tier) =>
      MonthlyMedalResult(
        year: year,
        month: month,
        score: 100,
        maxScore: MonthlyMedalRules.maxScore(year, month),
        activeDays: 10,
        correct: 0,
        wrong: 0,
        skipped: 0,
        tier: tier,
        ruleVersion: 1,
        finalizedAt: DateTime(year, month + 1, 1),
      );

  final collection = MonthlyMedalCollection(
    welcomeBadge: WelcomeBadge(
        earnedAt: DateTime(2025, 12, 3), ruleVersion: 1, backfilled: false),
    currentProgress: const MonthlyMedalProgress(
      year: 2026,
      month: 3,
      score: 4,
      maxScore: 155,
      activeDays: 1,
      correct: 4,
      wrong: 1,
      skipped: 0,
    ),
    // In storage order (oldest first), as the app reads them.
    results: [
      result(2025, 11, MedalTier.silver),
      result(2025, 12, MedalTier.gold),
      result(2026, 1, MedalTier.silver),
      result(2026, 2, MedalTier.bronze),
    ],
  );

  Future<void> open(WidgetTester tester,
      {TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = const Size(428, 926) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAllMedals(context, collection),
              child: const Text('See all'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
  }

  test(
      'the slots: newest first, the running month first, the Welcome badge '
      'after the month it was earned in', () {
    final slots = collection.allSlots();
    expect(
        [for (final s in slots) s == null ? 'welcome' : '${s.year}-${s.month}'],
        ['2026-3', '2026-2', '2026-1', '2025-12', 'welcome', '2025-11']);
    expect(slots.first!.running, isTrue);
    // The shelf shows the first three of the same order.
    expect([for (final s in collection.shelfSlots()) '${s!.year}-${s.month}'],
        ['2026-3', '2026-2', '2026-1']);
    // Counters: finalized medals only.
    expect(collection.countOf(MedalTier.gold), 1);
    expect(collection.countOf(MedalTier.silver), 2);
    expect(collection.countOf(MedalTier.bronze), 1);
  });

  testWidgets(
      'counters on top, then 2026 before 2025, each a 3-column '
      'grid read left to right, top to bottom', (tester) async {
    await open(tester);
    final counters = find.byKey(MedalsLayer.countersKey);
    for (final chip in ['1 Gold', '2 Silver', '1 Bronze', '1 Welcome']) {
      expect(find.descendant(of: counters, matching: find.text(chip)),
          findsOneWidget);
    }
    expect(find.text('All medals'), findsOneWidget);
    expect(find.text('Newest first'), findsOneWidget);
    final y2026 = tester.getTopLeft(find.byKey(MedalsLayer.yearKey(2026)));
    final y2025 = tester.getTopLeft(find.byKey(MedalsLayer.yearKey(2025)));
    expect(tester.getBottomLeft(counters).dy, lessThan(y2026.dy));
    expect(y2026.dy, lessThan(y2025.dy));

    Offset at(Key key) => tester.getTopLeft(find.byKey(key).last);
    final mar = at(MonthlyMedalCollection.slotKey(2026, 3));
    final feb = at(MonthlyMedalCollection.slotKey(2026, 2));
    final jan = at(MonthlyMedalCollection.slotKey(2026, 1));
    final dec = at(MonthlyMedalCollection.slotKey(2025, 12));
    final welcome = at(MonthlyMedalCollection.welcomeSlotKey);
    final nov = at(MonthlyMedalCollection.slotKey(2025, 11));
    // 2026: one row, newest at the left.
    expect(mar.dy, feb.dy);
    expect(feb.dy, jan.dy);
    expect(mar.dx, lessThan(feb.dx));
    expect(feb.dx, lessThan(jan.dx));
    // 2025 under its header: December, the Welcome badge (earned in
    // December), November.
    expect(dec.dy, greaterThan(y2025.dy));
    expect(dec.dy, welcome.dy);
    expect(welcome.dy, nov.dy);
    expect(dec.dx, lessThan(welcome.dx));
    expect(welcome.dx, lessThan(nov.dx));
    // Three equal columns: the first column of each year lines up.
    expect(dec.dx, closeTo(mar.dx, .01));
    // The running month says so; the others their tier; the badge its name.
    final marCell = find.byKey(MonthlyMedalCollection.slotKey(2026, 3)).last;
    expect(find.descendant(of: marCell, matching: find.text('in progress')),
        findsOneWidget);
    expect(find.descendant(of: marCell, matching: find.text('Mar')),
        findsOneWidget);
    final decCell = find.byKey(MonthlyMedalCollection.slotKey(2025, 12)).last;
    expect(find.descendant(of: decCell, matching: find.text('Gold')),
        findsOneWidget);
    final badge = find.byKey(MonthlyMedalCollection.welcomeSlotKey).last;
    expect(find.descendant(of: badge, matching: find.text('Welcome')),
        findsOneWidget);
    expect(
        find.descendant(of: badge, matching: find.text('Dec')), findsOneWidget);
  });

  testWidgets('a fourth medal in a year starts the second row at the left',
      (tester) async {
    final many = MonthlyMedalCollection(results: [
      for (var m = 1; m <= 4; m++) result(2026, m, MedalTier.bronze),
    ]);
    tester.view.physicalSize = const Size(428, 926) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAllMedals(context, many),
            child: const Text('See all'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    Offset at(int m) => tester
        .getTopLeft(find.byKey(MonthlyMedalCollection.slotKey(2026, m)).last);
    expect(at(4).dy, at(2).dy);
    expect(at(1).dy, greaterThan(at(4).dy));
    expect(at(1).dx, closeTo(at(4).dx, .01));
    expect(
        find.descendant(
            of: find.byKey(MedalsLayer.countersKey),
            matching: find.text('0 Welcome')),
        findsOneWidget);
  });

  testWidgets('RTL reads right to left', (tester) async {
    await open(tester, direction: TextDirection.rtl);
    Offset at(Key key) => tester.getTopLeft(find.byKey(key).last);
    expect(at(MonthlyMedalCollection.slotKey(2026, 3)).dx,
        greaterThan(at(MonthlyMedalCollection.slotKey(2026, 2)).dx));
  });
}
