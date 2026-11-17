import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/confetti_burst.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';
import 'package:grammar_lens/widgets/score_capsule.dart';
import 'package:grammar_lens/widgets/error_state.dart';
import 'package:grammar_lens/widgets/home_greeting.dart';
import 'package:grammar_lens/widgets/home_practice.dart';

import 'support/l10n_support.dart';
import 'support/celebration_support.dart';

/// Records `modeSelected` calls instead of the real (best-effort, silently
/// swallowed) Firebase call, so a test can assert which Home entry point a
/// tap actually reached — needed for Daily Test specifically, since unlike
/// Topic Practice/Premium, DailyTestScreen's real initial load has
/// nothing to succeed against in this test environment, landing on its own
/// in-screen error state (see daily_test_screen_test.dart) rather than
/// anything this file's simpler `tester.pump()`-only assertions could
/// reliably match against.
class _RecordingAnalyticsService extends AnalyticsService {
  final List<String> modesSelected = [];

  @override
  Future<void> modeSelected(String mode, {String? themeId}) async {
    modesSelected.add(mode);
  }
}

class _CountingClaudeService extends ClaudeService {
  int readCalls = 0;
  @override
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async {
    readCalls++;
    throw StateError('Cached Home flow must not read a set');
  }
}

/// Controls [hasFullAccess] and lets a test fire a live update through
/// whatever listener Home actually registered — the real SubscriptionService
/// would need an actual RevenueCat project to ever change entitlement state,
/// which this stands in for deterministically (see premium_screen_test.dart
/// for the same pattern applied to PremiumScreen).
class _FakeSubscriptionService extends SubscriptionService {
  bool hasAccess;
  AccessListener? _listener;

  _FakeSubscriptionService({this.hasAccess = false});

  @override
  Future<bool> get hasFullAccess async => hasAccess;

  @override
  void addAccessListener(AccessListener listener) {
    _listener = listener;
  }

  @override
  void removeAccessListener(AccessListener listener) {
    if (identical(_listener, listener)) _listener = null;
  }

  /// Simulates RevenueCat reporting a change — a trial starting, expiring,
  /// or a restore completing — without needing a real project connected.
  void emitAccessChange(bool value) {
    hasAccess = value;
    _listener?.call(value);
  }
}

/// Real StorageService methods throw in this test environment (no
/// platform channel) — fine for tests that don't care what Home's "today"
/// card or weak-spot section show (they fail open to "nothing yet", same
/// as every other best-effort read in this app), but the tests that assert
/// on *specific* Daily Test/weak-spot content need deterministic data,
/// which this fake supplies.
class _FakeStorageService extends StorageService {
  DailyTestSet? todaysDailyTest;
  List<WeakSpot> weakSpots = const [];

  /// What `getTopicStats` answers (Home's weak spot total); empty by
  /// default, so the total falls back to the cards shown.
  Map<String, TopicStats> topicStats = const {};
  int steps = 0;
  int correct = 0;
  int wrong = 0;
  int completionCalls = 0;
  Completer<void>? pendingCompletion;

  /// What a successful completion reports: whether it just earned the Welcome
  /// badge (a user who had never earned a step before).
  bool welcomeBadge = false;
  bool failProgress = false;
  final monthsRead = <(int, int)>[];
  Completer<({int steps, int correct, int wrong, int skipped})>?
      pendingProgress;

  /// The month's recorded theme: [recordedTheme] if set, else the
  /// rotation's (what the real one writes for a new month); throws when
  /// [failTheme].
  String? recordedTheme;
  bool failTheme = false;
  final themesResolved = <(int, int)>[];

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async {
    themesResolved.add((year, month));
    if (failTheme) throw StateError('Theme read failed');
    return recordedTheme ?? ClimbThemeRotation.shownFor(year, month).id;
  }

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
      int year, int month) async {
    monthsRead.add((year, month));
    if (failProgress) throw StateError('Read failed');
    if (pendingProgress != null) return pendingProgress!.future;
    return (steps: steps, correct: correct, wrong: wrong, skipped: 0);
  }

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => todaysDailyTest;

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) =>
      getDailyTestSetForToday();

  @override
  Future<bool> completeDailyTest(
      Map<String, String> answers, List<ErrorEntry> errors,
      {String? day, DateTime? completedAt}) async {
    completionCalls++;
    if (pendingCompletion != null) await pendingCompletion!.future;
    final set = todaysDailyTest!;
    todaysDailyTest = DailyTestSet(
        day: set.day,
        questions: set.questions,
        answers: answers,
        completedAt: completedAt ?? DateTime.now());
    if (answers.values.any((answer) => answer.trim().isNotEmpty)) steps++;
    return welcomeBadge;
  }

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      weakSpots.take(limit).toList();

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => topicStats;

  /// Today's free practices (the ticket) and practice sessions.
  int freeUsed = 0;
  int sessions = 0;

  @override
  Future<int> getFreePracticeCountForToday() async => freeUsed;

  @override
  Future<int> getSessionCountForToday() async => sessions;
}

DailyTestSet _completedDailyTestSet(
    {required int correct, required int total}) {
  final questions = List.generate(
    total,
    (i) => DailyTestQuestion(
      item: PracticeItem(
        id: 'q$i',
        type: PracticeItemType.fillInBlank,
        instruction: 'Question $i',
      ),
      topicId: 'tenseSelection',
      correctAnswer: 'right$i',
      commonWrongAnswers: const [],
    ),
  );
  final answers = {
    for (var i = 0; i < total; i++) 'q$i': i < correct ? 'right$i' : 'wrong',
  };
  return DailyTestSet(
    day: '2026-01-01',
    questions: questions,
    completedAt: DateTime(2026, 1, 1),
    answers: answers,
  );
}

WeakSpot _weakSpot({String topicId = 'articles', int frequency = 5}) =>
    WeakSpot(
      topicId: topicId,
      errorType: 'missing_article',
      frequency: frequency,
      lastSeen: DateTime.now(),
      latestExplanation: 'You left out "the" before a specific noun.',
    );

/// Home's greeting by what it says (and what VoiceOver reads), whether it is
/// laid out on one line or, when that does not fit, two.
Finder _greeting(String text) =>
    find.byWidgetPredicate((w) => w is HomeGreeting && w.text == text);

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    String userName = 'Ada',
    Avatar? avatar,
    VoidCallback? onOpenProfile,
    VoidCallback? onGoToReview,
    AnalyticsService? analyticsService,
    ClaudeService? claudeService,
    SubscriptionService? subscriptionService,
    StorageService? storageService,
    DateTime Function()? clock,
    Brightness brightness = Brightness.light,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reduceMotion = false,
    bool active = true,
    AppTextSize textSize = AppTextSize.medium,
  }) async {
    // A phone-realistic size so every card is actually reachable by taps.
    tester.view.physicalSize = size * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        // DailyTestResultScreen (reachable from the Today card once
        // completed) reads SemanticColors off the theme — the app's real
        // theme registers it, MaterialApp's default doesn't (same fix
        // first_launch_flow_test.dart already needed for the same
        // screen).
        theme: buildAppTheme(brightness, textSize: textSize),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: HomeScreen(
          active: active,
          userName: userName,
          avatar: avatar,
          claudeService: claudeService ?? ClaudeService(),
          storageService: storageService ?? StorageService(),
          analyticsService: analyticsService ?? AnalyticsService(),
          subscriptionService:
              subscriptionService ?? _FakeSubscriptionService(),
          onOpenProfile: onOpenProfile,
          onGoToReview: onGoToReview,
          // Fixed at a mid-morning instant by default so the greeting text
          // this file asserts on doesn't depend on when the suite happens
          // to run — timeOfDayGreeting's own boundary tests live in
          // greeting_test.dart, this file only needs one stable value.
          clock: clock ?? () => DateTime(2026, 1, 1, 9, 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('small Home, large text and reduced motion in $brightness',
        (tester) async {
      final storage = _FakeStorageService()..steps = 28;
      await pumpHome(tester,
          storageService: storage,
          clock: () => DateTime(2026, 2, 28),
          brightness: brightness,
          size: const Size(320, 568),
          textScale: 2,
          reduceMotion: true);
      final outer =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      for (var i = 0;
          i < 20 && find.byType(MonthlyMountain).evaluate().isEmpty;
          i++) {
        outer.jumpTo(outer.pixels + 200);
        await tester.pumpAndSettle();
      }
      final mountain =
          tester.widget<MonthlyMountain>(find.byType(MonthlyMountain));
      expect(mountain.days, 28);
      expect(mountain.completedDays, 28);
      expect(find.text('28 / 28'), findsOneWidget);
      for (var i = 0;
          i < 20 && find.text('Topic practice').evaluate().isEmpty;
          i++) {
        outer.jumpTo(outer.pixels + 200);
        await tester.pumpAndSettle();
      }
      expect(find.text('Topic practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // Batch 4: Home shows the month's recorded theme, and records it on the
  // first view (StorageService.resolveClimbMonthTheme), not only when a
  // Daily Test is completed.
  for (final (year, month, id) in [
    (2026, 10, 'green_slope'),
    (2026, 11, 'ember_peak'),
    (2026, 12, 'glacier_peak'),
    (2027, 1, 'red_canyon'),
  ]) {
    testWidgets('$year-$month: the mountain shows $id', (tester) async {
      final storage = _FakeStorageService()..steps = 3;
      await pumpHome(tester,
          storageService: storage, clock: () => DateTime(year, month, 5, 14));
      await tester.pumpAndSettle();
      expect(
          tester.widget<MonthlyMountain>(find.byType(MonthlyMountain)).theme.id,
          id);
      expect(storage.themesResolved, contains((year, month)));
    });
  }

  testWidgets('a recorded theme wins over the rotation', (tester) async {
    final storage = _FakeStorageService()..recordedTheme = 'glacier_peak';
    await pumpHome(tester,
        storageService: storage, clock: () => DateTime(2026, 11, 5, 14));
    await tester.pumpAndSettle();
    expect(tester.widget<MonthlyMountain>(find.byType(MonthlyMountain)).theme,
        ClimbThemes.glacierPeak);
  });

  testWidgets('if the theme cannot be read, the rotation\'s is shown',
      (tester) async {
    final storage = _FakeStorageService()..failTheme = true;
    await pumpHome(tester,
        storageService: storage, clock: () => DateTime(2026, 12, 5, 14));
    await tester.pumpAndSettle();
    expect(tester.widget<MonthlyMountain>(find.byType(MonthlyMountain)).theme,
        ClimbThemes.glacierPeak);
    expect(find.text('Retry progress'), findsNothing);
  });

  // Device report, 2026-10-01: one step done on the month's first day, no
  // dot behind the avatar. The dots follow the completed steps, never the
  // calendar day: on the 1st and on the 20th, one step gives one dot.
  for (final calendarDay in [1, 20]) {
    testWidgets(
        'one completed step on October $calendarDay: one passed-day dot',
        (tester) async {
      await pumpHome(tester,
          storageService: _FakeStorageService()..steps = 1,
          clock: () => DateTime(2026, 10, calendarDay, 14));
      for (var i = 0;
          i < 20 && find.byType(MonthlyMountain).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      final mountain = find.byType(MonthlyMountain);
      expect(tester.widget<MonthlyMountain>(mountain).completedDays, 1);
      final dots = tester
          .widgetList<CustomPaint>(
              find.descendant(of: mountain, matching: find.byType(CustomPaint)))
          .map((p) => p.painter)
          .whereType<ClimbTrailDots>()
          .single;
      expect(dots.points, hasLength(1));
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('dragging the Home mountain scrolls the page in $brightness',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHome(tester,
          storageService: _FakeStorageService()..steps = 8,
          brightness: brightness,
          size: const Size(320, 568));
      final mountain = find.byType(MonthlyMountain);
      await tester.ensureVisible(mountain);
      await tester.pumpAndSettle();
      final outer =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      // The scene has no scrollable of its own (the camera follows the
      // pawn), so a vertical drag on it always reaches the page.
      expect(find.descendant(of: mountain, matching: find.byType(Scrollable)),
          findsNothing);
      final pageBefore = outer.pixels;
      await tester.dragFrom(tester.getCenter(mountain), const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(outer.pixels, greaterThan(pageBefore));
      expect(find.text('Topic practice').hitTestable(), findsOneWidget);
      expect(find.textContaining('Answer at least'), findsNothing);
      expect(find.textContaining('Your climb starts'), findsNothing);
      await tester.ensureVisible(find.text('8 / 31'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.text('8 / 31')).label, '8 of 31 steps.');
      // Inside the card's frame, at the top of the mountain window
      // (design decision K3), not in a header row above it.
      final counterTop = tester.getTopLeft(find.text('8 / 31')).dy;
      expect(counterTop, greaterThan(tester.getTopLeft(mountain).dy));
      expect(counterTop, lessThan(tester.getTopLeft(mountain).dy + 60));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final answer in ['wrong', '']) {
    testWidgets(
        'finish with "$answer" refreshes only persisted progress, replay adds nothing',
        (tester) async {
      final storage = _FakeStorageService()
        ..pendingCompletion = Completer<void>()
        ..todaysDailyTest = DailyTestSet(
            day: '2026-01-01',
            questions: _completedDailyTestSet(correct: 0, total: 5).questions);
      final claude = _CountingClaudeService();
      await pumpHome(tester, storageService: storage, claudeService: claude);
      await tester.tap(find.text('Start today’s test'));
      await tester.pumpAndSettle();
      if (answer.isNotEmpty) {
        await tester.enterText(find.byType(TextField).first, answer);
      }
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        if (i == 0 && answer.isNotEmpty) {
          await tester.tap(find.byKey(DailyTestScreen.checkKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(DailyTestScreen.continueKey));
        } else {
          await tester.tap(find.byKey(DailyTestScreen.skipKey));
        }
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(DailyTestScreen.skipKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      expect(storage.completionCalls, 1);
      // Leave before the write completes: Home must refresh on commit too.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<MonthlyMountain>(find.byType(MonthlyMountain))
              .completedDays,
          0);
      storage.pendingCompletion!.complete();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<MonthlyMountain>(find.byType(MonthlyMountain))
              .completedDays,
          answer.isEmpty ? 0 : 1);
      await tester.ensureVisible(find.text('Review answers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(storage.completionCalls, 1);
      expect(storage.steps, answer.isEmpty ? 0 : 1);
      expect(claude.readCalls, 0);
    });
  }

  testWidgets('climb reads the calendar month and selected avatar',
      (tester) async {
    final storage = _FakeStorageService()..steps = 8;
    await pumpHome(tester,
        storageService: storage,
        avatar: Avatar.values.last,
        clock: () => DateTime(2028, 2, 15));
    final mountain =
        tester.widget<MonthlyMountain>(find.byType(MonthlyMountain));
    expect(mountain.days, 29);
    expect(mountain.completedDays, 8);
    expect(mountain.avatar, Avatar.values.last);
    expect(storage.monthsRead, [(2028, 2)]);
  });

  testWidgets('delayed save waits for the Home tab to become active',
      (tester) async {
    final storage = _FakeStorageService()
      ..pendingCompletion = Completer<void>()
      ..todaysDailyTest = DailyTestSet(
          day: '2026-01-01',
          questions: _completedDailyTestSet(correct: 0, total: 1).questions);
    await pumpHome(tester, storageService: storage);
    await tester.tap(find.text('Start today’s test'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'wrong');
    await tester.pump();
    // V07: the last question's "Finish" checks; the sheet's button goes on.
    await tester.tap(find.byKey(DailyTestScreen.checkKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DailyTestScreen.continueKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // V10 has no app bar; the system back gesture pops the route.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await pumpHome(tester, storageService: storage, active: false);
    storage.pendingCompletion!.complete();
    await tester.pumpAndSettle();
    expect(storage.steps, 1);
    expect(
        tester
            .widget<MonthlyMountain>(find.byType(MonthlyMountain))
            .completedDays,
        0);
    await pumpHome(tester, storageService: storage, active: true);
    expect(
        tester
            .widget<MonthlyMountain>(find.byType(MonthlyMountain))
            .completedDays,
        1);
    expect(storage.completionCalls, 1);
  });

  for (final useButton in [true, false]) {
    for (final reduceMotion in [false, true]) {
      testWidgets(
          'return via ${useButton ? 'CTA' : 'back'} shows saved step only on visible Home, reduced=$reduceMotion',
          (tester) async {
        final storage = _FakeStorageService()
          ..steps = 8
          ..todaysDailyTest = DailyTestSet(
              day: '2026-01-01',
              questions:
                  _completedDailyTestSet(correct: 0, total: 1).questions);
        await pumpHome(tester,
            storageService: storage, reduceMotion: reduceMotion);
        final mountain = find.byType(MonthlyMountain, skipOffstage: false);
        double pawnTop() => tester
            .widget<Positioned>(find
                .descendant(
                    of: mountain,
                    matching: find.byWidgetPredicate(
                        (w) => w is Positioned && w.child is AvatarTile,
                        skipOffstage: false))
                .last)
            .top!;
        final oldTop = pawnTop();
        final oldState = tester.state(mountain);
        await tester.tap(find.text('Start today’s test'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'wrong');
        await tester.pump();
        await tester.tap(find.byKey(DailyTestScreen.checkKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(DailyTestScreen.continueKey));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        expect(storage.steps, 9); // Persisted while results are still open.
        expect(tester.widget<MonthlyMountain>(mountain).completedDays, 8);
        expect(pawnTop(), oldTop); // No hidden animation.
        if (useButton) {
          // V10: the button sits in the screen's bottom slot.
          await tester.tap(find.text('See your climb'));
        } else {
          // V10 has no app bar: the system back gesture pops the route.
          tester.state<NavigatorState>(find.byType(Navigator)).pop();
        }
        // Observe the first frame that receives the committed target, rather
        // than pumpAndSettle (which would hide an already-consumed animation).
        for (var i = 0;
            i < 40 &&
                tester.widget<MonthlyMountain>(mountain).completedDays == 8;
            i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        expect(tester.widget<MonthlyMountain>(mountain).completedDays, 9);
        expect(tester.state(mountain), same(oldState));
        final startTop = pawnTop();
        if (!reduceMotion) expect(startTop, closeTo(oldTop, 0.1));
        final scene = tester.getRect(mountain);
        expect(scene.top, greaterThanOrEqualTo(0));
        expect(scene.bottom, lessThanOrEqualTo(844));
        await tester.pump(const Duration(milliseconds: 425));
        final middleTop = pawnTop();
        await tester.pumpAndSettle();
        final endTop = pawnTop();
        expect(endTop, lessThan(oldTop));
        if (reduceMotion) {
          expect(startTop, endTop);
        } else {
          expect(middleTop, lessThan(startTop));
          // Halfway, the pawn hops above the line between the two steps
          // (design decision D8: 14 units, 10.2 pt with the camera).
          expect(middleTop, lessThan((startTop + endTop) / 2 - 8));
        }
        await tester.ensureVisible(find.text('Review answers'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review answers'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Back to Home'), 250,
            scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text('Back to Home'));
        await tester.pumpAndSettle();
        expect(pawnTop(), endTop);
        expect(storage.completionCalls, 1);
      });
    }
  }

  testWidgets(
      'a badge earned from Home: the celebration first, then Start my climb '
      '(no confetti of its own, N36) and Home animates the step',
      (tester) async {
    final storage = _FakeStorageService()
      ..steps = 8
      ..welcomeBadge = true
      ..todaysDailyTest = DailyTestSet(
          day: '2026-01-01',
          questions: _completedDailyTestSet(correct: 0, total: 1).questions);
    await pumpHome(tester, storageService: storage);
    final mountain = find.byType(MonthlyMountain, skipOffstage: false);
    double pawnTop() => tester
        .widget<Positioned>(find
            .descendant(
                of: mountain,
                matching: find.byWidgetPredicate(
                    (w) => w is Positioned && w.child is AvatarTile,
                    skipOffstage: false))
            .last)
        .top!;
    final oldTop = pawnTop();
    await tester.tap(find.text('Start today’s test'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'wrong');
    await tester.pump();
    await tester.tap(find.byKey(DailyTestScreen.checkKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DailyTestScreen.continueKey));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(storage.steps, 9);
    // Batch 5 (N15): the celebration over the results first; its own
    // confetti went with it.
    await closeCelebration(tester);
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(find.text('Climb my first step'), findsOneWidget);
    expect(find.text('See your climb'), findsNothing);

    // N36: no confetti of its own; the results pop and Home steps.
    await tester.tap(find.text('Climb my first step'));
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsNothing);
    for (var i = 0;
        i < 60 && tester.widget<MonthlyMountain>(mountain).completedDays == 8;
        i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(find.byType(DailyTestResultScreen), findsNothing);
    expect(tester.widget<MonthlyMountain>(mountain).completedDays, 9);
    final startTop = pawnTop();
    expect(startTop, closeTo(oldTop, 0.1));
    await tester.pump(const Duration(milliseconds: 425));
    final middleTop = pawnTop();
    await tester.pumpAndSettle();
    final endTop = pawnTop();
    expect(endTop, lessThan(oldTop));
    expect(middleTop, lessThan(startTop));
    // Halfway, the pawn hops above the line between the two steps (D8).
    expect(middleTop, lessThan((startTop + endTop) / 2 - 8));
    expect(storage.completionCalls, 1);
  });

  testWidgets(
      'the score capsule reads the month\'s score and the next medal (D9, '
      'V14: the score bar moved from under the mountain)', (tester) async {
    final semantics = tester.ensureSemantics();
    // October 2026: 31 days, Bronze at 78 (rule v1). 20 correct and 10
    // wrong = 50 points.
    final storage = _FakeStorageService()
      ..steps = 6
      ..correct = 20
      ..wrong = 10;
    await pumpHome(tester,
        storageService: storage, clock: () => DateTime(2026, 10, 12, 9));
    await tester.pumpAndSettle();
    expect(find.byType(ClimbScoreBar), findsNothing);
    final capsule =
        tester.widget<ScoreCapsule>(find.byKey(HomeScreen.capsuleKey));
    expect(capsule.points, 50);
    expect((capsule.year, capsule.month), (2026, 10));
    expect(ScoreCapsule.nextTier(50, 2026, 10), MedalTier.bronze);
    expect(find.text('28 to Bronze'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
      'month rollover replaces the old mountain, including equal-length months',
      (tester) async {
    var now = DateTime(2026, 7, 31);
    final storage = _FakeStorageService()..steps = 20;
    await pumpHome(tester, storageService: storage, clock: () => now);
    final oldState = tester.state(find.byType(MonthlyMountain));
    now = DateTime(2026, 8, 1);
    storage.steps = 0;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(MonthlyMountain)), isNot(same(oldState)));
    expect(
        tester
            .widget<MonthlyMountain>(find.byType(MonthlyMountain))
            .completedDays,
        0);
    expect(storage.monthsRead.last, (2026, 8));
  });

  testWidgets(
      'failed progress read offers retry without inventing zero progress',
      (tester) async {
    final storage = _FakeStorageService()..failProgress = true;
    await pumpHome(tester, storageService: storage);
    expect(find.byType(MonthlyMountain), findsNothing);
    expect(find.text('Couldn’t load your monthly progress.'), findsOneWidget);
    storage.failProgress = false;
    storage.steps = 4;
    // R11: the shared error state's "Try again".
    await tester.ensureVisible(find.byKey(ErrorState.retryKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ErrorState.retryKey));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MonthlyMountain>(find.byType(MonthlyMountain))
            .completedDays,
        4);
  });

  testWidgets('stale progress read cannot overwrite a newer resumed month',
      (tester) async {
    var now = DateTime(2026, 9, 30);
    final storage = _FakeStorageService();
    await pumpHome(tester, storageService: storage, clock: () => now);
    final pending =
        Completer<({int steps, int correct, int wrong, int skipped})>();
    storage.pendingProgress = pending;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    now = DateTime(2026, 10, 1);
    storage.pendingProgress = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    pending.complete((steps: 25, correct: 0, wrong: 0, skipped: 0));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<MonthlyMountain>(find.byType(MonthlyMountain))
            .completedDays,
        0);
  });

  testWidgets('resume refreshes cached test and greeting after local midnight',
      (tester) async {
    var now = DateTime(2026, 1, 1, 23, 59);
    final storage = _FakeStorageService()
      ..todaysDailyTest = _completedDailyTestSet(correct: 3, total: 5);
    await pumpHome(tester, storageService: storage, clock: () => now);
    expect(_greeting('Good evening, Ada'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 1, 2, 9);
    storage.todaysDailyTest = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_greeting('Good morning, Ada'), findsOneWidget);
    expect(find.text('Review answers'), findsNothing);
    expect(find.text('Start today’s test'), findsOneWidget);
  });

  testWidgets('greets the user by their onboarding name', (tester) async {
    await pumpHome(tester);
    expect(_greeting('Good morning, Ada'), findsOneWidget);
  });

  testWidgets(
      'renders the greeting word alone, with no dangling comma, when there '
      'is no name', (tester) async {
    await pumpHome(tester, userName: '');
    expect(find.text('Good morning'), findsOneWidget);
    // Not just absence of the old copy — nothing starting with "Good "
    // should carry a trailing ", " with nothing after it.
    expect(find.textContaining('Good morning,'), findsNothing);
  });

  testWidgets('the greeting follows the injected clock, not a fixed word',
      (tester) async {
    await pumpHome(tester, clock: () => DateTime(2026, 1, 1, 19, 0));
    expect(_greeting('Good evening, Ada'), findsOneWidget);
    expect(_greeting('Good morning, Ada'), findsNothing);
  });

  // UI polish (SPEC §5 Home, V14 / V15 / H04 / V24): the wordmark with the
  // score capsule, the greeting, the Daily Test card, the mountain with its
  // bubble, the free ticket and the topic showcase (free) or the practice
  // card (Premium); the rest scene once every daily right is used. Home's
  // avatar, its weak spot list, the topic strip and the Review call-out are
  // gone (PROGRESS.md D5-1).
  group('Home, UI polish', () {
    testWidgets(
        'before the test: the card\'s line and "Start today’s test" opens '
        'the Daily Test; the bubble says the next step is one test away',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());
      final card = find.byKey(HomeScreen.dailyTestCardKey);
      expect(find.descendant(of: card, matching: find.text('Your next step.')),
          findsOneWidget);
      expect(
          find.descendant(
              of: card,
              matching: find.text(
                  '${DailyTestSet.questionCount} questions · about 2 minutes')),
          findsOneWidget);
      expect(find.text('Review answers'), findsNothing);
      expect(find.text('Step 1 is one test away!'), findsOneWidget);
      // V15: the step the test will reach pulses in gold.
      expect(find.byKey(MonthlyMountain.nextStepKey), findsOneWidget);

      await tester.tap(find.text('Start today’s test'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestScreen), findsOneWidget);
    });

    testWidgets(
        'after the test: today\'s points and step, "Review answers" opens '
        'the result, and the bubble points at tomorrow', (tester) async {
      final storage = _FakeStorageService()
        ..steps = 1
        ..todaysDailyTest = _completedDailyTestSet(correct: 3, total: 5);
      await pumpHome(tester, storageService: storage);
      final card = find.byKey(HomeScreen.dailyTestCardKey);
      // 3 right (+2 each) and 2 wrong (+1 each).
      expect(
          find.descendant(
              of: card, matching: find.text('+8 points · step 1 reached')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Day 1 complete!')),
          findsOneWidget);
      expect(find.text('Start today’s test'), findsNothing);
      expect(find.text('Step 2 opens tomorrow'), findsOneWidget);
      expect(find.byKey(MonthlyMountain.nextStepKey), findsNothing);

      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      expect(find.byType(DailyTestScreen), findsNothing);
    });

    testWidgets('the score capsule opens Profile', (tester) async {
      var opened = 0;
      await pumpHome(tester, onOpenProfile: () => opened++);
      await tester.tap(find.byKey(HomeScreen.capsuleKey));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    testWidgets(
        'a free user: the ticket names the weak spot and switches to Review',
        (tester) async {
      var toReview = 0;
      await pumpHome(tester,
          storageService: _FakeStorageService()..weakSpots = [_weakSpot()],
          onGoToReview: () => toReview++);
      final ticket = find.byKey(HomeScreen.ticketKey);
      await tester.ensureVisible(ticket);
      await tester.pumpAndSettle();
      expect(find.text('1 free practice'), findsOneWidget);
      expect(find.text('Use it on: Missing Article'), findsOneWidget);
      await tester.tap(ticket);
      await tester.pumpAndSettle();
      expect(toReview, 1);
      expect(find.byType(PremiumScreen), findsNothing);
    });

    testWidgets('a free user with no weak spot: the ticket points at Review',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());
      expect(find.text('Pick a weak spot in Review.'), findsOneWidget);
    });

    testWidgets('a free user who used the ticket: the used line',
        (tester) async {
      await pumpHome(tester,
          storageService: _FakeStorageService()..freeUsed = 1);
      expect(find.text('Nice work, Ada.'), findsOneWidget);
    });

    testWidgets(
        'a free user: the showcase picks the weak spot\'s topic, and every '
        'tap opens the paywall', (tester) async {
      await pumpHome(tester,
          storageService: _FakeStorageService()
            ..weakSpots = [_weakSpot(topicId: 'modalVerbs')]);
      final showcase = find.byType(TopicShowcase);
      expect(
          find.descendant(
              of: showcase,
              matching: find.text(kTopics
                  .firstWhere((t) => t.id.name == 'modalVerbs')
                  .title(en))),
          findsOneWidget);
      final unlock = find.text('Unlock all ${kTopics.length} topics');
      await tester.ensureVisible(unlock);
      await tester.pumpAndSettle();
      await tester.tap(unlock);
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.byType(TopicPracticeScreen), findsNothing);
    });

    testWidgets(
        'a Premium user: no ticket, the practice card; a topic opens Topic '
        'Practice', (tester) async {
      await pumpHome(tester,
          subscriptionService: _FakeSubscriptionService(hasAccess: true),
          storageService: _FakeStorageService()..sessions = 2);
      expect(find.byKey(HomeScreen.ticketKey), findsNothing);
      expect(find.byType(TopicShowcase), findsNothing);
      expect(find.byType(PracticeCard), findsOneWidget);
      expect(
          find.text('2/${StorageService.dailySessionLimit}'), findsOneWidget);
      final tile = find.descendant(
          of: find.byType(PracticeCard),
          matching: find.text(kTopics.first.title(en)));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(TopicPracticeScreen), findsOneWidget);
    });

    testWidgets(
        'a Premium user: "Practice your weak spot" opens that weak spot',
        (tester) async {
      await pumpHome(tester,
          subscriptionService: _FakeSubscriptionService(hasAccess: true),
          storageService: _FakeStorageService()..weakSpots = [_weakSpot()]);
      final button = find.byKey(PracticeCard.weakSpotKey);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(WeakSpotDetailScreen), findsOneWidget);
    });

    testWidgets(
        'reacts live to an entitlement change: a trial starting swaps the '
        'showcase for the practice card', (tester) async {
      final subscriptionService = _FakeSubscriptionService();
      await pumpHome(tester, subscriptionService: subscriptionService);
      expect(find.byType(TopicShowcase), findsOneWidget);
      subscriptionService.emitAccessChange(true);
      await tester.pumpAndSettle();
      expect(find.byType(TopicShowcase), findsNothing);
      expect(find.byType(PracticeCard), findsOneWidget);
    });

    testWidgets(
        'stacks in order: the capsule row, the Daily Test card, the '
        'mountain, the ticket, the showcase', (tester) async {
      await pumpHome(tester,
          storageService: _FakeStorageService()..weakSpots = [_weakSpot()]);
      double top(Finder f) => tester.getTopLeft(f).dy;
      final capsule = top(find.byKey(HomeScreen.capsuleKey));
      final daily = top(find.byKey(HomeScreen.dailyTestCardKey));
      final mountain = top(find.byType(MonthlyMountain));
      final ticket = top(find.byKey(HomeScreen.ticketKey));
      final showcase = top(find.byType(TopicShowcase));
      expect(daily, greaterThan(capsule));
      expect(mountain, greaterThan(daily));
      expect(ticket, greaterThan(mountain));
      expect(showcase, greaterThan(ticket));
    });

    testWidgets('every daily right used (free): the rest scene replaces Home',
        (tester) async {
      final storage = _FakeStorageService()
        ..steps = 3
        ..freeUsed = 1
        ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5);
      await pumpHome(tester, storageService: storage);
      expect(find.byKey(HomeScreen.restSceneKey), findsOneWidget);
      expect(find.byKey(HomeScreen.dailyTestCardKey), findsNothing);
      expect(find.text('All done for today'), findsOneWidget);
      expect(find.text('4/5 · +9 points'), findsOneWidget);
      expect(find.text('Ticket used'), findsOneWidget);
      expect(find.byKey(HomeScreen.capsuleKey), findsOneWidget);
    });

    testWidgets(
        'every daily right used (Premium): every session, then the rest scene',
        (tester) async {
      final storage = _FakeStorageService()
        ..steps = 3
        ..sessions = StorageService.dailySessionLimit
        ..todaysDailyTest = _completedDailyTestSet(correct: 5, total: 5);
      await pumpHome(tester,
          storageService: storage,
          subscriptionService: _FakeSubscriptionService(hasAccess: true));
      expect(find.byKey(HomeScreen.restSceneKey), findsOneWidget);
      const limit = StorageService.dailySessionLimit;
      expect(find.text('$limit/$limit sessions'), findsOneWidget);
    });

    testWidgets('a done test with practice left is not a rest day',
        (tester) async {
      final storage = _FakeStorageService()
        ..steps = 3
        ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5);
      await pumpHome(tester, storageService: storage);
      expect(find.byKey(HomeScreen.restSceneKey), findsNothing);
      expect(find.byKey(HomeScreen.dailyTestCardKey), findsOneWidget);
    });
  });

  testWidgets(
      'Daily Test is wired to its own entry point, distinct from Topic '
      'Practice/Premium', (tester) async {
    final analyticsService = _RecordingAnalyticsService();
    await pumpHome(tester, analyticsService: analyticsService);

    await tester.tap(find.text('Start today’s test'));
    await tester.pump();

    expect(analyticsService.modesSelected, [AnalyticsService.modeDailyTest]);
  });

  testWidgets('the Daily Test card spans the content width (page padding, Q18)',
      (tester) async {
    for (final width in [320.0, 390.0, 430.0]) {
      await pumpHome(tester, size: Size(width, 844));
      final hPad = width < 360 ? 14.0 : 18.0;
      final card = tester.getRect(find.byKey(HomeScreen.dailyTestCardKey));
      expect(card.left, closeTo(hPad, 1), reason: '$width');
      expect(card.right, closeTo(width - hPad, 1), reason: '$width');
    }
  });

  testWidgets(
      'the greeting is larger than a section title and smaller than the '
      'brand; the name is the same size, bolder (V15)', (tester) async {
    await pumpHome(tester);
    TextStyle style(Finder f) => tester.widget<Text>(f).style!;
    final greeting = style(find.text('Good morning,'));
    final name = style(find.text('Ada'));
    final brand = style(find.text('GrammarLens'));
    final section = style(find.text('Topic practice'));
    expect(greeting.fontSize,
        closeTo(section.fontSize! * HomeScreen.greetingScale, .01));
    expect(greeting.fontSize, greaterThan(section.fontSize!));
    expect(name.fontSize, greeting.fontSize);
    expect(name.fontWeight!.value, greaterThan(greeting.fontWeight!.value));
    expect(greeting.fontSize, lessThan(brand.fontSize!));
  });

  testWidgets('320 pt, Large text: a long name wraps inside the page',
      (tester) async {
    await pumpHome(tester,
        size: const Size(320, 844),
        textSize: AppTextSize.large,
        userName: 'Maximiliana Alexandra Konstantinopoulou');
    expect(tester.takeException(), isNull);
    final name = find.text('Maximiliana Alexandra Konstantinopoulou');
    final paragraph = tester.renderObject<RenderParagraph>(name);
    expect(paragraph.didExceedMaxLines, isFalse);
    // More than one line: it wraps instead of running under the hero.
    final lineHeight = tester.widget<Text>(name).style!.fontSize! *
        tester.widget<Text>(name).style!.height!;
    expect(tester.getSize(name).height, greaterThan(lineHeight * 1.5));
    expect(tester.getRect(name).right, lessThanOrEqualTo(320));
  });

  // 1.2.0 Batch 3: no overflow anywhere on Home at the three widths, the
  // largest app text size, in both themes; the name is never lost at 320 pt
  // (the 1.1.0 fix), now beside the score capsule.
  for (final width in [320.0, 390.0, 430.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          '${width.toInt()} pt, Large text, ${brightness.name}: no overflow '
          'from top to bottom', (tester) async {
        await pumpHome(tester,
            size: Size(width, 844),
            brightness: brightness,
            textSize: AppTextSize.large,
            storageService: _FakeStorageService()
              ..weakSpots = [_weakSpot(), _weakSpot(topicId: 'modalVerbs')],
            userName: 'Maximiliana Alexandra');
        expect(tester.takeException(), isNull);

        // The greeting stays inside the page, and the whole name is there.
        final greeting = tester.getRect(find.byType(HomeGreeting));
        expect(greeting.right, lessThanOrEqualTo(width));
        expect(tester.getRect(find.byKey(HomeScreen.capsuleKey)).right,
            lessThanOrEqualTo(width));
        expect(find.text('Maximiliana Alexandra'), findsOneWidget);
        final name = tester
            .renderObject<RenderParagraph>(find.text('Maximiliana Alexandra'));
        expect(name.didExceedMaxLines, isFalse);

        final page = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        while (page.pixels < page.maxScrollExtent) {
          page.jumpTo(
              (page.pixels + 300).clamp(0.0, page.maxScrollExtent).toDouble());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'at ${page.pixels}');
        }
        // The last thing on Home scrolls fully into view.
        expect(tester.getRect(find.byKey(TopicShowcase.unlockKey)).bottom,
            lessThanOrEqualTo(844));
      });
    }
  }
}
