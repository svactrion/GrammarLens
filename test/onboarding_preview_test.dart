import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/screens/debug_panel_screen.dart';
import 'package:grammar_lens/screens/onboarding_preview.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/screens/welcome_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

import 'support/l10n_support.dart';

/// The debug panel's "Preview onboarding" (1.4.0 B5): the real Welcome and
/// onboarding screens, run to the end, leave a fresh database fresh, and
/// finishing or leaving returns to the panel.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  const dbName = 'test_onboarding_preview.db';
  setUp(() async {
    await databaseFactory
        .deleteDatabase(join(await getDatabasesPath(), dbName));
    // Welcome's looping motion off, so the flow settles.
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() => TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .clearAccessibilityFeaturesTestValue());

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    DebugPanelScreen(onResetLocalData: () async {}))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(DebugPanelScreen.previewOnboardingKey), 200,
        scrollable: find.byType(Scrollable).first);
    await tester
        .ensureVisible(find.byKey(DebugPanelScreen.previewOnboardingKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DebugPanelScreen.previewOnboardingKey));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the whole flow, data sheet included, to Start: back on the panel, '
      'no profile and no day-0 set stored', (tester) async {
    final storage = StorageService(dbName: dbName);
    await pumpPanel(tester);
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.tap(find.text(en.welcomeGetStarted));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
    await tester.pump();
    await tester.tap(find.byKey(OnboardingScreen.continueKey));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(OnboardingScreen.dataLinkKey));
    await tester.tap(find.byKey(OnboardingScreen.dataLinkKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(OnboardingScreen.gotItKey));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(OnboardingScreen.goalKey(LearningGoal.work)));
    await tester.tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.work)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(OnboardingScreen.startKey));
    await tester.tap(find.byKey(OnboardingScreen.startKey));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPreview), findsNothing);
    expect(find.byType(DebugPanelScreen), findsOneWidget);
    expect(await tester.runAsync(storage.getUserProfile), isNull);
    expect(await tester.runAsync(storage.getDailyTestSetForToday), isNull);
  });

  testWidgets(
      'leaving with the back gesture, from Welcome or the first step: '
      'back on the panel', (tester) async {
    await pumpPanel(tester);
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPreview), findsNothing);
    expect(find.byType(DebugPanelScreen), findsOneWidget);

    await tester.tap(find.byKey(DebugPanelScreen.previewOnboardingKey));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.tap(find.text(en.welcomeGetStarted));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPreview), findsNothing);
    expect(find.byType(DebugPanelScreen), findsOneWidget);
  });
}
