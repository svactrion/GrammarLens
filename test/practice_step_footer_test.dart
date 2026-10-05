import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/practice_step_footer.dart';

/// Covers docs/design-audit.md D3: the primary button must never be
/// labeled "Skip" or double as the skip action, and its disabled state
/// must stay legible rather than repeating the onboarding "Continue"
/// contrast failure. Skip sits beside the primary action, clearly narrower
/// than it, so it never reads as an equal alternative. Question V2 (the
/// additional screens package): Skip is a link-coloured text button, the
/// primary action is the brand orange, both at least 48 tall, 10 apart.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool primaryEnabled = true,
    VoidCallback? onPrimary,
    VoidCallback? onSkip,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: PracticeStepFooter(
            primaryLabel: 'Next',
            primaryEnabled: primaryEnabled,
            onPrimary: onPrimary ?? () {},
            onSkip: onSkip ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('the primary button is never labeled "Skip"', (tester) async {
    await pump(tester, primaryEnabled: false);
    expect(find.widgetWithText(FilledButton, 'Skip'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
  });

  testWidgets(
      'Skip is a text button, always present regardless of whether '
      'the primary button is enabled', (tester) async {
    await pump(tester, primaryEnabled: true);
    expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);

    await pump(tester, primaryEnabled: false);
    expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
  });

  testWidgets(
      'Skip is clearly narrower than the primary button, never an '
      'equal-width alternative to it (D3)', (tester) async {
    await pump(tester);
    final skipWidth =
        tester.getSize(find.widgetWithText(TextButton, 'Skip')).width;
    final primaryWidth =
        tester.getSize(find.widgetWithText(FilledButton, 'Next')).width;
    expect(skipWidth, lessThan(primaryWidth));
  });

  testWidgets('Skip and the primary button are both 48 tall, 10 apart',
      (tester) async {
    await pump(tester);
    final skipRect = tester.getRect(find.widgetWithText(TextButton, 'Skip'));
    final primaryRect =
        tester.getRect(find.widgetWithText(FilledButton, 'Next'));

    expect(skipRect.height, 48);
    expect(primaryRect.height, 48);
    expect(primaryRect.left - skipRect.right, 10);
    expect(skipRect.width, greaterThanOrEqualTo(63));
  });

  testWidgets('the primary button is disabled while primaryEnabled is false',
      (tester) async {
    var primaryTapped = false;
    await pump(tester,
        primaryEnabled: false, onPrimary: () => primaryTapped = true);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    expect(primaryTapped, isFalse);
  });

  testWidgets('the primary button fires onPrimary once enabled',
      (tester) async {
    var primaryTapped = false;
    await pump(tester,
        primaryEnabled: true, onPrimary: () => primaryTapped = true);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    expect(primaryTapped, isTrue);
  });

  testWidgets(
      'tapping Skip advances even while the primary button is '
      'disabled', (tester) async {
    var skipped = false;
    await pump(tester, primaryEnabled: false, onSkip: () => skipped = true);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    expect(skipped, isTrue);
  });

  testWidgets(
      'the disabled primary button uses an explicit, legible color pairing '
      '— never the default translucent-over-orange treatment that made '
      "onboarding's disabled Continue nearly invisible", (tester) async {
    await pump(tester, primaryEnabled: false);

    final theme = buildAppTheme(Brightness.light);
    final palette = theme.extension<AppPalette>()!;
    final button =
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
    // Question V2: the footer styles its orange button itself, with the
    // app's explicit disabled pairing.
    final style = button.style!;
    final resolved = style.backgroundColor!.resolve({WidgetState.disabled});
    final resolvedFg = style.foregroundColor!.resolve({WidgetState.disabled});

    expect(resolved, palette.disabledFill);
    expect(resolvedFg, palette.disabledLabel);
    expect(resolved!.a, 1.0, reason: 'opaque, not a translucent overlay');
    // Specifically not the page's own orange or a translucent variant of
    // it — the failure mode this guards against.
    expect(resolved, isNot(theme.colorScheme.primary));
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'the primary action is the brand orange with the onOrange text and '
        'no edge, in ${brightness.name} mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(brightness),
        home: Scaffold(
          body: PracticeStepFooter(
            primaryLabel: 'Next',
            primaryEnabled: true,
            onPrimary: () {},
            onSkip: () {},
          ),
        ),
      ));
      final theme = buildAppTheme(brightness);
      final style = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .style!;
      expect(style.backgroundColor!.resolve({}), theme.colorScheme.primary);
      expect(style.foregroundColor!.resolve({}), theme.colorScheme.onPrimary);
      expect(style.side!.resolve({}), BorderSide.none);
      final skip = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Skip'))
          .style!;
      expect(skip.foregroundColor!.resolve({}), theme.colorScheme.secondary);
    });
  }
}
