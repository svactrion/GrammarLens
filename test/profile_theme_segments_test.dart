import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

/// 1.2.0 Batch 7: inside the Appearance card the theme control is narrower
/// than before, and at 320 pt "System" broke mid-word beside its icon. The
/// icons stay only while the longest label fits beside one. Measured with
/// the bundled Nunito Sans: the test font is far wider and wraps even
/// "Small" at 320 pt with Large text.
class _Storage extends StorageService {
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];

  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async =>
      const MonthlyMedalProgress(
        year: 2026,
        month: 10,
        score: 7,
        maxScore: 310,
        activeDays: 1,
        correct: 0,
        wrong: 0,
        skipped: 0,
      );

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];

  @override
  Future<WelcomeBadge?> getWelcomeBadge() async => null;
}

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  for (final (width, size, icons) in [
    (320.0, AppTextSize.large, false),
    (320.0, AppTextSize.medium, false),
    (390.0, AppTextSize.medium, true),
    (390.0, AppTextSize.large, true),
    (430.0, AppTextSize.large, true),
  ]) {
    testWidgets(
        '${width.toInt()} pt, ${size.name}: ${icons ? 'icons kept' : 'no icons'}, '
        'no label broken over two lines', (tester) async {
      tester.view.physicalSize = Size(width, 2400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light, textSize: size),
        home: SettingsScreen(
          active: true,
          themeMode: AppThemeMode.system,
          onSelectThemeMode: (_) {},
          textSize: size,
          onSelectTextSize: (_) {},
          profile: const UserProfile(
              name: 'Ada', learningGoal: LearningGoal.general),
          storageService: _Storage(),
          onProfileUpdated: (_) {},
          onResetOnboarding: () {},
        ),
      ));
      await tester.pumpAndSettle();
      final control = find.ancestor(
          of: find.text('System'),
          matching: find.byType(SegmentedButton<AppThemeMode>));
      expect(find.descendant(of: control, matching: find.byType(Icon)),
          icons ? findsNWidgets(3) : findsNothing);
      final line = tester.getSize(find.text('Dark')).height;
      for (final label in ['System', 'Light', 'Small', 'Medium', 'Large']) {
        expect(tester.getSize(find.text(label)).height, line, reason: label);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
