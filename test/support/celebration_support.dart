import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';

/// The celebration layer over the result screen (Batch 5, N15).
final celebrationFinder = find.byType(MedalCelebration);

/// Expects the celebration open with [title], closes it with one tap and
/// lets it go (its confetti included).
Future<void> closeCelebration(WidgetTester tester,
    {String title = 'Welcome to the climb'}) async {
  expect(celebrationFinder, findsOneWidget);
  expect(find.descendant(of: celebrationFinder, matching: find.text(title)),
      findsOneWidget);
  await tester.tap(celebrationFinder);
  await tester.pump();
  expect(celebrationFinder, findsNothing);
}
