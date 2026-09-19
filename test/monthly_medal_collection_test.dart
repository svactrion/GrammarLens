import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';

void main() {
  Future<void> pumpCollection(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    MonthlyMedalProgress? currentProgress,
    List<MonthlyMedalResult> results = const [],
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
              currentProgress: currentProgress,
              results: results,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    for (final size in AppTextSize.values) {
      testWidgets('locked collection fits 320px in $brightness at $size',
          (tester) async {
        await pumpCollection(tester, brightness: brightness, textSize: size);

        expect(find.text('Bronze'), findsOneWidget);
        expect(find.text('Silver'), findsOneWidget);
        expect(find.text('Gold'), findsOneWidget);
        expect(find.text('Not earned'), findsNWidgets(3));
        expect(find.text('Earned'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('progress and history fit 320px in $brightness at $size',
          (tester) async {
        await pumpCollection(
          tester,
          brightness: brightness,
          textSize: size,
          currentProgress: currentProgress,
          results: [bronzeResult, noMedalResult],
        );

        expect(find.text('In progress'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('locked and earned tiers have explicit semantics',
      (tester) async {
    await pumpCollection(tester, results: [bronzeResult]);

    expect(find.bySemanticsLabel('Bronze medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Silver medal, locked.'), findsOneWidget);
    expect(find.bySemanticsLabel('Gold medal, locked.'), findsOneWidget);
  });

  // docs/prd-gamification.md §M6.2: a month's highest tier is a ladder, not
  // three independent badges — Gold already implies Bronze and Silver were
  // cleared that same month, so all three specimens read as earned.
  testWidgets(
      'a Gold-finalized month also unlocks the Bronze and Silver specimens',
      (tester) async {
    await pumpCollection(tester, results: [goldResult]);

    expect(find.bySemanticsLabel('Bronze medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Silver medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Gold medal, earned.'), findsOneWidget);
    expect(find.text('Not earned'), findsNothing);
    expect(find.text('Earned'), findsNWidgets(3));
  });

  testWidgets('a Silver-finalized month unlocks Bronze and Silver, not Gold',
      (tester) async {
    await pumpCollection(tester, results: [silverResult]);

    expect(find.bySemanticsLabel('Bronze medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Silver medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Gold medal, locked.'), findsOneWidget);
  });

  testWidgets(
      'unlocking looks at the highest tier across every finalized month, '
      'not just the most recent one', (tester) async {
    // goldResult (August) is listed after bronzeResult (September) here —
    // deliberately not already-sorted-descending, since a caller's own
    // ordering (e.g. StorageService's `month DESC`) shouldn't matter to
    // which tiers this widget marks as earned.
    await pumpCollection(tester, results: [bronzeResult, goldResult]);

    expect(find.bySemanticsLabel('Bronze medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Silver medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Gold medal, earned.'), findsOneWidget);
  });

  testWidgets(
      'a No-medal month mixed with a real finalized month is ignored for '
      'unlocking, not treated as resetting it', (tester) async {
    await pumpCollection(tester, results: [noMedalResult, bronzeResult]);

    expect(find.bySemanticsLabel('Bronze medal, earned.'), findsOneWidget);
    expect(find.bySemanticsLabel('Silver medal, locked.'), findsOneWidget);
    expect(find.bySemanticsLabel('Gold medal, locked.'), findsOneWidget);
  });

  testWidgets('shows current progress and finalized history', (tester) async {
    await pumpCollection(
      tester,
      currentProgress: currentProgress,
      results: [bronzeResult, noMedalResult],
    );

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('42 / 300 points · 6 active days'), findsOneWidget);
    expect(find.text('Bronze medal'), findsOneWidget);
    expect(find.text('No medal'), findsOneWidget);
  });
}

const currentProgress = MonthlyMedalProgress(
  year: 2026,
  month: 9,
  score: 42,
  maxScore: 300,
  activeDays: 6,
  correct: 18,
  wrong: 6,
  skipped: 6,
);

final bronzeResult = MonthlyMedalResult(
  year: 2026,
  month: 8,
  score: 80,
  maxScore: 310,
  activeDays: 10,
  correct: 30,
  wrong: 20,
  skipped: 0,
  tier: MedalTier.bronze,
  ruleVersion: 1,
  finalizedAt: DateTime(2026, 9, 1),
);

final silverResult = MonthlyMedalResult(
  year: 2026,
  month: 8,
  score: 160,
  maxScore: 310,
  activeDays: 25,
  correct: 70,
  wrong: 20,
  skipped: 35,
  tier: MedalTier.silver,
  ruleVersion: 1,
  finalizedAt: DateTime(2026, 9, 1),
);

final goldResult = MonthlyMedalResult(
  year: 2026,
  month: 8,
  score: 305,
  maxScore: 310,
  activeDays: 31,
  correct: 150,
  wrong: 5,
  skipped: 0,
  tier: MedalTier.gold,
  ruleVersion: 1,
  finalizedAt: DateTime(2026, 9, 1),
);

final noMedalResult = MonthlyMedalResult(
  year: 2026,
  month: 7,
  score: 20,
  maxScore: 310,
  activeDays: 3,
  correct: 5,
  wrong: 10,
  skipped: 0,
  tier: null,
  ruleVersion: 1,
  finalizedAt: DateTime(2026, 8, 1),
);
