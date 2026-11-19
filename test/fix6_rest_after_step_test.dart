import 'dart:async';
import 'dart:ui' as ui;

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
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'support/fake_native_bridge.dart';
import 'support/fix3_render.dart';
import 'support/recording_analytics_sink.dart';

/// Fix round 6, item 1 (SPEC §1.8, v14). On the owner's phone: the free
/// ticket used before the Daily Test; after the test, "See your climb"
/// opened the rest scene at once and the day's step was never shown. The
/// rest scene replaced Home as soon as every right was used, also while
/// the finished test's step was still pending.
///
/// Now: the step walks, the pawn rests for [HomeScreen.restBeat], and the
/// rest scene fades in over Home, in the same visit.
class _Storage extends StorageService {
  DailyTestSet? today;
  int steps = 8;
  int freeUsed = 0;
  int sessions = 0;
  Completer<void>? pendingCompletion;
  bool failProgress = false;
  ReminderSettings? reminderSettings;
  DateTime? firstCompletion;

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
        item: PracticeItem(
          id: 'q0',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question 0',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'right0',
        commonWrongAnswers: const [],
      ),
    ]);

DailyTestSet _doneSet() {
  final set = _waitingSet();
  return DailyTestSet(
      day: set.day,
      questions: set.questions,
      answers: const {'q0': 'right0'},
      completedAt: DateTime(2026, 1, 1, 8));
}

final _rest = find.byKey(HomeScreen.restSceneKey);
final _mountain = find.byType(MonthlyMountain, skipOffstage: false);
final _ask = find.byType(ReminderSoftAsk);

/// The scene's opacity while it fades in over Home; null when it stands
/// alone (or is not there).
double? _restOpacity(WidgetTester tester) {
  final fade = find.byKey(HomeScreen.restFadeKey);
  if (fade.evaluate().isEmpty) return null;
  return tester.widget<FadeTransition>(fade).opacity.value;
}

void main() {
  Future<void> pumpHome(
    WidgetTester tester,
    _Storage storage, {
    bool premium = false,
    bool reduceMotion = false,
    bool active = true,
    Brightness brightness = Brightness.light,
    ReminderController? reminders,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
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

  double pawnTop(WidgetTester tester) => tester
      .widget<Positioned>(find
          .descendant(
              of: _mountain,
              matching: find.byWidgetPredicate(
                  (w) => w is Positioned && w.child is AvatarTile,
                  skipOffstage: false))
          .last)
      .top!;

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

  /// Pumps until the mountain has taken the new step count (its first
  /// frame: the pawn still stands on the old step).
  Future<void> untilStepStarts(WidgetTester tester, int from) async {
    for (var i = 0; i < 60 && shownSteps(tester) == from; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(shownSteps(tester), from + 1);
  }

  /// From the result screen: "See your climb", the walk, the pawn at rest
  /// for the beat, then the rest scene fading in over Home. [arrival]: what
  /// a save point adds between the landing and the beat.
  Future<void> expectStepThenScene(WidgetTester tester,
      {int from = 8, Duration fade = const Duration(milliseconds: 400)}) async {
    final oldTop = pawnTop(tester);
    await tester.tap(find.text('See your climb'));
    await untilStepStarts(tester, from);
    expect(_rest, findsNothing, reason: 'the step first');
    expect(pawnTop(tester), closeTo(oldTop, .1));
    // The mountain is in view for the walk.
    final scene = tester.getRect(_mountain);
    expect(scene.top, greaterThanOrEqualTo(0));
    expect(scene.bottom, lessThanOrEqualTo(844));
    await tester.pump(const Duration(milliseconds: 425));
    expect(pawnTop(tester), lessThan(oldTop), reason: 'the pawn is walking');
    expect(_rest, findsNothing);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    final landed = pawnTop(tester);
    expect(landed, lessThan(oldTop));
    // The beat: the pawn stands on its new step, nothing else changes.
    await tester.pump(const Duration(milliseconds: 900));
    expect(_rest, findsNothing, reason: 'still the beat');
    expect(pawnTop(tester), landed);
    // The change is a cross-fade over Home, not a cut.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(_rest, findsOneWidget);
    expect(_mountain, findsOneWidget, reason: 'Home is still under it');
    expect(_restOpacity(tester), inExclusiveRange(0, 1));
    await tester.pump(fade);
    await tester.pump();
    expect(_rest, findsOneWidget);
    expect(_mountain, findsNothing, reason: 'the scene stands alone');
    expect(_restOpacity(tester), isNull);
  }

  testWidgets(
      'free: the ticket used, then the Daily Test: the step walks, the pawn '
      'rests, then the rest scene (the owner\'s path)', (tester) async {
    final storage = _Storage()
      ..today = _waitingSet()
      ..freeUsed = 1;
    await pumpHome(tester, storage);
    expect(_rest, findsNothing);
    await doTest(tester);
    expect(storage.steps, 9);
    // Under the results Home keeps the mountain on the old step.
    expect(shownSteps(tester), 8);
    await expectStepThenScene(tester);
    // It stays: nothing brings Home back.
    await tester.pump(const Duration(seconds: 5));
    expect(_rest, findsOneWidget);
  });

  testWidgets(
      'Premium: every session used, then the Daily Test: the step, the '
      'beat, then the rest scene', (tester) async {
    final storage = _Storage()
      ..today = _waitingSet()
      ..sessions = StorageService.dailySessionLimit;
    await pumpHome(tester, storage, premium: true);
    expect(_rest, findsNothing);
    await doTest(tester);
    await expectStepThenScene(tester);
  });

  testWidgets(
      'the other order is unchanged: the test and its step first, the last '
      'practice later: the rest scene at once, no beat, no fade',
      (tester) async {
    final storage = _Storage()..today = _waitingSet();
    await pumpHome(tester, storage);
    await doTest(tester);
    await tester.tap(find.text('See your climb'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(shownSteps(tester), 9);
    expect(_rest, findsNothing, reason: 'the ticket is not used');
    // The ticket is used from Review while Home is not the visible tab.
    await pumpHome(tester, storage, active: false);
    storage.freeUsed = 1;
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester, storage);
    expect(_rest, findsOneWidget);
    expect(_restOpacity(tester), isNull);
    expect(_mountain, findsNothing);
  });

  testWidgets(
      'the other order in one Home: back on the tab after the practice, the '
      'rest scene is there on the first frame', (tester) async {
    final storage = _Storage()..today = _doneSet();
    await pumpHome(tester, storage);
    expect(_rest, findsNothing);
    await pumpHome(tester, storage, active: false);
    storage.freeUsed = 1;
    await pumpHome(tester, storage);
    expect(_rest, findsOneWidget);
    expect(_restOpacity(tester), isNull);
  });

  testWidgets(
      'a save point day: the save point lights up and shows its name before '
      'the scene; the beat starts when the name has gone', (tester) async {
    // January has 31 days: step 7 is First Camp.
    final storage = _Storage()
      ..today = _waitingSet()
      ..steps = 6
      ..freeUsed = 1;
    await pumpHome(tester, storage);
    await doTest(tester);
    await tester.tap(find.text('See your climb'));
    await untilStepStarts(tester, 6);
    await tester.pump(const Duration(milliseconds: 875));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(MonthlyMountain.labelKey), findsOneWidget);
    expect(find.text('First Camp'), findsOneWidget);
    expect(_rest, findsNothing);
    // Well past a plain step's beat: the name is still up, Home stays.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.byKey(MonthlyMountain.labelKey), findsOneWidget);
    expect(_rest, findsNothing);
    // The label's 3.1 s end; then the beat; then the fade.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(find.byKey(MonthlyMountain.labelKey), findsNothing);
    expect(_rest, findsNothing);
    await tester.pump(const Duration(milliseconds: 900));
    expect(_rest, findsNothing, reason: 'the beat after the name');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(_rest, findsOneWidget);
    await tester.pumpAndSettle();
    expect(_mountain, findsNothing);
  });

  testWidgets(
      'Reduce Motion: the pawn is on its new step without a walk, the same '
      'beat, then a 150 ms fade', (tester) async {
    final storage = _Storage()
      ..today = _waitingSet()
      ..freeUsed = 1;
    await pumpHome(tester, storage, reduceMotion: true);
    await doTest(tester);
    final oldTop = pawnTop(tester);
    await tester.tap(find.text('See your climb'));
    await untilStepStarts(tester, 8);
    final landed = pawnTop(tester);
    expect(landed, lessThan(oldTop), reason: 'no walk');
    expect(_rest, findsNothing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(_rest, findsNothing, reason: 'the beat');
    expect(pawnTop(tester), landed);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(_rest, findsOneWidget);
    expect(_mountain, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(_rest, findsOneWidget);
    expect(_mountain, findsNothing);
  });

  testWidgets(
      'Home not visible when the test is saved: the step waits for Home, '
      'plays when it is visible, and the rest scene only after it',
      (tester) async {
    final storage = _Storage()
      ..today = _waitingSet()
      ..freeUsed = 1
      ..pendingCompletion = Completer<void>();
    await pumpHome(tester, storage);
    await doTest(tester, saving: true);
    // Leave the results before the save has finished, then another tab.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await pumpHome(tester, storage, active: false);
    storage.pendingCompletion!.complete();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(storage.steps, 9);
    expect(shownSteps(tester), 8, reason: 'not played behind another tab');
    expect(_rest, findsNothing);
    // Back on Home: the step, the beat, the scene.
    final oldTop = pawnTop(tester);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: HomeScreen(
        userName: 'Ada',
        claudeService: ClaudeService(),
        storageService: storage,
        analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
        subscriptionService: _Subscription(),
        clock: () => DateTime(2026, 1, 1, 9),
      ),
    ));
    await untilStepStarts(tester, 8);
    expect(_rest, findsNothing);
    await tester.pump(const Duration(milliseconds: 425));
    expect(pawnTop(tester), lessThan(oldTop));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(_rest, findsNothing);
    await tester.pumpAndSettle();
    expect(_rest, findsOneWidget);
    expect(_mountain, findsNothing);
  });

  group('leaving Home once the step has begun', () {
    Future<_Storage> toTheWalk(WidgetTester tester) async {
      final storage = _Storage()
        ..today = _waitingSet()
        ..freeUsed = 1;
      await pumpHome(tester, storage);
      await doTest(tester);
      await tester.tap(find.text('See your climb'));
      await untilStepStarts(tester, 8);
      return storage;
    }

    testWidgets(
        'another tab during the beat: the rest scene on return, the step '
        'is not replayed', (tester) async {
      final storage = await toTheWalk(tester);
      await tester.pump(const Duration(milliseconds: 875));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_rest, findsNothing);
      await pumpHome(tester, storage, active: false);
      await pumpHome(tester, storage);
      expect(_rest, findsOneWidget);
      expect(_restOpacity(tester), isNull);
      expect(_mountain, findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(_rest, findsOneWidget);
    });

    testWidgets('another tab during the walk: the same', (tester) async {
      final storage = await toTheWalk(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_rest, findsNothing);
      await pumpHome(tester, storage, active: false);
      await pumpHome(tester, storage);
      expect(_rest, findsOneWidget);
      expect(_mountain, findsNothing);
    });

    testWidgets('a route pushed above Home during the beat: the same',
        (tester) async {
      await toTheWalk(tester);
      await tester.pump(const Duration(milliseconds: 875));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('above'))));
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(_rest, findsOneWidget);
      expect(_restOpacity(tester), isNull);
      expect(_mountain, findsNothing);
    });

    testWidgets('the app in the background during the beat: the same',
        (tester) async {
      await toTheWalk(tester);
      await tester.pump(const Duration(milliseconds: 875));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_rest, findsOneWidget);
      expect(_restOpacity(tester), isNull);
      expect(_mountain, findsNothing);
    });

    testWidgets('another tab during the fade: the scene stands alone',
        (tester) async {
      final storage = await toTheWalk(tester);
      await tester.pump(const Duration(milliseconds: 875));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(_restOpacity(tester), isNotNull);
      await pumpHome(tester, storage, active: false);
      await pumpHome(tester, storage);
      expect(_rest, findsOneWidget);
      expect(_restOpacity(tester), isNull);
      expect(_mountain, findsNothing);
    });
  });

  group('N01 follows the delayed rest scene', () {
    for (final secondTest in [false, true]) {
      testWidgets(
          'not during the walk or the beat, once when the scene is on '
          'screen (${secondTest ? 'also queued by a second test' : 'first rest scene'})',
          (tester) async {
        final storage = _Storage()
          ..today = _waitingSet()
          ..freeUsed = 1
          ..reminderSettings = const ReminderSettings()
          ..firstCompletion =
              secondTest ? DateTime(2025, 12, 31, 20) : DateTime(2026, 1, 1, 9);
        final reminders = ReminderController(
            storage: storage,
            bridge: FakeNativeBridge()
              ..permission = NotificationPermission.notDetermined);
        addTearDown(reminders.dispose);
        await pumpHome(tester, storage, reminders: reminders);
        await doTest(tester);
        await tester.tap(find.text('See your climb'));
        await untilStepStarts(tester, 8);
        expect(_ask, findsNothing);
        await tester.pump(const Duration(milliseconds: 425));
        expect(_ask, findsNothing, reason: 'the walk');
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        expect(_ask, findsNothing, reason: 'the beat');
        expect(_rest, findsNothing);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(_rest, findsOneWidget);
        expect(_ask, findsNothing, reason: 'the scene is still fading in');
        await tester.pumpAndSettle();
        expect(_restOpacity(tester), isNull);
        expect(_ask, findsOneWidget);
        await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
        await tester.pumpAndSettle();
        expect(_ask, findsNothing);
        expect(storage.reminderSettings!.ask, ReminderAsk.declined);
      });
    }
  });

  group('no step to show: the rest scene comes as before, at once', () {
    testWidgets('the completion earned no step (every question skipped)',
        (tester) async {
      final storage = _Storage()
        ..today = _waitingSet()
        ..freeUsed = 1;
      await pumpHome(tester, storage);
      await doTest(tester, answer: '');
      expect(storage.steps, 8);
      // V10 has no "See your climb" without a step: the system back.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(_rest, findsOneWidget);
      expect(_restOpacity(tester), isNull);
      expect(_mountain, findsNothing);
    });

    testWidgets('the climb fails to load after the test', (tester) async {
      final storage = _Storage()
        ..today = _waitingSet()
        ..freeUsed = 1;
      await pumpHome(tester, storage);
      await doTest(tester);
      storage.failProgress = true;
      await tester.tap(find.text('See your climb'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(_rest, findsOneWidget);
      expect(_restOpacity(tester), isNull);
    });
  });

  // With `FIX6_CAPTURE=1`: a frame strip of the walk, the pawn at rest and
  // the rest scene, in `build/fix6-captures/[dark/]`.
  for (final brightness in Brightness.values) {
    final dark = brightness == Brightness.dark;
    testWidgets(
        'the whole run in ${brightness.name}: the walk, the pawn at rest, '
        'the fade, the rest scene (frame strip)', (tester) async {
      final storage = _Storage()
        ..today = _waitingSet()
        ..freeUsed = 1;
      await pumpFix3(
          tester,
          HomeScreen(
            userName: 'Ada',
            claudeService: ClaudeService(),
            storageService: storage,
            analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
            subscriptionService: _Subscription(),
            clock: () => DateTime(2026, 1, 1, 9),
          ),
          brightness: brightness);
      await doTest(tester);
      await tester.tap(find.text('See your climb'));
      await untilStepStarts(tester, 8);
      final frames = <ui.Image?>[await fix6Frame(tester)];
      // The walk is 850 ms.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 212));
        frames.add(await fix6Frame(tester));
      }
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(_rest, findsNothing);
      // The pawn at rest, half way through the beat.
      await tester.pump(const Duration(milliseconds: 500));
      frames.add(await fix6Frame(tester));
      // The fade, about half way.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(_restOpacity(tester), inExclusiveRange(0, 1));
      frames.add(await fix6Frame(tester));
      await tester.pumpAndSettle();
      expect(_rest, findsOneWidget);
      expect(_restOpacity(tester), isNull);
      frames.add(await fix6Frame(tester));
      await fix6Strip(tester, 'item1-step-then-rest', frames, dark: dark);
    });
  }

  testWidgets(
      'an ordinary day (practice unused) is as before: the step, no rest '
      'scene, and using the ticket later brings the scene at once',
      (tester) async {
    final storage = _Storage()..today = _waitingSet();
    await pumpHome(tester, storage);
    await doTest(tester);
    await tester.tap(find.text('See your climb'));
    await untilStepStarts(tester, 8);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(_rest, findsNothing);
    expect(shownSteps(tester), 9);
    await pumpHome(tester, storage, active: false);
    storage.freeUsed = 1;
    await pumpHome(tester, storage);
    expect(_rest, findsOneWidget);
    expect(_restOpacity(tester), isNull);
  });
}
