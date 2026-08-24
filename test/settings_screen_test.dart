import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

/// sqflite has no platform channel in this test environment (see
/// widget_test.dart's note), so a real `StorageService.saveUserProfile`
/// call throws — this fake lets the one test that needs `onProfileUpdated`
/// to actually fire (it only fires after a successful save) work without
/// real persistence.
class _FakeStorageService extends StorageService {
  @override
  Future<void> saveUserProfile(UserProfile profile) async {}
}

void main() {
  const profile = UserProfile(name: 'Ada', learningGoal: LearningGoal.work);

  Future<void> pumpSettings(
    WidgetTester tester, {
    AppThemeMode themeMode = AppThemeMode.system,
    ValueChanged<AppThemeMode>? onSelectThemeMode,
    ValueChanged<UserProfile>? onProfileUpdated,
    StorageService? storageService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          themeMode: themeMode,
          onSelectThemeMode: onSelectThemeMode ?? (_) {},
          profile: profile,
          storageService: storageService ?? StorageService(),
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

  bool isSelected(WidgetTester tester, Avatar avatar) {
    final circle = tester.widget<AvatarTile>(
      find.byWidgetPredicate(
        (w) => w is AvatarTile && w.avatar == avatar,
      ),
    );
    return circle.selected;
  }

  testWidgets('shows all eight stock avatars, none selected by default',
      (tester) async {
    await pumpSettings(tester);
    expect(find.byType(AvatarTile), findsNWidgets(Avatar.values.length));
    for (final avatar in Avatar.values) {
      expect(isSelected(tester, avatar), isFalse);
    }
  });

  testWidgets('tapping an avatar selects it, tapping it again clears it',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byWidgetPredicate(
      (w) => w is AvatarTile && w.avatar == Avatar.fox,
    ));
    await tester.pump();
    expect(isSelected(tester, Avatar.fox), isTrue);
    expect(isSelected(tester, Avatar.cat), isFalse);

    await tester.tap(find.byWidgetPredicate(
      (w) => w is AvatarTile && w.avatar == Avatar.fox,
    ));
    await tester.pump();
    expect(isSelected(tester, Avatar.fox), isFalse);
  });

  testWidgets('saving passes the selected avatar to onProfileUpdated',
      (tester) async {
    UserProfile? saved;
    await pumpSettings(
      tester,
      storageService: _FakeStorageService(),
      onProfileUpdated: (p) => saved = p,
    );

    await tester.tap(find.byWidgetPredicate(
      (w) => w is AvatarTile && w.avatar == Avatar.owl,
    ));
    await tester.pump();

    // The Save button sits below the fold at the default test-surface size
    // once the avatar row pushed the rest of the form down.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(saved?.avatar, Avatar.owl);
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
