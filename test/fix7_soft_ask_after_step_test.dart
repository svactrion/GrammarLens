import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/reminder_soft_ask.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/native_bridge.dart';
import 'package:grammar_lens/services/reminder_controller.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'support/fake_native_bridge.dart';
import 'support/recording_analytics_sink.dart';

/// Fix round 7, item 1 (SPEC §1.8, v15). Seen in the iPad tour (Premium, a
/// second day): after the Daily Test, "See your climb" brought Home with
/// N01 already open over the mountain; the pawn walked only after N01 was
/// closed. Every new user meets this once, on the day of their second
/// Daily Test.
///
/// Cause: N01 is queued by the second test and asked for on Home's first
/// frame after the results close; it waited only for `_climbAnimating`,
/// which the climb load sets after several awaits (the progress read, the
/// theme, the month card, the scroll), so it opened in that window.
///
/// Now, as fix round 6 did for the rest scene: the step walks, the pawn
/// lands, what follows a step follows it, then [HomeScreen.restBeat], then
/// N01. On a rest day N01 still follows the rest scene.
class _Storage extends StorageService {
  DailyTestSet? today;
  int steps = 8;
  int freeUsed = 0;
  int sessions = 0;
  bool failProgress = false;
  Completer<void>? pendingCompletion;
  ReminderSettings? reminderSettings = const ReminderSettings();
  DateTime? firstCompletion = DateTime(2025, 12, 31, 20);

  /// The month card: due (fresh variant) once [cardDue] is set, until
  /// claimed.
  bool cardDue = false;
  final flags = <String>{};

  @override
  Future<bool> hasOneTimeFlag(String key) async =>
      key.startsWith('month_card:') ? !cardDue || flags.contains(key) : true;

  @override
  Future<bool> claimOneTimeFlag(String key) async => flags.add(key);

  @override
  Future<bool> hasClimbHistoryBefore(int year, int month) async => true;

  @override
  Future<ReminderSettings> getReminderSettings() async =>
      reminderSettings ?? (throw StateError('no reminder settings'));

  @override
  Future<void> setReminderSettings(ReminderSettings settings) async =>
      reminderSettings = settings;

  @override
  Future<DateTime?> getFirstDailyTestCompletion() async => firstCompletion;

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
      int year, int month) async {
    if (failProgress) throw StateError('Read failed');
    // The month before has no steps: a month card, when due, is "fresh".
    if (month != 1) return (steps: 0, correct: 0, wrong: 0, skipped: 0);
    return (steps: steps, correct: 0, wrong: 0, skipped: 0);
  }

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => today;

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => today;

  @override
  Future<bool> completeDailyTest(
      Map<String, String> answers, List<ErrorEntry> errors,
      {String? day, DateTime? completedAt}) async {
    if (pendingCompletion != null) await pendingCompletion!.future;
    final set = today!;
    today = DailyTestSet(
        day: set.day,
        questions: set.questions,
        answers: answers,
        completedAt: completedAt ?? DateTime(2026, 1, 1, 9));
    if (answers.values.any((answer) => answer.trim().isNotEmpty)) steps++;
    return false;
  }

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};

  @override
  Future<int> getFreePracticeCountForToday() async => freeUsed;

  @override
  Future<int> getSessionCountForToday() async => sessions;
}

class _Subscription extends SubscriptionService {
  final bool hasAccess;
  _Subscription({this.hasAccess = false});

  @override
  Future<bool> get hasFullAccess async => hasAccess;

  @override
  void addAccessListener(AccessListener listener) {}

  @override
  void removeAccessListener(AccessListener listener) {}
}

DailyTestSet _waitingSet() => DailyTestSet(day: '2026-01-01', questions: [
      DailyTestQuestion(
        item: const PracticeItem(
          id: 'q0',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question 0',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'right0',
        commonWrongAnswers: const [],
      ),
    ]);

final _rest = find.byKey(HomeScreen.restSceneKey);
final _mountain = find.byType(MonthlyMountain, skipOffstage: false);
final _ask = find.byType(ReminderSoftAsk);

void main() {
  late ReminderController reminders;

  Future<void> pumpHome(
    WidgetTester tester,
    _Storage storage, {
    bool premium = false,
    bool active = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: HomeScreen(
        active: active,
        userName: 'Ada',
        claudeService: ClaudeService(),
        storageService: storage,
        analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
        subscriptionService: _Subscription(hasAccess: premium),
        reminders: reminders,
        clock: () => DateTime(2026, 1, 1, 9),
      ),
    ));
    await tester.pumpAndSettle();
  }

  _Storage storageFor({int freeUsed = 0, int sessions = 0}) => _Storage()
    ..today = _waitingSet()
    ..freeUsed = freeUsed
    ..sessions = sessions;

  setUp(() {
    reminders = ReminderController(
        storage: _Storage(),
        bridge: FakeNativeBridge()
          ..permission = NotificationPermission.notDetermined);
  });

  /// The controller must read the same storage as Home.
  ReminderController remindersFor(_Storage storage) {
    reminders.dispose();
    return reminders = ReminderController(
        storage: storage,
        bridge: FakeNativeBridge()
          ..permission = NotificationPermission.notDetermined);
  }

  tearDown(() => reminders.dispose());

  int shownSteps(WidgetTester tester) =>
      tester.widget<MonthlyMountain>(_mountain).completedDays;

  /// Home's Daily Test, one answer, up to the result screen (V10).
  Future<void> doTest(WidgetTester tester,
      {String answer = 'wrong', bool saving = false}) async {
    await tester.tap(find.text('Start today’s test'));
    await tester.pumpAndSettle();
    if (answer.isEmpty) {
      await tester.tap(find.byKey(DailyTestScreen.skipKey));
    } else {
      await tester.enterText(find.byType(TextField).first, answer);
      await tester.pump();
      await tester.tap(find.byKey(DailyTestScreen.checkKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DailyTestScreen.continueKey));
    }
    if (saving) {
      // The save has not finished: the result screen keeps its spinner.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    } else {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
    }
    expect(find.byType(DailyTestResultScreen), findsOneWidget);
  }

  /// Pumps in small steps until the mountain has taken the new step count,
  /// checking on every frame that N01 has not opened.
  Future<void> untilStepStarts(WidgetTester tester, int from) async {
    for (var i = 0; i < 60 && shownSteps(tester) == from; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(_ask, findsNothing, reason: 'N01 before the walk (frame $i)');
    }
    expect(shownSteps(tester), from + 1);
  }

  /// From the result screen on an ordinary day: "See your climb", the walk,
  /// the landing, the beat, then N01, once.
  Future<void> expectStepThenAsk(WidgetTester tester, _Storage storage,
      {int from = 8}) async {
    await tester.tap(find.text('See your climb'));
    await untilStepStarts(tester, from);
    expect(_ask, findsNothing, reason: 'the step first');
    // The walk is 850 ms.
    await tester.pump(const Duration(milliseconds: 425));
    expect(_ask, findsNothing, reason: 'the walk');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    // The beat after the landing.
    await tester.pump(const Duration(milliseconds: 800));
    expect(_ask, findsNothing, reason: 'the beat');
    expect(shownSteps(tester), from + 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(_ask, findsOneWidget);
    expect(_rest, findsNothing);
    await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
    await tester.pumpAndSettle();
    expect(_ask, findsNothing);
    expect(storage.reminderSettings!.ask, ReminderAsk.declined);
    // Once for the install.
    await tester.pump(const Duration(seconds: 3));
    expect(_ask, findsNothing);
  }

  group('a second day, the test first (an ordinary day)', () {
    testWidgets('free: the step walks, the beat, then N01 (the tour)',
        (tester) async {
      final storage = storageFor();
      remindersFor(storage);
      await pumpHome(tester, storage);
      await doTest(tester);
      expect(_ask, findsNothing, reason: 'not over the results');
      await expectStepThenAsk(tester, storage);
    });

    testWidgets('Premium: the same', (tester) async {
      final storage = storageFor();
      remindersFor(storage);
      await pumpHome(tester, storage, premium: true);
      await doTest(tester);
      await expectStepThenAsk(tester, storage);
    });
  });

  group('a second day, the practice first (a rest day)', () {
    for (final premium in [false, true]) {
      testWidgets(
          '${premium ? 'Premium' : 'free'}: the step, the beat, the rest '
          'scene, then N01 over it, once', (tester) async {
        final storage = premium
            ? storageFor(sessions: StorageService.dailySessionLimit)
            : storageFor(freeUsed: 1);
        remindersFor(storage);
        await pumpHome(tester, storage, premium: premium);
        await doTest(tester);
        await tester.tap(find.text('See your climb'));
        await untilStepStarts(tester, 8);
        await tester.pump(const Duration(milliseconds: 875));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        expect(_ask, findsNothing, reason: 'the beat');
        expect(_rest, findsNothing);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(_rest, findsOneWidget);
        expect(_ask, findsNothing, reason: 'the scene is still fading in');
        await tester.pumpAndSettle();
        expect(_mountain, findsNothing);
        expect(_ask, findsOneWidget);
        await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        expect(_ask, findsNothing);
      });
    }
  });

  testWidgets(
      'a save point day: N01 waits for the save point\'s light and name, '
      'then the beat', (tester) async {
    // January has 31 days: step 7 is First Camp.
    final storage = storageFor()..steps = 6;
    remindersFor(storage);
    await pumpHome(tester, storage);
    await doTest(tester);
    await tester.tap(find.text('See your climb'));
    await untilStepStarts(tester, 6);
    await tester.pump(const Duration(milliseconds: 875));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(MonthlyMountain.labelKey), findsOneWidget);
    // Well past a plain step's beat: the name is still up, N01 waits.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.byKey(MonthlyMountain.labelKey), findsOneWidget);
    expect(_ask, findsNothing);
    // The label's end; then the beat.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(find.byKey(MonthlyMountain.labelKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 800));
    expect(_ask, findsNothing, reason: 'the beat after the name');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(_ask, findsOneWidget);
  });

  testWidgets(
      'a month card on the same visit: N01 waits for the card, its zoom '
      'and the beat', (tester) async {
    final storage = storageFor();
    remindersFor(storage);
    await pumpHome(tester, storage);
    await doTest(tester);
    // The card becomes due for the load that brings the step.
    storage.cardDue = true;
    await tester.tap(find.text('See your climb'));
    for (var i = 0;
        i < 80 &&
            find.byKey(MonthCardSheet.startClimbingKey).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(_ask, findsNothing, reason: 'N01 before the card (frame $i)');
    }
    expect(find.byKey(MonthCardSheet.startClimbingKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(_ask, findsNothing, reason: 'under the card');
    await tester.tap(find.byKey(MonthCardSheet.startClimbingKey));
    // The card closes and its zoom plays; N01 only after it and the step.
    var askedAfter = Duration.zero;
    for (var i = 0; i < 200 && _ask.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      askedAfter += const Duration(milliseconds: 50);
    }
    // When N01 first shows, the step is taken and at least the beat has
    // passed since the card closed.
    expect(_ask, findsOneWidget);
    expect(shownSteps(tester), 9);
    expect(askedAfter, greaterThanOrEqualTo(HomeScreen.restBeat));
    await tester.pumpAndSettle();
    expect(_ask, findsOneWidget);
    expect(find.byKey(MonthCardSheet.startClimbingKey), findsNothing);
    expect(shownSteps(tester), 9);
  });

  group('no step to show: N01 is not lost', () {
    testWidgets('the climb fails to load after the test: N01 at once',
        (tester) async {
      final storage = storageFor();
      remindersFor(storage);
      await pumpHome(tester, storage);
      await doTest(tester);
      storage.failProgress = true;
      await tester.tap(find.text('See your climb'));
      await tester.pumpAndSettle();
      expect(_ask, findsOneWidget);
      await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(_ask, findsNothing);
    });

    testWidgets('the completion earned no step (every question skipped)',
        (tester) async {
      final storage = storageFor();
      remindersFor(storage);
      await pumpHome(tester, storage);
      await doTest(tester, answer: '');
      expect(storage.steps, 8);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(_ask, findsOneWidget);
    });
  });

  testWidgets(
      'Home not visible when the test is saved: no N01 behind another tab; '
      'back on Home the step, the beat, then N01', (tester) async {
    final storage = storageFor()..pendingCompletion = Completer<void>();
    remindersFor(storage);
    await pumpHome(tester, storage);
    await doTest(tester, saving: true);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await pumpHome(tester, storage, active: false);
    storage.pendingCompletion!.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(storage.steps, 9);
    expect(shownSteps(tester), 8, reason: 'not played behind another tab');
    expect(_ask, findsNothing);
    await pumpHome(tester, storage);
    // pumpHome settles: the step has walked; the beat is a timer.
    expect(shownSteps(tester), 9);
    expect(_ask, findsNothing, reason: 'the beat');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_ask, findsOneWidget);
  });

  testWidgets('another tab during the walk: N01 opens on the return, not lost',
      (tester) async {
    final storage = storageFor();
    remindersFor(storage);
    await pumpHome(tester, storage);
    await doTest(tester);
    await tester.tap(find.text('See your climb'));
    await untilStepStarts(tester, 8);
    await tester.pump(const Duration(milliseconds: 300));
    await pumpHome(tester, storage, active: false);
    expect(_ask, findsNothing);
    await pumpHome(tester, storage);
    expect(_ask, findsOneWidget);
  });
}
