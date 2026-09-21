import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
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
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// The bottom "Premium" upsell row's own label — disambiguated from
/// `LockedPremiumPill`'s identically-worded "Premium" text (shown on a
/// locked Topic Practice card, docs/design-audit.md Batch 0 item 3) by
/// anchoring on the row's own description line, which only ever sits next
/// to the row's label, never the pill's.
Finder _premiumRowLabel() => find.descendant(
      of: find
          .ancestor(
            of: find.text('Unlock targeted practice on your weak spots'),
            matching: find.byType(Column),
          )
          .first,
      matching: find.text('Premium'),
    );

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
  Future<void> modeSelected(String mode) async {
    modesSelected.add(mode);
  }
}

class _CountingClaudeService extends ClaudeService {
  int generationCalls = 0;
  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
  }) async {
    generationCalls++;
    throw StateError('Cached Home flow must not generate questions');
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
  int steps = 0;
  int completionCalls = 0;
  Completer<void>? pendingCompletion;

  /// What a successful completion reports: whether it just earned the Welcome
  /// badge (a user who had never earned a step before).
  bool welcomeBadge = false;
  bool failProgress = false;
  final monthsRead = <(int, int)>[];
  Completer<({int steps, int correct, int wrong, int skipped})>?
      pendingProgress;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
      int year, int month) async {
    monthsRead.add((year, month));
    if (failProgress) throw StateError('Read failed');
    if (pendingProgress != null) return pendingProgress!.future;
    return (steps: steps, correct: 0, wrong: 0, skipped: 0);
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
      weakSpots;
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

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    String userName = 'Ada',
    Avatar? avatar,
    VoidCallback? onAvatarTap,
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
        theme: buildAppTheme(brightness),
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
      expect(find.text('28 / 28 steps'), findsOneWidget);
      for (var i = 0;
          i < 20 && find.text('Topic Practice').evaluate().isEmpty;
          i++) {
        outer.jumpTo(outer.pixels + 200);
        await tester.pumpAndSettle();
      }
      expect(find.text('Topic Practice'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      final inner = tester
          .state<ScrollableState>(
              find.descendant(of: mountain, matching: find.byType(Scrollable)))
          .position;
      final pageBefore = outer.pixels;
      final trailBefore = inner.pixels;
      await tester.dragFrom(tester.getCenter(mountain), const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(outer.pixels, greaterThan(pageBefore));
      expect(inner.pixels, trailBefore);
      expect(find.text('Topic Practice').hitTestable(), findsOneWidget);
      expect(find.textContaining('Answer at least'), findsNothing);
      expect(find.textContaining('Your climb starts'), findsNothing);
      await tester.ensureVisible(find.text('8 / 31 steps'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.text('8 / 31 steps')).label,
          'Monthly progress: 8 of 31 steps.');
      expect(tester.getTopLeft(find.text('8 / 31 steps')).dy,
          lessThan(tester.getTopLeft(mountain).dy));
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
      await tester.tap(find.text('Daily Test'));
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
      await tester.ensureVisible(find.textContaining('0/5 correct'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('0/5 correct'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(storage.completionCalls, 1);
      expect(storage.steps, answer.isEmpty ? 0 : 1);
      expect(claude.generationCalls, 0);
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
    await tester.tap(find.text('Daily Test'));
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
        await tester.tap(find.text('Daily Test'));
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
          expect(middleTop, greaterThan(endTop));
        }
        await tester.ensureVisible(find.textContaining('0/1 correct'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('0/1 correct'));
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
      'a badge earned from Home: Start my climb plays the confetti on the '
      'results, and only then does Home animate the step', (tester) async {
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
    await tester.tap(find.text('Daily Test'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'wrong');
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(storage.steps, 9);
    expect(find.text('Start my climb'), findsOneWidget);
    expect(find.text('See your climb'), findsNothing);

    await tester.tap(find.text('Start my climb'));
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1000));
    // Still on the results, with the mountain not yet moved.
    expect(find.byType(DailyTestResultScreen), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(tester.widget<MonthlyMountain>(mountain).completedDays, 8);
    expect(pawnTop(), oldTop);

    await tester.pump(const Duration(milliseconds: 900));
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
    expect(middleTop, greaterThan(endTop));
    expect(storage.completionCalls, 1);
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
    expect(find.text('Good evening, Ada'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 1, 2, 9);
    storage.todaysDailyTest = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Good morning, Ada'), findsOneWidget);
    expect(find.textContaining('New test tomorrow'), findsNothing);
    expect(find.textContaining("Today's 5-question warm-up"), findsOneWidget);
  });

  testWidgets('greets the user by their onboarding name', (tester) async {
    await pumpHome(tester);
    expect(find.text('Good morning, Ada'), findsOneWidget);
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
    expect(find.text('Good evening, Ada'), findsOneWidget);
    expect(find.text('Good morning, Ada'), findsNothing);
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

    final greetingLeft = tester.getTopLeft(find.text('Good morning, Ada')).dx;
    final avatarRect = tester.getRect(find.byType(AvatarTile));
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    // To the right of the greeting text, not before it.
    expect(avatarRect.left, greaterThan(greetingLeft));
    // Flush against the trailing screen edge (within the row's own
    // padding), not floating in the middle.
    expect(avatarRect.right, greaterThan(screenWidth - 60));
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

  group('Today (Daily Test state, PRD v2 §13.5 item 2)', () {
    testWidgets('not yet done: shows an invitation, tapping opens Daily Test',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());

      expect(find.text('Daily Test'), findsOneWidget);
      expect(
        find.textContaining("ready — free, always"),
        findsOneWidget,
      );

      await tester.tap(find.text('Daily Test'));
      await tester.pumpAndSettle();

      expect(find.byType(DailyTestScreen), findsOneWidget);
    });

    testWidgets(
        'done: shows the score and "new test tomorrow", not the '
        'invitation', (tester) async {
      final storage = _FakeStorageService()
        ..todaysDailyTest = _completedDailyTestSet(correct: 3, total: 5);
      await pumpHome(tester, storageService: storage);

      expect(find.textContaining('3/5 correct'), findsOneWidget);
      expect(find.textContaining('New test tomorrow'), findsOneWidget);
      expect(find.text('Daily Test'), findsNothing);
    });

    testWidgets('done: tapping it views the result again, not a new test',
        (tester) async {
      final storage = _FakeStorageService()
        ..todaysDailyTest = _completedDailyTestSet(correct: 2, total: 5);
      await pumpHome(tester, storageService: storage);

      await tester.tap(find.textContaining('2/5 correct'));
      await tester.pumpAndSettle();

      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      expect(find.byType(DailyTestScreen), findsNothing);
      // The real score, reconstructed from the persisted answers, not
      // recomputed from nothing.
      expect(find.textContaining('2/5 correct'), findsOneWidget);
    });
  });

  testWidgets('shows the Topic Practice card', (tester) async {
    await pumpHome(tester);
    expect(find.text('Topic Practice'), findsOneWidget);
    // Streak Mode and Voice Practice were removed from Home entirely (App
    // Store completeness risk at the time; both were also later dropped
    // from the Premium screen itself — PRD v2 §13.4, nothing unbuilt gets
    // sold) — see docs/roadmap.md.
    expect(find.text('Streak Mode'), findsNothing);
    expect(find.text('Voice Practice'), findsNothing);
  });

  testWidgets(
      'the Today card and Topic Practice card are both full-width, not '
      'grid tiles', (tester) async {
    await pumpHome(tester);
    expect(find.byType(GridView), findsNothing);

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    for (final title in ['Daily Test', 'Topic Practice']) {
      final cardRect = tester.getRect(
        find.ancestor(of: find.text(title), matching: find.byType(Card)),
      );
      expect(cardRect.left, closeTo(hPad, 1));
      expect(cardRect.right, closeTo(width - hPad, 1));
    }
  });

  testWidgets(
      'stacks in order: Today, then Topic Practice, then the Premium row',
      (tester) async {
    await pumpHome(tester);

    final todayTop = tester.getTopLeft(find.text('Daily Test')).dy;
    final topicTop = tester.getTopLeft(find.text('Topic Practice')).dy;
    final premiumTop = tester.getTopLeft(_premiumRowLabel()).dy;

    expect(topicTop, greaterThan(todayTop));
    expect(premiumTop, greaterThan(topicTop));
  });

  testWidgets(
      'Daily Test is wired to its own entry point, distinct from Topic '
      'Practice/Premium', (tester) async {
    final analyticsService = _RecordingAnalyticsService();
    await pumpHome(tester, analyticsService: analyticsService);

    await tester.tap(find.text('Daily Test'));
    await tester.pump();

    expect(analyticsService.modesSelected, [AnalyticsService.modeDailyTest]);
  });

  testWidgets(
      'Topic Practice opens the existing MVP loop when the entitlement is '
      'active', (tester) async {
    await pumpHome(
      tester,
      subscriptionService: _FakeSubscriptionService(hasAccess: true),
    );
    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();
    expect(find.byType(TopicPracticeScreen), findsOneWidget);
  });

  testWidgets(
      'Topic Practice shows locked and opens the Premium screen instead, '
      'with no entitlement active (PRD v2 §12.2/§12.3)', (tester) async {
    await pumpHome(tester); // default fake: hasAccess: false
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();

    expect(find.byType(TopicPracticeScreen), findsNothing);
    expect(find.byType(PremiumScreen), findsOneWidget);
  });

  testWidgets(
      'reacts live to an entitlement change — a trial starting unlocks the '
      'card without rebuilding the screen', (tester) async {
    final subscriptionService = _FakeSubscriptionService();
    await pumpHome(tester, subscriptionService: subscriptionService);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    subscriptionService.emitAccessChange(true);
    await tester.pump();

    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();
    expect(find.byType(TopicPracticeScreen), findsOneWidget);
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

  group('Premium row (PRD v2 §13.5 item 5)', () {
    testWidgets('shown for a free user, opens the Premium screen',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(_premiumRowLabel());
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets(
        'not shown once the entitlement is active — no repeated '
        'upsell to someone already subscribed', (tester) async {
      await pumpHome(
        tester,
        subscriptionService: _FakeSubscriptionService(hasAccess: true),
      );
      expect(
        find.text('Unlock targeted practice on your weak spots'),
        findsNothing,
      );
    });

    testWidgets('states what it offers, not just the word "Premium"',
        (tester) async {
      await pumpHome(tester);
      expect(
        find.text('Unlock targeted practice on your weak spots'),
        findsOneWidget,
      );
    });

    testWidgets(
        'text color is the scaffold foreground, not the low-contrast '
        'onSurfaceVariant meant for a surface background — this row sits '
        'directly on the orange scaffold in light mode', (tester) async {
      await pumpHome(tester);

      final theme = Theme.of(tester.element(_premiumRowLabel()));
      final expectedFg =
          theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

      final style = tester.widget<Text>(_premiumRowLabel()).style;
      expect(style?.color, expectedFg);
      expect(style?.color, isNot(theme.colorScheme.onSurfaceVariant));
    });
  });
}
