import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/daily_test_card.dart';
import 'package:grammar_lens/widgets/score_ring.dart';

/// X05 / SPEC §1.4: one fixed skeleton for loading / waiting / done; the
/// card never changes size or alignment, at any text size.
void main() {
  Future<void> pump(WidgetTester tester, DailyTestCardState state,
      {double textScale = 1,
      AppTextSize size = AppTextSize.medium,
      String title = 'Your next step.'}) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light, textSize: size),
      home: MediaQuery(
        data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              DailyTestCard(
                state: state,
                hero: Avatar.fox,
                title: title,
                subtitle: '5 questions · about 2 minutes',
                results: const [true, false, true, true, true],
                buttonLabel: state == DailyTestCardState.done
                    ? 'Review answers'
                    : 'Start today’s test',
                onPressed: () {},
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Rect card(WidgetTester tester) => tester.getRect(find.byType(DailyTestCard));

  testWidgets('350 × 256 in all three states', (tester) async {
    for (final state in DailyTestCardState.values) {
      await pump(tester, state);
      expect(card(tester).size, const Size(350, 256), reason: '$state');
      expect(tester.takeException(), isNull);
    }
  });

  for (final (scale, size) in [
    (1.0, AppTextSize.large),
    (2.0, AppTextSize.large),
    (3.1, AppTextSize.large),
  ]) {
    testWidgets(
        'the same size in all states at text scale $scale and ${size.name} '
        'text', (tester) async {
      for (final state in DailyTestCardState.values) {
        await pump(tester, state,
            textScale: scale,
            size: size,
            title: 'A very long title that would never fit on one line');
        expect(card(tester).size, const Size(350, 256), reason: '$state');
        expect(tester.takeException(), isNull, reason: '$state overflow');
      }
    });
  }

  testWidgets('the header, bar and button sit at the same place in every state',
      (tester) async {
    final rows = <DailyTestCardState, List<Rect>>{};
    for (final state in DailyTestCardState.values) {
      await pump(tester, state);
      final cardRect = card(tester);
      final button = state == DailyTestCardState.loading
          ? null
          : tester.getRect(find.byKey(DailyTestCard.buttonKey));
      rows[state] = [cardRect, if (button != null) button];
    }
    expect(
        rows[DailyTestCardState.todo]![1], rows[DailyTestCardState.done]![1]);
  });

  testWidgets('loading: the thinking companion and no button', (tester) async {
    await pump(tester, DailyTestCardState.loading);
    final view = tester.widget<CompanionView>(find.byType(CompanionView));
    expect(view.mood, CompanionMood.think);
    expect(find.byKey(DailyTestCard.buttonKey), findsNothing);
    expect(find.text('Getting today’s test'), findsOneWidget);
  });

  testWidgets('todo: the hopping companion and the Start button',
      (tester) async {
    await pump(tester, DailyTestCardState.todo);
    final view = tester.widget<CompanionView>(find.byType(CompanionView));
    expect(view.hopping, isTrue);
    expect(find.text('Start today’s test'), findsOneWidget);
    expect(find.byType(ScoreRing), findsNothing);
  });

  testWidgets('done: the score ring 4/5 and Review answers', (tester) async {
    await pump(tester, DailyTestCardState.done, title: 'Day 1 complete!');
    expect(find.byType(ScoreRing), findsOneWidget);
    expect(find.text('4/5'), findsOneWidget);
    expect(find.bySemanticsLabel('4 of 5 correct'), findsOneWidget);
    expect(find.text('Review answers'), findsOneWidget);
    expect(find.byType(CompanionView), findsNothing);
  });
}
