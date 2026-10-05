import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/question_app_bar.dart';

/// The question screens' header (Question V2, the additional screens
/// package). The title must not shift sideways between question 1 (no
/// previous question) and question 2: Back keeps its 44 × 44 slot on
/// question 1, now shown disabled instead of hidden.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool canGoBack,
    String title = 'Articles',
    VoidCallback? onBack,
    VoidCallback? onClose,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              QuestionHeader(
                title: title,
                subtitle: 'Practice',
                onBack: canGoBack ? (onBack ?? () {}) : null,
                onClose: onClose ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconButton backButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.descendant(
          of: find.byKey(QuestionHeader.backKey),
          matching: find.byType(IconButton)));

  testWidgets(
      "the title's center x is identical on question 1 (Back disabled) and "
      'question 2 (Back enabled)', (tester) async {
    await pump(tester, canGoBack: false);
    final centerOnQ1 = tester.getCenter(find.text('Articles')).dx;

    await pump(tester, canGoBack: true);
    final centerOnQ2 = tester.getCenter(find.text('Articles')).dx;

    expect(centerOnQ2, centerOnQ1);
  });

  testWidgets('on question 1 Back is in its place, disabled', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, canGoBack: false);

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(backButton(tester).onPressed, isNull);
    expect(
      tester.getSemantics(find.descendant(
          of: find.byKey(QuestionHeader.backKey),
          matching: find.byType(IconButton))),
      matchesSemantics(
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        tooltip: 'Previous question',
      ),
    );
    semantics.dispose();
  });

  testWidgets('Back and Close are both 44 × 44', (tester) async {
    await pump(tester, canGoBack: true);

    expect(tester.getSize(find.byKey(QuestionHeader.backKey)),
        const Size(HeaderIconButton.size, HeaderIconButton.size));
    expect(tester.getSize(find.byKey(QuestionHeader.closeKey)),
        const Size(HeaderIconButton.size, HeaderIconButton.size));
    expect(HeaderIconButton.size, 44);
  });

  testWidgets(
      'no counter or progress bar in the header: the counter is in the '
      'question card (docs/design-audit.md, Batch 0 item 7: one, not two)',
      (tester) async {
    await pump(tester, canGoBack: true);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining(' / '), findsNothing);
  });

  testWidgets('a long title wraps, never cut off with an ellipsis',
      (tester) async {
    tester.view.physicalSize = const Size(320, 600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const long = 'Modal verbs for past deduction and speculation';
    await pump(tester, canGoBack: true, title: long);

    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(tester.getSize(find.text(long)).height, greaterThan(30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Back and Close fire their own callbacks',
      (tester) async {
    var backTapped = false;
    var closeTapped = false;
    await pump(tester,
        canGoBack: true,
        onBack: () => backTapped = true,
        onClose: () => closeTapped = true);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(backTapped, isTrue);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(closeTapped, isTrue);
  });
}
