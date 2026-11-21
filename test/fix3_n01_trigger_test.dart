import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/reminder_soft_ask.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/native_bridge.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

import 'support/fake_native_bridge.dart';
import 'support/recording_analytics_sink.dart';

/// Fix round 3, A2 (SPEC §5.10, v11): N01 opens as soon as the first rest
/// scene (V24 / V24f) is on screen, whatever path led there, once. On the
/// owner's phone: the Day 0 test, then Review, the free ticket used on a
/// practice, back to Home: the rest scene showed but N01 opened only after
/// another tab switch.
///
/// The whole app (its real tab shell, Home and Review) on a storage fake:
/// today's Daily Test done, the free ticket used or not, reminders never
/// asked.
class _Storage extends StorageService {
  final UserProfile profile =
      const UserProfile(name: 'Ada', learningGoal: LearningGoal.general);
  DailyTestSet? today;
  int freeUsed = 0;
  ReminderSettings reminders = const ReminderSettings();

  @override
  Future<UserProfile?> getUserProfile() async => profile;

  @override
  Future<int> deleteStaleDailyTestSets() async => 0;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => today;

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => today;

  @override
  Future<int> getFreePracticeCountForToday() async => freeUsed;

  @override
  Future<int> getSessionCountForToday() async => freeUsed;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: 1, correct: 1, wrong: 0, skipped: 0);

  @override
  Future<DateTime?> getFirstDailyTestCompletion() async =>
      DateTime(2026, 11, 18, 9);

  @override
  Future<ReminderSettings> getReminderSettings() async => reminders;

  @override
  Future<void> setReminderSettings(ReminderSettings settings) async =>
      reminders = settings;
}

DailyTestSet _doneToday() {
  final questions = [
    for (var i = 0; i < 5; i++)
      DailyTestQuestion(
        item: PracticeItem(
            id: 'q$i',
            type: PracticeItemType.fillInBlank,
            instruction: 'Question $i'),
        topicId: 'tenseSelection',
        correctAnswer: 'right',
        commonWrongAnswers: const [],
      ),
  ];
  return DailyTestSet(
    day: '2026-11-18',
    questions: questions,
    completedAt: DateTime(2026, 11, 18, 9),
    answers: {for (final q in questions) q.item.id: 'right'},
  );
}

Future<void> _pumpApp(WidgetTester tester, _Storage storage) async {
  tester.view.physicalSize = const Size(402, 874) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GrammarLensApp(
    storageService: storage,
    analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
    nativeBridge: FakeNativeBridge()
      ..permission = NotificationPermission.notDetermined,
    clock: () => DateTime(2026, 11, 18, 15),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
      of: find.byKey(FloatingNavShell.barKey), matching: find.text(label)));
  await tester.pumpAndSettle();
}

final _rest = find.byKey(HomeScreen.restSceneKey);
final _ask = find.byType(ReminderSoftAsk);

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

  testWidgets(
      '(a) the owner\'s path: Home, then Review, the free ticket used on a '
      'practice, back to Home: the rest scene and N01 at once',
      (tester) async {
    final storage = _Storage()..today = _doneToday();
    await _pumpApp(tester, storage);
    expect(_rest, findsNothing);
    expect(_ask, findsNothing);

    await _tapTab(tester, 'Review');
    // The practice started from Review records the ticket (and, in the
    // app, its result) while Home is not the visible tab.
    storage.freeUsed = 1;
    await _tapTab(tester, 'Climb');

    expect(_rest, findsOneWidget);
    expect(_ask, findsOneWidget);
  });

  testWidgets(
      '(a\') the same with the app resumed while Review is in front: N01 '
      'opens when Home comes back', (tester) async {
    final storage = _Storage()..today = _doneToday();
    await _pumpApp(tester, storage);
    await _tapTab(tester, 'Review');
    storage.freeUsed = 1;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_ask, findsNothing, reason: 'Home is not on screen');
    await _tapTab(tester, 'Climb');
    expect(_rest, findsOneWidget);
    expect(_ask, findsOneWidget);
  });

  testWidgets('(b) a cold start straight into the rest scene opens N01',
      (tester) async {
    final storage = _Storage()
      ..today = _doneToday()
      ..freeUsed = 1;
    await _pumpApp(tester, storage);
    expect(_rest, findsOneWidget);
    expect(_ask, findsOneWidget);
  });

  testWidgets(
      '(c) never twice: after "Not now", tab switches and a resume leave it '
      'closed', (tester) async {
    final storage = _Storage()
      ..today = _doneToday()
      ..freeUsed = 1;
    await _pumpApp(tester, storage);
    expect(_ask, findsOneWidget);
    await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
    await tester.pumpAndSettle();
    expect(storage.reminders.ask, ReminderAsk.declined);
    for (final tab in ['Review', 'Climb', 'Profile', 'Climb']) {
      await _tapTab(tester, tab);
      expect(_ask, findsNothing);
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_ask, findsNothing);
  });

  testWidgets(
      '(c\') never twice in one session: closed by a swipe, it stays closed '
      'across tab switches', (tester) async {
    final storage = _Storage()..today = _doneToday();
    await _pumpApp(tester, storage);
    await _tapTab(tester, 'Review');
    storage.freeUsed = 1;
    await _tapTab(tester, 'Climb');
    expect(_ask, findsOneWidget);
    // Closing the sheet any way counts as "Not now" (DW5-2).
    await tester.tapAt(const Offset(200, 60));
    await tester.pumpAndSettle();
    expect(_ask, findsNothing);
    await _tapTab(tester, 'Review');
    await _tapTab(tester, 'Climb');
    expect(_ask, findsNothing);
  });
}
