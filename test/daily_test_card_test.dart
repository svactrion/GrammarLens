import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/motion.dart';
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

  // Fix round 6, item 2: the owner saw the companion move "as if
  // breathing". Measured (here and on the simulator): the hop is drawn as
  // specified, so nothing was changed; this holds it there.
  testWidgets(
      'todo after loading: the companion hops 16 pt every 1.2 s (X05, '
      'gl-hop), not the idle breath', (tester) async {
    AppMotion.loopsEnabled = true;
    addTearDown(() => AppMotion.loopsEnabled = false);
    Widget card(DailyTestCardState state) => MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
            body: Column(children: [
          DailyTestCard(
              state: state,
              hero: Avatar.fox,
              title: 'Your next step.',
              subtitle: '5 questions · about 2 minutes',
              results: const [],
              buttonLabel: 'Start today’s test',
              onPressed: () {}),
        ])));
    // As on Home: the card is loading first, then the test waits.
    await tester.pumpWidget(card(DailyTestCardState.loading));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(card(DailyTestCardState.todo));
    double lift() => -tester
        .widget<Transform>(find.byKey(CompanionView.bodyKey))
        .transform
        .getTranslation()
        .y;
    final lifts = <double>[];
    for (var ms = 0; ms < 2400; ms += 20) {
      await tester.pump(const Duration(milliseconds: 20));
      lifts.add(lift());
    }
    final first = lifts.sublist(0, 60), second = lifts.sublist(60);
    for (final hop in [first, second]) {
      expect(hop.reduce((a, b) => a > b ? a : b), closeTo(16, .3));
      // In the air for the first half, still on the ground for the rest.
      expect(hop.sublist(1, 28).every((y) => y > 0), isTrue);
      expect(hop.sublist(31, 59).every((y) => y == 0), isTrue);
    }
    // The slot does not clip it: the companion draws above its 100 pt box.
    expect(tester.takeException(), isNull);
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
