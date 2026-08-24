import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_theme_mode.dart';
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
          onSelectThemeMode: (AppThemeMode _) {},
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
  });
}
