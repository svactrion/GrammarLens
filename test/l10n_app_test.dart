import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/language_picker_screen.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

import 'support/recording_analytics_sink.dart';

/// 1.4.0 B3 at the app root: the delegates are wired, the stored choice
/// loads, a change in Profile is stored and reported, and `ui_language`
/// is set at startup (docs/analytics-plan.md §3).
class _Storage extends StorageService {
  AppLanguage stored;
  final List<AppLanguage> writes = [];
  _Storage(this.stored);

  @override
  Future<UserProfile?> getUserProfile() async =>
      const UserProfile(name: 'Ada', learningGoal: LearningGoal.work);

  @override
  Future<AppLanguage> getLanguage() async => stored;

  @override
  Future<void> setLanguage(AppLanguage language) async {
    stored = language;
    writes.add(language);
  }

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.clearAccessibilityFeaturesTestValue();
    dispatcher.clearLocalesTestValue();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    _Storage storage,
    RecordingAnalyticsSink sink,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GrammarLensApp(
      storageService: storage,
      analyticsService: AnalyticsService(sink: sink),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the app carries the AppLocalizations delegate', (tester) async {
    await pumpApp(
        tester, _Storage(AppLanguage.system), RecordingAnalyticsSink());
    final context = tester.element(find.byType(FloatingNavShell));
    expect(Localizations.of<AppLocalizations>(context, AppLocalizations),
        isNotNull);
    expect(Localizations.localeOf(context), const Locale('en'));
  });

  testWidgets(
      'ui_language is set at startup to the resolved language, never '
      '"system"', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
    final sink = RecordingAnalyticsSink();
    await pumpApp(tester, _Storage(AppLanguage.system), sink);
    // No Japanese strings in this build yet (B5): English is shown.
    expect(sink.userProperties['ui_language'], 'en');
    expect(sink.events.where((e) => e.name.contains('language')), isEmpty);
  });

  testWidgets(
      'a stored choice this build has no strings for shows English and '
      'reports it', (tester) async {
    final sink = RecordingAnalyticsSink();
    await pumpApp(tester, _Storage(AppLanguage.de), sink);
    final context = tester.element(find.byType(FloatingNavShell));
    expect(Localizations.localeOf(context), const Locale('en'));
    expect(sink.userProperties['ui_language'], 'en');
  });

  testWidgets(
      'Profile → Language: the row shows the choice; picking one stores and '
      'reports it', (tester) async {
    final storage = _Storage(AppLanguage.system);
    final sink = RecordingAnalyticsSink();
    await pumpApp(tester, storage, sink);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final row = find.byKey(SettingsScreen.languageRowKey);
    // The row's own scrollable: the other tabs stay alive behind Profile.
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    expect(find.descendant(of: row, matching: find.text('System default')),
        findsOneWidget);

    sink.userPropertyWrites.clear();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(LanguagePickerScreen), findsOneWidget);
    await tester
        .tap(find.byKey(LanguagePickerScreen.optionKey(AppLanguage.en)));
    await tester.pumpAndSettle();

    expect(find.byType(LanguagePickerScreen), findsNothing);
    expect(storage.writes, [AppLanguage.en]);
    expect(sink.userPropertyWrites, ['ui_language']);
    expect(sink.userProperties['ui_language'], 'en');
    expect(find.descendant(of: row, matching: find.text('English')),
        findsOneWidget);
  });

  testWidgets('a device-language change on System default is reported',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    await pumpApp(tester, _Storage(AppLanguage.system), sink);
    sink.userPropertyWrites.clear();
    tester.platformDispatcher.localesTestValue = const [Locale('de')];
    await tester.pumpAndSettle();
    expect(sink.userPropertyWrites, ['ui_language']);
  });
}
