import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';

void main() {
  const profile = UserProfile(name: 'Ada', learningGoal: LearningGoal.work);

  Future<void> pumpSettings(
    WidgetTester tester, {
    AppThemeMode themeMode = AppThemeMode.system,
    ValueChanged<AppThemeMode>? onSelectThemeMode,
    ValueChanged<UserProfile>? onProfileUpdated,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          themeMode: themeMode,
          onSelectThemeMode: onSelectThemeMode ?? (_) {},
          profile: profile,
          storageService: StorageService(),
          onProfileUpdated: onProfileUpdated ?? (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the current name from the profile', (tester) async {
    await pumpSettings(tester);
    expect(find.widgetWithText(TextField, 'Ada'), findsOneWidget);
  });

  testWidgets('Save is disabled once the name is cleared', (tester) async {
    await pumpSettings(tester);
    FilledButton saveButton() =>
        tester.widget(find.widgetWithText(FilledButton, 'Save'));

    expect(saveButton().onPressed, isNotNull);

    await tester.enterText(find.widgetWithText(TextField, 'Ada'), '');
    await tester.pump();
    expect(saveButton().onPressed, isNull);
  });

  testWidgets('picking a theme segment calls onSelectThemeMode',
      (tester) async {
    AppThemeMode? selected;
    await pumpSettings(
      tester,
      onSelectThemeMode: (mode) => selected = mode,
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();

    expect(selected, AppThemeMode.dark);
  });

  testWidgets('reset progress asks for confirmation before doing anything',
      (tester) async {
    await pumpSettings(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset progress data'));
    await tester.pumpAndSettle();
    expect(find.text('Reset progress?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset progress?'), findsNothing);
    // sqflite has no platform channel in this test environment, so a real
    // reset call would surface as an error snackbar — its absence here
    // confirms Cancel never triggered one.
    expect(find.textContaining('Could not reset'), findsNothing);
  });
}
