import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/mistake_breakdown.dart';

/// Regression coverage for docs/design-audit.md, Batch 0 item 1: a skipped
/// question's correct answer used to render on the same green success
/// color as an actual correction, labeled "CORRECTED" — reading as if a
/// mistake had been made and fixed, on a question that was never
/// attempted. Fixed by deriving skippedness from the answer already being
/// empty (see mistake_breakdown.dart's own `isSkipped` comment) rather
/// than a caller-supplied flag.
void main() {
  Color? boxColor(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(label), matching: find.byType(Container)).first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  Future<void> pump(
    WidgetTester tester, {
    required String userAnswer,
    required String correctedAnswer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: MistakeBreakdown(
            prompt: 'She ___ to the store yesterday.',
            userAnswer: userAnswer,
            correctedAnswer: correctedAnswer,
            explanation: null,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'a skipped question (empty answer) shows the correct answer in the '
      'neutral box, labeled CORRECT ANSWER — not CORRECTED', (tester) async {
    await pump(tester, userAnswer: '', correctedAnswer: 'went');

    expect(find.text('CORRECT ANSWER'), findsOneWidget);
    expect(find.text('CORRECTED'), findsNothing);
    // Neither the skipped answer nor a "YOU WROTE" box exist to show it in.
    expect(find.text('YOU WROTE'), findsNothing);

    final theme = buildAppTheme(Brightness.light);
    expect(boxColor(tester, 'CORRECT ANSWER'), theme.colorScheme.surface);
  });

  testWidgets(
      'a real wrong answer still shows the correction on the success '
      'color, labeled CORRECTED', (tester) async {
    await pump(tester, userAnswer: 'goed', correctedAnswer: 'went');

    expect(find.text('CORRECTED'), findsOneWidget);
    expect(find.text('CORRECT ANSWER'), findsNothing);
    expect(find.text('YOU WROTE'), findsOneWidget);

    final semantic = buildAppTheme(Brightness.light).extension<SemanticColors>()!;
    expect(boxColor(tester, 'CORRECTED'), semantic.correctBackground);
  });
}
