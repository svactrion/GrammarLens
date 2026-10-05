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
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
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
import 'package:grammar_lens/widgets/home_greeting.dart';
import 'package:grammar_lens/widgets/weak_spot_card.dart';
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
    VoidCallback? onAvatarTap,
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
          onAvatarTap: onAvatarTap,
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
      await tester.tap(find.text('Start daily test'));
      await tester.pumpAndSettle();
      if (answer.isNotEmpty) {
        await tester.enterText(find.byType(TextField).first, answer);
      }
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester
            .tap(find.text(i == 0 && answer.isNotEmpty ? 'Next' : 'Skip'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Skip'));
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
      await tester.ensureVisible(find.text('Review results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review results'));
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
    await tester.tap(find.text('Start daily test'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'wrong');
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pageBack();
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
        await tester.tap(find.text('Start daily test'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'wrong');
        await tester.pump();
        await tester.tap(find.text('Finish'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 2));
        expect(storage.steps, 9); // Persisted while results are still open.
        expect(tester.widget<MonthlyMountain>(mountain).completedDays, 8);
        expect(pawnTop(), oldTop); // No hidden animation.
        if (useButton) {
          await tester.scrollUntilVisible(find.text('See your climb'), 250,
              scrollable: find.byType(Scrollable).last);
          await tester.tap(find.text('See your climb'));
        } else {
          await tester.pageBack();
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
        await tester.ensureVisible(find.text('Review results'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review results'));
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
    await tester.tap(find.text('Start daily test'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'wrong');
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(storage.steps, 9);
    // Batch 5 (N15): the celebration over the results first; its own
    // confetti went with it.
    await closeCelebration(tester);
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(find.text('Start my climb'), findsOneWidget);
    expect(find.text('See your climb'), findsNothing);

    // N36: no confetti of its own; the results pop and Home steps.
    await tester.tap(find.text('Start my climb'));
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
      'the score bar under the mountain reads the month\'s score and '
      'thresholds (D9)', (tester) async {
    final semantics = tester.ensureSemantics();
    // October 2026: 31 days, 310 points at most; Bronze 78, Silver 155,
    // Gold 233 (rule v1). 20 correct and 10 wrong = 50 points.
    final storage = _FakeStorageService()
      ..steps = 6
      ..correct = 20
      ..wrong = 10;
    await pumpHome(tester,
        storageService: storage, clock: () => DateTime(2026, 10, 12, 9));
    await tester.pumpAndSettle();
    final bar = find.byType(ClimbScoreBar);
    expect(bar, findsOneWidget);
    final widget = tester.widget<ClimbScoreBar>(bar);
    expect(widget.score, 50);
    expect(widget.maxScore, 310);
    expect(widget.thresholds,
        {MedalTier.bronze: 78, MedalTier.silver: 155, MedalTier.gold: 233});
    expect(
        find.bySemanticsLabel('Monthly score: 50 of 310 points. Bronze at 78, '
            'Silver at 155, Gold at 233.'),
        findsOneWidget);
    // A strip of its own directly under the window, not over the scene.
    final window = tester.getRect(find.byType(MonthlyMountain));
    final strip = tester.getRect(bar);
    expect(strip.top, closeTo(window.bottom, .01));
    expect(strip.width, window.width);
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
    await tester.tap(find.text('Retry progress'));
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
    expect(find.textContaining('New test tomorrow'), findsNothing);
    expect(find.text('Start daily test'), findsOneWidget);
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

  testWidgets('shows a placeholder avatar when none has been picked',
      (tester) async {
    await pumpHome(tester);
    final circle = tester.widget<AvatarTile>(find.byType(AvatarTile));
    expect(circle.avatar, isNull);
  });

  testWidgets('shows the picked avatar next to the greeting', (tester) async {
    final penguin =
        Avatar.values.firstWhere((a) => a.semanticLabel == 'Penguin');
    await pumpHome(tester, avatar: penguin);
    final circle = tester.widget<AvatarTile>(find.byType(AvatarTile));
    expect(circle.avatar, penguin);
  });

  testWidgets(
      'avatar sits trailing at the far right, after the greeting text, not '
      'leading before it', (tester) async {
    await pumpHome(tester);

    final greetingLeft = tester.getTopLeft(_greeting('Good morning, Ada')).dx;
    final avatarRect = tester.getRect(find.byType(AvatarTile));
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    // To the right of the greeting text, not before it.
    expect(avatarRect.left, greaterThan(greetingLeft));
    // Flush against the trailing screen edge (within the row's own
    // padding), not floating in the middle.
    expect(avatarRect.right, greaterThan(screenWidth - 60));
  });

  testWidgets(
      'no edit badge on the hero (owner, after Batch 3); the avatar itself is '
      'the "Change your avatar" control', (tester) async {
    final semantics = tester.ensureSemantics();
    var tapped = false;
    await pumpHome(tester, onAvatarTap: () => tapped = true);

    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.bySemanticsLabel('Change your avatar'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Change your avatar'));
    await tester.pump();
    expect(tapped, isTrue);
    semantics.dispose();
  });

  testWidgets('tapping the avatar calls onAvatarTap', (tester) async {
    var tapped = false;
    await pumpHome(tester, onAvatarTap: () => tapped = true);

    await tester.tap(find.byType(AvatarTile));
    await tester.pump();

    expect(tapped, isTrue);
  });

  group(
      'avatar tap opens the picker via a real route push, with a Hero '
      'flight (app.dart, batch: Home avatar → Settings picker transition)', () {
    // Mirrors app.dart's real _openAvatarPickerFromHome exactly (a real
    // Navigator.push, branching on MediaQuery.disableAnimationsOf the same
    // manual way this app already gates motion everywhere else) — the
    // same "minimal harness reproducing the real wiring" approach this
    // suite's sibling files already use (avatar_picker_screen_test.dart's
    // own pumpPushed) rather than driving the whole GrammarLensApp through
    // onboarding just to reach Home.
    Future<void> pumpHomeInNavigator(
      WidgetTester tester, {
      required ValueChanged<Avatar> onAvatarChanged,
    }) async {
      tester.view.physicalSize = const Size(390, 844) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Builder(
            builder: (context) => HomeScreen(
              userName: 'Ada',
              avatar: Avatar.values[3],
              claudeService: ClaudeService(),
              storageService: StorageService(),
              analyticsService: AnalyticsService(),
              subscriptionService: _FakeSubscriptionService(),
              clock: () => DateTime(2026, 1, 1, 9, 0),
              onAvatarTap: () {
                final reduceMotion = MediaQuery.disableAnimationsOf(context);
                final picker = AvatarPickerScreen(
                  currentAvatar: Avatar.values[3],
                  onAvatarChanged: onAvatarChanged,
                  heroTag: homeAvatarHeroTag,
                );
                Navigator.of(context).push(
                  reduceMotion
                      ? PageRouteBuilder(
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                          pageBuilder: (_, __, ___) => picker,
                        )
                      : MaterialPageRoute(builder: (_) => picker),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'tapping the avatar opens AvatarPickerScreen, not a tab '
        'switch', (tester) async {
      await pumpHomeInNavigator(tester, onAvatarChanged: (_) {});

      expect(find.byType(AvatarPickerScreen), findsNothing);
      await tester.tap(find.byType(AvatarTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(AvatarPickerScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing,
          reason: 'a real push covers Home, unlike the old tab switch');
    });

    testWidgets('Done on the picker pops back to Home', (tester) async {
      await pumpHomeInNavigator(tester, onAvatarChanged: (_) {});
      await tester.tap(find.byType(AvatarTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      expect(find.byType(AvatarPickerScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        'with MediaQuery.disableAnimations on, the route has a zero-duration '
        'transition — no flight, an instant switch', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await pumpHomeInNavigator(tester, onAvatarChanged: (_) {});
      await tester.tap(find.byType(AvatarTile).first);
      await tester.pump();

      final route = ModalRoute.of(
        tester.element(find.byType(AvatarPickerScreen)),
      ) as PageRoute;
      expect(route.transitionDuration, Duration.zero);
    });

    testWidgets(
        'with normal motion, the route animates with MaterialPageRoute\'s '
        'own (non-zero) transition duration', (tester) async {
      await pumpHomeInNavigator(tester, onAvatarChanged: (_) {});
      await tester.tap(find.byType(AvatarTile).first);
      // A normal (non-zero-duration) route needs two pumps here: the
      // first only processes the tap's own push() call, the second
      // actually builds the incoming route's page.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final route = ModalRoute.of(
        tester.element(find.byType(AvatarPickerScreen)),
      ) as PageRoute;
      expect(route.transitionDuration, isNot(Duration.zero));
      await tester.pumpAndSettle();
    });
  });

  // 1.2.0 Batch 3: the Daily Test card (brief, "Home"; batch0-report.md
  // §6 N4). These replace the old whole-card "Today" tests: the entry is the
  // card's button now, with the same two handlers behind it.
  group('Daily Test card (1.2.0)', () {
    testWidgets(
        'not started: the real question count and "Start daily test", no '
        'progress bar; the button opens the Daily Test', (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());
      final card = find.byKey(HomeScreen.dailyTestCardKey);

      expect(find.descendant(of: card, matching: find.text('Your next step.')),
          findsOneWidget);
      expect(
          find.descendant(
              of: card, matching: find.text('${DailyTestSet.questionCount}')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('questions')),
          findsOneWidget);
      // The same order as the done state: the label above the number.
      expect(
          tester
              .getRect(
                  find.descendant(of: card, matching: find.text('questions')))
              .bottom,
          lessThanOrEqualTo(tester
              .getRect(find.descendant(
                  of: card,
                  matching: find.text('${DailyTestSet.questionCount}')))
              .top));
      expect(find.descendant(of: card, matching: find.text('Review results')),
          findsNothing);
      expect(
          find.descendant(
              of: card, matching: find.byType(LinearProgressIndicator)),
          findsNothing);

      await tester.tap(find.text('Start daily test'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestScreen), findsOneWidget);
    });

    testWidgets(
        'done: the real score, "Review results" and tomorrow\'s line, not '
        'the invitation', (tester) async {
      final storage = _FakeStorageService()
        ..todaysDailyTest = _completedDailyTestSet(correct: 3, total: 5);
      await pumpHome(tester, storageService: storage);
      final card = find.byKey(HomeScreen.dailyTestCardKey);

      expect(find.descendant(of: card, matching: find.text('3/5')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('correct')),
          findsOneWidget);
      expect(
          find.descendant(
              of: card,
              matching:
                  find.text('New test tomorrow. Review today’s answers.')),
          findsOneWidget);
      expect(find.text('Start daily test'), findsNothing);
      expect(find.text('Review results'), findsOneWidget);
      // The label above the value, one step larger than the card's 11 pt
      // labels (owner, after Batch 3).
      final label = find.descendant(of: card, matching: find.text('correct'));
      final value = find.descendant(of: card, matching: find.text('3/5'));
      expect(tester.getRect(label).bottom,
          lessThanOrEqualTo(tester.getRect(value).top));
      final theme = Theme.of(tester.element(card));
      expect(tester.widget<Text>(label).style!.fontSize,
          theme.textTheme.labelMedium!.fontSize);
    });

    testWidgets(
        'done: the button views the result again (onViewResult), not a new '
        'test', (tester) async {
      final storage = _FakeStorageService()
        ..todaysDailyTest = _completedDailyTestSet(correct: 2, total: 5);
      await pumpHome(tester, storageService: storage);

      await tester.tap(find.text('Review results'));
      await tester.pumpAndSettle();

      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      expect(find.byType(DailyTestScreen), findsNothing);
      // The real score, reconstructed from the persisted answers, not
      // recomputed from nothing.
      expect(find.textContaining('2/5 correct'), findsOneWidget);
    });

    testWidgets(
        'only the button is the entry: a tap on the card\'s text does '
        'nothing', (tester) async {
      final analyticsService = _RecordingAnalyticsService();
      await pumpHome(tester, analyticsService: analyticsService);
      await tester.tap(find.text('Your next step.'));
      await tester.pumpAndSettle();
      expect(analyticsService.modesSelected, isEmpty);
      expect(find.byType(DailyTestScreen), findsNothing);
    });

    testWidgets(
        'the card is orange with onOrange text in both themes, the button '
        'the app\'s navy', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpHome(tester, brightness: brightness);
        final card = find.byKey(HomeScreen.dailyTestCardKey);
        final theme = Theme.of(tester.element(card));
        final material = tester.widget<Card>(
            find.descendant(of: card, matching: find.byType(Card)));
        expect(material.color, theme.colorScheme.primary,
            reason: '$brightness');
        final title = tester.widget<Text>(find.text('Your next step.'));
        expect(title.style!.color, theme.colorScheme.onPrimary,
            reason: '$brightness: dark text on orange, never white');
        expect(find.descendant(of: card, matching: find.byType(FilledButton)),
            findsOneWidget);
      }
    });

    testWidgets(
        'the month card peek (M21) is the button and the padding below it',
        (tester) async {
      await pumpHome(tester);
      final card = tester.getRect(find.byKey(HomeScreen.dailyTestCardKey));
      final button = tester.getRect(find.ancestor(
          of: find.text('Start daily test'),
          matching: find.byType(FilledButton)));
      expect(
          card.bottom - button.top, closeTo(HomeScreen.monthCardTodayPeek, 1));
    });
  });

  testWidgets(
      'Daily Test is wired to its own entry point, distinct from Topic '
      'Practice/Premium', (tester) async {
    final analyticsService = _RecordingAnalyticsService();
    await pumpHome(tester, analyticsService: analyticsService);

    await tester.tap(find.text('Start daily test'));
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

  group('Topic practice strip (1.2.0, Q9, Q10)', () {
    Future<void> revealStrip(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Explore all topics'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the real topics, not the mockup\'s examples',
        (tester) async {
      await pumpHome(tester);
      await revealStrip(tester);
      for (final topic in kTopics) {
        expect(find.text(topic.title), findsOneWidget, reason: topic.title);
      }
      expect(find.text('Tenses'), findsNothing);
      expect(find.text('Prepositions'), findsNothing);
      // Streak Mode and Voice Practice stay gone from Home.
      expect(find.text('Streak Mode'), findsNothing);
      expect(find.text('Voice Practice'), findsNothing);
    });

    testWidgets(
        'a free user: the heading carries the Premium tag, and a topic opens '
        'the Premium screen, not Topic Practice', (tester) async {
      await pumpHome(tester); // default fake: hasAccess: false
      await revealStrip(tester);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.text(kTopics.first.title));
      await tester.pumpAndSettle();

      expect(find.byType(TopicPracticeScreen), findsNothing);
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets('a free user: "Explore all topics" opens the Premium screen',
        (tester) async {
      await pumpHome(tester);
      await revealStrip(tester);
      await tester.tap(find.text('Explore all topics'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets(
        'a premium user: a topic and "Explore all topics" open the existing '
        'Topic Practice screen; no Premium tag', (tester) async {
      await pumpHome(
        tester,
        subscriptionService: _FakeSubscriptionService(hasAccess: true),
      );
      await revealStrip(tester);
      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await tester.tap(find.text(kTopics.first.title));
      await tester.pumpAndSettle();
      expect(find.byType(TopicPracticeScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore all topics'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicPracticeScreen), findsOneWidget);
    });

    testWidgets(
        'reacts live to an entitlement change — a trial starting unlocks the '
        'strip without rebuilding the screen', (tester) async {
      final subscriptionService = _FakeSubscriptionService();
      await pumpHome(tester, subscriptionService: subscriptionService);
      await revealStrip(tester);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      subscriptionService.emitAccessChange(true);
      await tester.pump();
      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await tester.tap(find.text(kTopics.first.title));
      await tester.pumpAndSettle();
      expect(find.byType(TopicPracticeScreen), findsOneWidget);
    });

    testWidgets('the strip scrolls sideways and leaves the page where it is',
        (tester) async {
      await pumpHome(tester);
      await revealStrip(tester);
      final page =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      final pageBefore = page.pixels;
      final strip = find.descendant(
          of: find.byKey(const ValueKey('home_topic_strip')),
          matching: find.byType(Scrollable));
      final stripPosition = tester.state<ScrollableState>(strip).position;

      await tester.drag(find.text(kTopics.first.title), const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(stripPosition.pixels, greaterThan(0));
      expect(page.pixels, pageBefore);
    });
  });

  testWidgets(
      'stacks in order: the Daily Test card, the mountain, Topic practice, '
      'the weak spots, the Review call-out', (tester) async {
    final storage = _FakeStorageService()..weakSpots = [_weakSpot()];
    await pumpHome(tester, storageService: storage);
    double top(Finder f) => tester.getTopLeft(f).dy;

    final daily = top(find.byKey(HomeScreen.dailyTestCardKey));
    final mountain = top(find.byType(MonthlyMountain));
    final topics = top(find.text('Topic practice'));
    final weak = top(find.text('Your weak spots'));
    final review = top(find.text('One free practice. Every day.'));
    expect(mountain, greaterThan(daily));
    expect(topics, greaterThan(mountain));
    expect(weak, greaterThan(topics));
    expect(review, greaterThan(weak));
  });

  group('weak spots (PRD v2 §13.5 item 4)', () {
    testWidgets('no section at all when there are none — no empty state',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());
      expect(find.text('Your weak spots'), findsNothing);
    });

    testWidgets(
        'shows up to the most frequent, tappable through when '
        'unlocked', (tester) async {
      final storage = _FakeStorageService()..weakSpots = [_weakSpot()];
      await pumpHome(
        tester,
        storageService: storage,
        subscriptionService: _FakeSubscriptionService(hasAccess: true),
      );

      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(550);
      await tester.pumpAndSettle();
      expect(find.text('Your weak spots'), findsOneWidget);
      expect(
        find.text('You left out "the" before a specific noun.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await tester.ensureVisible(
          find.text('You left out "the" before a specific noun.'));
      // 1.2.0: Home is longer; the scroll ensureVisible makes has to be
      // drawn before the tap lands on the card.
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('You left out "the" before a specific noun.'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeakSpotDetailScreen), findsOneWidget);
    });

    testWidgets(
        'shows locked when the entitlement is not active, and tapping '
        'opens the Premium screen naming that weak spot', (tester) async {
      final storage = _FakeStorageService()..weakSpots = [_weakSpot()];
      await pumpHome(tester, storageService: storage); // hasAccess: false

      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(550);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      await tester.ensureVisible(
          find.text('You left out "the" before a specific noun.'));
      // 1.2.0: Home is longer; the scroll ensureVisible makes has to be
      // drawn before the tap lands on the card.
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('You left out "the" before a specific noun.'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeakSpotDetailScreen), findsNothing);
      final premium = tester.widget<PremiumScreen>(
        find.byType(PremiumScreen),
      );
      expect(premium.sourceContext, 'Missing Article');
    });
  });

  // 1.2.0 (owner decision Q15): the Premium row that used to end Home is
  // gone; a pointer to Review's free daily practice takes its place.
  group('Review call-out (1.2.0, Q15)', () {
    testWidgets('no Premium row any more, for a free user either',
        (tester) async {
      await pumpHome(tester,
          storageService: _FakeStorageService()..weakSpots = [_weakSpot()]);
      expect(find.text('Unlock targeted practice on your weak spots'),
          findsNothing);
    });

    testWidgets(
        'a free user with weak spots: shown, and it switches to the Review '
        'tab', (tester) async {
      var toReview = 0;
      await pumpHome(tester,
          storageService: _FakeStorageService()..weakSpots = [_weakSpot()],
          onGoToReview: () => toReview++);
      final link = find.text('Go to Review');
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      expect(find.text('One free practice. Every day.'), findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(toReview, 1);
      // A tab switch, not a pushed route.
      expect(find.byType(PremiumScreen), findsNothing);
    });

    testWidgets('not shown to a premium user (no quota to describe)',
        (tester) async {
      await pumpHome(tester,
          storageService: _FakeStorageService()..weakSpots = [_weakSpot()],
          subscriptionService: _FakeSubscriptionService(hasAccess: true));
      expect(find.text('One free practice. Every day.'), findsNothing);
    });

    testWidgets('not shown when there is no weak spot to choose',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());
      expect(find.text('One free practice. Every day.'), findsNothing);
    });
  });

  testWidgets(
      'the greeting word is larger than a section title and smaller than '
      'the name and the brand (owner, after Batch 3)', (tester) async {
    await pumpHome(tester);
    double size(Finder f) => tester.widget<Text>(f).style!.fontSize!;
    final greeting = size(find.text('Good morning,'));
    final name = size(find.text('Ada'));
    final brand = size(find.text('GrammarLens'));
    final section = size(find.text('Topic practice'));
    expect(greeting, closeTo(section * HomeScreen.greetingScale, .01));
    expect(greeting, greaterThan(section));
    expect(greeting, lessThan(name));
    expect(greeting, lessThan(brand));
  });

  testWidgets('320 pt, Large text: a long name wraps under the greeting',
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
    expect(tester.getRect(name).right,
        lessThanOrEqualTo(tester.getRect(find.byType(AvatarTile)).left));
  });

  testWidgets(
      'the weak spots badge shows the real total, while Home shows at most '
      'three cards (owner, after Batch 3)', (tester) async {
    final storage = _FakeStorageService()
      ..weakSpots = [
        for (var i = 0; i < 7; i++) _weakSpot(frequency: 7 - i),
      ]
      ..topicStats = const {
        'articles': TopicStats(practiced: 10, weakSpotCount: 4),
        'modalVerbs': TopicStats(practiced: 5, weakSpotCount: 3),
        'tenseSelection': TopicStats(practiced: 2, weakSpotCount: 0),
      };
    await pumpHome(tester, storageService: storage);
    expect(find.text('7 weak spots'), findsOneWidget);
    expect(find.byType(WeakSpotCard), findsNWidgets(3));
  });

  testWidgets('the weak spots heading counts the weak spots shown',
      (tester) async {
    await pumpHome(tester,
        storageService: _FakeStorageService()
          ..weakSpots = [_weakSpot(), _weakSpot(topicId: 'modalVerbs')]);
    expect(find.text('2 weak spots'), findsOneWidget);
  });

  // 1.2.0 Batch 3: no overflow anywhere on Home at the three widths, the
  // largest app text size, in both themes; and the greeting row's 1.1.0
  // fix (the name never lost at 320 pt) holds with the larger hero.
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

        // The greeting and the hero share a row without overlapping, and
        // the whole name is there.
        final greeting = tester.getRect(find.byType(HomeGreeting));
        final hero = tester.getRect(find.byType(AvatarTile).first);
        expect(greeting.right, lessThanOrEqualTo(hero.left));
        expect(hero.right, lessThanOrEqualTo(width));
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
        expect(tester.getRect(find.text('Go to Review')).bottom,
            lessThanOrEqualTo(844));
      });
    }
  }
}
