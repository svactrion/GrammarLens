import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/first_launch_flow.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

import 'support/fake_native_bridge.dart';
import 'support/recording_analytics_sink.dart';

/// Just enough storage for the app to reach its tab shell (or onboarding
/// when [profile] is null). Anything else throws, which the app tolerates.
class _Storage extends StorageService {
  _Storage(
      {this.profile =
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.general)});

  final UserProfile? profile;
  DailyTestSet? today;

  @override
  Future<UserProfile?> getUserProfile() async => profile;

  @override
  Future<int> deleteStaleDailyTestSets() async => 0;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => today;

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => today;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: 0, correct: 0, wrong: 0, skipped: 0);
}

int _tab(WidgetTester tester) => tester
    .widget<FloatingNavShell>(
        find.byType(FloatingNavShell, skipOffstage: false))
    .selectedIndex;

Future<void> _pumpApp(WidgetTester tester, FakeNativeBridge bridge,
    {_Storage? storage}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(GrammarLensApp(
    storageService: storage ?? _Storage(),
    analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
    nativeBridge: bridge,
    clock: () => DateTime(2026, 11, 18, 9),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('cold start: grammarlens://review opens the Review tab',
      (tester) async {
    await _pumpApp(tester, FakeNativeBridge(initial: 'grammarlens://review'));
    expect(_tab(tester), 1);
  });

  testWidgets('cold start: grammarlens://daily-test opens the Daily Test',
      (tester) async {
    await _pumpApp(
        tester, FakeNativeBridge(initial: 'grammarlens://daily-test'));
    expect(find.byType(DailyTestScreen), findsOneWidget);
  });

  testWidgets('warm: review, then home switch tabs', (tester) async {
    final bridge = FakeNativeBridge();
    await _pumpApp(tester, bridge);
    expect(_tab(tester), 0);
    bridge.pushLink('grammarlens://review');
    await tester.pumpAndSettle();
    expect(_tab(tester), 1);
    bridge.pushLink('grammarlens://home');
    await tester.pumpAndSettle();
    expect(_tab(tester), 0);
  });

  testWidgets('warm: daily-test from another tab goes to Home and opens it',
      (tester) async {
    final bridge = FakeNativeBridge();
    await _pumpApp(tester, bridge);
    bridge.pushLink('grammarlens://review');
    await tester.pumpAndSettle();
    bridge.pushLink('grammarlens://daily-test');
    await tester.pumpAndSettle();
    expect(_tab(tester), 0);
    expect(find.byType(DailyTestScreen), findsOneWidget);
  });

  testWidgets('a link is dropped while a flow is open (DW0-3)', (tester) async {
    final bridge = FakeNativeBridge();
    await _pumpApp(tester, bridge);
    bridge.pushLink('grammarlens://daily-test');
    await tester.pumpAndSettle();
    expect(find.byType(DailyTestScreen), findsOneWidget);
    bridge.pushLink('grammarlens://review');
    await tester.pumpAndSettle();
    // Still in the Daily Test; the tab behind it did not change.
    expect(find.byType(DailyTestScreen), findsOneWidget);
    expect(_tab(tester), 0);
  });

  testWidgets('during onboarding links are dropped', (tester) async {
    final bridge = FakeNativeBridge(initial: 'grammarlens://daily-test');
    await _pumpApp(tester, bridge, storage: _Storage(profile: null));
    expect(find.byType(FirstLaunchFlow), findsOneWidget);
    bridge.pushLink('grammarlens://review');
    await tester.pumpAndSettle();
    expect(find.byType(FirstLaunchFlow), findsOneWidget);
    expect(find.byType(DailyTestScreen), findsNothing);
  });
}
