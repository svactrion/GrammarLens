import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';

/// The celebration layer over the result screen (Batch 5, N15, N28).
final celebrationFinder = find.byType(MedalCelebration);

/// Expects the celebration open with a title starting with [title] (V11
/// adds the name: "Welcome to the climb, Ada!"), closes it with one tap
/// and lets it go: its close (a shrink and a fade) and its confetti.
Future<void> closeCelebration(WidgetTester tester,
    {String title = 'Welcome to the climb'}) async {
  expect(celebrationFinder, findsOneWidget);
  expect(
      find.descendant(
          of: celebrationFinder,
          matching: find.textContaining(RegExp('^${RegExp.escape(title)}'))),
      findsOneWidget);
  await tester.tap(celebrationFinder);
  await tester.pump();
  await tester.pump(MedalCelebration.close + const Duration(milliseconds: 50));
  await tester.pump();
  expect(celebrationFinder, findsNothing);
}

/// SPEC §4 (v11, fix round 3 A1): V10 Results → V11 Welcome badge → V12.
/// The results show first with no layer over them; "Climb my first step"
/// opens the badge; closing the badge goes on (the first climb, or the
/// route pops).
Future<void> climbThroughWelcome(WidgetTester tester) async {
  expect(celebrationFinder, findsNothing,
      reason: 'the results come before the badge');
  final climb = find.text('Climb my first step');
  expect(climb, findsOneWidget);
  await tester.tap(climb);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await closeCelebration(tester);
}
