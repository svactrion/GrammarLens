import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          userName: 'Ada',
          claudeService: ClaudeService(),
          storageService: StorageService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('greets the user by their onboarding name', (tester) async {
    await pumpHome(tester);
    expect(find.text('Welcome back, Ada'), findsOneWidget);
  });

  testWidgets('shows all three mode cards', (tester) async {
    await pumpHome(tester);
    expect(find.text('Topic Practice'), findsOneWidget);
    expect(find.text('Streak Mode'), findsOneWidget);
    expect(find.text('Voice Practice'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('Topic Practice opens the existing MVP loop', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();
    expect(find.byType(TopicPracticeScreen), findsOneWidget);
  });

  testWidgets('Streak Mode tap is informative, not a dead tap',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Streak Mode'));
    await tester.pump();
    expect(find.text('Streak Mode is coming soon.'), findsOneWidget);
    // A real dialog, not the old SnackBar (which is where the reported bug
    // came from — see the other tests in this group).
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Voice Practice tap is informative, not a dead tap',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Voice Practice'));
    await tester.pump();
    expect(
      find.text('Voice Practice will be part of premium, in a later update.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'two taps fired before any frame renders only open one dialog',
      (tester) async {
    await pumpHome(tester);
    // Deliberately no pump between these two. In practice the barrier from
    // the first tap's dialog already ends up blocking the second (hence
    // warnIfMissed: false below) — the `_infoDialogOpen` guard is the
    // backstop for the narrower race where it doesn't.
    await tester.tap(find.text('Voice Practice'));
    await tester.tap(find.text('Voice Practice'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('the dialog closes on its own button and does not linger',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Streak Mode'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // And it can be opened again afterwards — the guard flag correctly
    // reset rather than permanently locking the card out.
    await tester.tap(find.text('Streak Mode'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
      'the dialog is modal, so it cannot be tapped through into another '
      'screen while open', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Streak Mode'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    // "Topic Practice" is still technically in the tree underneath the
    // dialog's modal barrier — tapping it must not reach the card and
    // navigate, which is exactly the "follows you to another screen" bug
    // the old app-wide SnackBar had.
    await tester.tap(find.text('Topic Practice'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(TopicPracticeScreen), findsNothing);
  });
}
