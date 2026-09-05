import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/practice_step_footer.dart';

/// Covers item 4's fix (docs/design-audit.md D3): the primary button must
/// never be labeled "Skip" or double as the skip action, and its disabled
/// state must stay legible rather than repeating the onboarding "Continue"
/// contrast failure.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool showBack = false,
    bool primaryEnabled = true,
    VoidCallback? onPrimary,
    VoidCallback? onSkip,
    VoidCallback? onBack,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: PracticeStepFooter(
            showBack: showBack,
            onBack: onBack ?? () {},
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

  testWidgets('Skip is a quiet text action, always present regardless of '
      'whether the primary button is enabled', (tester) async {
    await pump(tester, primaryEnabled: true);
    expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);

    await pump(tester, primaryEnabled: false);
    expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
  });

  testWidgets('the primary button is disabled while primaryEnabled is false',
      (tester) async {
    var primaryTapped = false;
    await pump(tester, primaryEnabled: false, onPrimary: () => primaryTapped = true);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    expect(primaryTapped, isFalse);
  });

  testWidgets('the primary button fires onPrimary once enabled', (tester) async {
    var primaryTapped = false;
    await pump(tester, primaryEnabled: true, onPrimary: () => primaryTapped = true);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    expect(primaryTapped, isTrue);
  });

  testWidgets('tapping Skip advances even while the primary button is '
      'disabled', (tester) async {
    var skipped = false;
    await pump(tester, primaryEnabled: false, onSkip: () => skipped = true);

    await tester.tap(find.widgetWithText(TextButton, 'Skip'));
    expect(skipped, isTrue);
  });

  testWidgets('Back only renders when showBack is true', (tester) async {
    await pump(tester, showBack: false);
    expect(find.widgetWithText(OutlinedButton, 'Back'), findsNothing);

    await pump(tester, showBack: true);
    expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);
  });

  testWidgets(
      'the disabled primary button uses an explicit, legible color pairing '
      '— never the default translucent-over-orange treatment that made '
      "onboarding's disabled Continue nearly invisible", (tester) async {
    await pump(tester, primaryEnabled: false);

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'));
    final theme = buildAppTheme(Brightness.light);
    final resolved = button.style!.backgroundColor!.resolve({WidgetState.disabled});
    final resolvedFg = button.style!.foregroundColor!.resolve({WidgetState.disabled});

    expect(resolved, theme.colorScheme.surfaceContainerHighest);
    expect(resolvedFg, theme.colorScheme.onSurfaceVariant);
    // Specifically not the page's own orange or a translucent variant of
    // it — the failure mode this guards against.
    expect(resolved, isNot(theme.colorScheme.primary));
  });
}
