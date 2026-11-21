import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'support/recording_analytics_sink.dart';
import 'package:grammar_lens/utils/text_format.dart';
import 'package:grammar_lens/screens/premium_on_screen.dart';
import 'package:grammar_lens/widgets/rest_scene.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/reminder_soft_ask.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/native_bridge.dart';
import 'package:grammar_lens/services/reminder_controller.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/confetti_burst.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';
import 'package:grammar_lens/widgets/score_capsule.dart';
import 'package:grammar_lens/widgets/error_state.dart';
import 'package:grammar_lens/widgets/home_greeting.dart';
import 'package:grammar_lens/widgets/speech_bubble.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/home_practice.dart';
import 'package:grammar_lens/widgets/rest_reminder_row.dart';
import 'package:grammar_lens/widgets/step_bar.dart';
import 'package:grammar_lens/widgets/ticket.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart'
    show climbImageAspect;
import 'package:grammar_lens/widgets/monthly_climb/mountain_scene.dart';

import 'support/fake_native_bridge.dart';
import 'support/l10n_support.dart';
import 'support/celebration_support.dart';
import 'support/paywall_close.dart';

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

  /// Fix round 2 (V24f → V13r → PW05r): an offering with a 7-day trial,
  /// eligible, and a purchase that succeeds. Null: the real calls (they
  /// never answer in a widget test).
  final Offering? offering;
  int purchases = 0;

  _FakeSubscriptionService({this.hasAccess = false, this.offering});

  @override
  Future<Offering?> getOfferings() {
    final o = offering;
    return o == null ? super.getOfferings() : Future.value(o);
  }

  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
          List<String> productIds) async =>
      {for (final id in productIds) id: TrialEligibility.eligible};

  @override
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    purchases++;
    emitAccessChange(true);
    return PurchaseOutcome.success;
  }

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

  /// The reminder settings (TASK-widgets W5); null reads as a storage
  /// failure, so Home never asks (every older test).
  ReminderSettings? reminderSettings;

  /// The first Daily Test on record (N01 after the second one).
  DateTime? firstCompletion;

  @override
  Future<ReminderSettings> getReminderSettings() async =>
      reminderSettings ?? (throw StateError('no reminder settings'));

  @override
  Future<void> setReminderSettings(ReminderSettings settings) async =>
      reminderSettings = settings;

  @override
  Future<DateTime?> getFirstDailyTestCompletion() async => firstCompletion;
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
    ValueListenable<int>? dailyTestLinks,
    ReminderController? reminders,
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
          dailyTestLinks: dailyTestLinks,
          reminders: reminders,
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
    // Fix round 3 (A1): the results first, then "Climb my first step"
    // opens the Welcome badge; closing it pops the results.
    expect(find.text('Climb my first step'), findsOneWidget);
    expect(find.text('See your climb'), findsNothing);
    await climbThroughWelcome(tester);

    // N36: no confetti of its own; the results pop and Home steps.
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
  // TASK-widgets W1: a `grammarlens://daily-test` link (widget or reminder).
  group('Daily Test link', () {
    testWidgets('opens today\'s Daily Test when it is not done',
        (tester) async {
      final links = ValueNotifier(0);
      addTearDown(links.dispose);
      await pumpHome(tester,
          storageService: _FakeStorageService(), dailyTestLinks: links);
      expect(find.byType(DailyTestScreen), findsNothing);
      links.value++;
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestScreen), findsOneWidget);
    });

    testWidgets('stays on Home when today\'s test is done', (tester) async {
      final links = ValueNotifier(0);
      addTearDown(links.dispose);
      final storage = _FakeStorageService()
        ..steps = 1
        ..todaysDailyTest = _completedDailyTestSet(correct: 3, total: 5);
      await pumpHome(tester, storageService: storage, dailyTestLinks: links);
      links.value++;
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestScreen), findsNothing);
      expect(find.byType(DailyTestResultScreen), findsNothing);
      expect(find.byKey(HomeScreen.dailyTestCardKey), findsOneWidget);
    });

    testWidgets('re-reads today\'s set first (a link right after midnight)',
        (tester) async {
      final links = ValueNotifier(0);
      addTearDown(links.dispose);
      final storage = _FakeStorageService()
        ..steps = 1
        ..todaysDailyTest = _completedDailyTestSet(correct: 3, total: 5);
      await pumpHome(tester, storageService: storage, dailyTestLinks: links);
      // The new day: no completed set any more.
      storage.todaysDailyTest = null;
      links.value++;
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestScreen), findsOneWidget);
    });
  });

  // TASK-widgets W5: N01 opens on its own once, at the first rest scene or
  // after the second Daily Test; V24 carries the reminder row.
  group('Reminder question (N01) and V24\'s row', () {
    ReminderController controllerFor(_FakeStorageService storage) =>
        ReminderController(
            storage: storage,
            bridge: FakeNativeBridge()
              ..permission = NotificationPermission.notDetermined);

    testWidgets('the first rest scene opens N01 once; Not now is final',
        (tester) async {
      final storage = _FakeStorageService()
        ..steps = 3
        ..freeUsed = 1
        ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5)
        ..reminderSettings = const ReminderSettings();
      final reminders = controllerFor(storage);
      addTearDown(reminders.dispose);
      await pumpHome(tester, storageService: storage, reminders: reminders);
      expect(find.byKey(HomeScreen.restSceneKey), findsOneWidget);
      expect(find.byType(ReminderSoftAsk), findsOneWidget);
      expect(find.byKey(RestReminderRow.switchKey), findsOneWidget);
      await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
      await tester.pumpAndSettle();
      expect(storage.reminderSettings!.ask, ReminderAsk.declined);
      // Home rebuilds (a resume): it is not asked again.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSoftAsk), findsNothing);
    });

    testWidgets('already answered: the rest scene does not ask',
        (tester) async {
      final storage = _FakeStorageService()
        ..steps = 3
        ..freeUsed = 1
        ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5)
        ..reminderSettings = const ReminderSettings(ask: ReminderAsk.declined);
      final reminders = controllerFor(storage);
      addTearDown(reminders.dispose);
      await pumpHome(tester, storageService: storage, reminders: reminders);
      expect(find.byKey(HomeScreen.restSceneKey), findsOneWidget);
      expect(find.byType(ReminderSoftAsk), findsNothing);
    });

    testWidgets('back from a Daily Test that is not the first: N01 opens',
        (tester) async {
      final storage = _FakeStorageService()
        ..steps = 2
        ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5)
        ..firstCompletion = DateTime(2025, 12, 31, 20)
        ..reminderSettings = const ReminderSettings();
      final reminders = controllerFor(storage);
      addTearDown(reminders.dispose);
      await pumpHome(tester, storageService: storage, reminders: reminders);
      expect(find.byType(ReminderSoftAsk), findsNothing);
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(DailyTestResultScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSoftAsk), findsOneWidget);
    });

    testWidgets('the very first Daily Test does not ask', (tester) async {
      final storage = _FakeStorageService()
        ..steps = 1
        ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5)
        ..firstCompletion = DateTime(2026, 1, 1, 8)
        ..reminderSettings = const ReminderSettings();
      final reminders = controllerFor(storage);
      addTearDown(reminders.dispose);
      await pumpHome(tester, storageService: storage, reminders: reminders);
      await tester.tap(find.text('Review answers'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DailyTestResultScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ReminderSoftAsk), findsNothing);
    });
  });

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
      final unlock = find.text('Unlock all ${practiceTopics().length} topics');
      await tester.ensureVisible(unlock);
      await tester.pumpAndSettle();
      await tester.tap(unlock);
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.byType(TopicPracticeScreen), findsNothing);
    });

    // 1.5.0: a weak spot in a first-wave topic picks that topic, not the
    // first one (the lookup knew only the Daily Test's five).
    testWidgets('a free user: a weak spot in a new topic is "Picked for you"',
        (tester) async {
      await pumpHome(tester,
          storageService: _FakeStorageService()
            ..weakSpots = [_weakSpot(topicId: 'prepositions')]);
      final showcase = find.byType(TopicShowcase);
      expect(tester.widget<TopicShowcase>(showcase).picked?.id,
          TopicId.prepositions);
      expect(find.descendant(of: showcase, matching: find.text('Prepositions')),
          findsOneWidget);
      expect(find.text('Unlock all 10 topics'), findsOneWidget);
    });

    testWidgets(
        'v13: the paywall from a Home topic card stays on a swipe, a drag '
        'down and a system back; X → V13b once', (tester) async {
      PremiumScreen.resetExitReminder();
      await pumpHome(tester,
          subscriptionService:
              _FakeSubscriptionService(offering: _restOffering()),
          storageService: _FakeStorageService()
            ..weakSpots = [_weakSpot(topicId: 'modalVerbs')]);
      final unlock = find.text('Unlock all ${practiceTopics().length} topics');
      await tester.ensureVisible(unlock);
      await tester.pumpAndSettle();
      await tester.tap(unlock);
      await tester.pumpAndSettle();
      await expectPaywallHolds(tester);
      await closeWithX(tester, reminder: true);
      expect(find.byType(TopicShowcase), findsOneWidget);
      // The second time this session the X closes at once.
      await tester.ensureVisible(unlock);
      await tester.pumpAndSettle();
      await tester.tap(unlock);
      await tester.pumpAndSettle();
      await expectPaywallHolds(tester);
      await closeWithX(tester, reminder: false);
    }, variant: iOSOnly);

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
      // Fix round 2: free users get V24f (SPEC §1.15); v13: the used
      // ticket and the deck, no done tiles.
      expect(find.byKey(RestScene.usedTicketKey), findsOneWidget);
      expect(find.byKey(RestScene.premiumCardKey), findsOneWidget);
      expect(find.byKey(RestScene.doneTilesKey), findsNothing);
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
      // Premium users keep V24: no Premium card, no dream; the Zzz and
      // "See you tomorrow". Fix round 5 (SPEC V24 v13): its own board
      // again — the two done tiles and the next test's card with its step
      // bar and countdown.
      expect(find.byKey(RestScene.premiumCardKey), findsNothing);
      expect(find.byKey(RestScene.usedTicketKey), findsNothing);
      expect(find.byKey(RestScene.dreamKey), findsNothing);
      expect(find.byKey(RestScene.seeYouKey), findsOneWidget);
      expect(
          find.text('Your buddy is resting until tomorrow.'), findsOneWidget);
      expect(find.byKey(RestScene.doneTilesKey), findsOneWidget);
      expect(find.text('Daily Test'), findsOneWidget);
      expect(find.text('5/5 · +10 points'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('$limit/$limit sessions'), findsOneWidget);
      expect(find.byKey(RestScene.nextTestKey), findsOneWidget);
      expect(find.text('NEXT DAILY TEST · STEP 4'), findsOneWidget);
      // Clock 9:00: 15 h to the next test.
      expect(find.text('15:00'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(RestScene.nextTestKey),
              matching: find.byType(StepBar)),
          findsOneWidget);
    });

    group(
        'fix round 2, item 11: the free rest scene leads to Premium '
        '(V24f → V24s → V13r → PW05r)', () {
      Future<(RecordingAnalyticsSink, _FakeSubscriptionService)> pumpRest(
          WidgetTester tester,
          {bool weakSpot = true}) async {
        final sink = RecordingAnalyticsSink();
        final subs = _FakeSubscriptionService(offering: _restOffering());
        final storage = _FakeStorageService()
          ..steps = 3
          ..freeUsed = 1
          ..weakSpots = weakSpot ? [_weakSpot()] : const []
          ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5);
        await pumpHome(tester,
            storageService: storage,
            subscriptionService: subs,
            analyticsService: AnalyticsService(sink: sink),
            size: const Size(428, 926));
        return (sink, subs);
      }

      testWidgets(
          'V24f v13: the dream bubble names today\'s weak spot; no Zzz and '
          'no "See you tomorrow"; the used ticket with the next one\'s '
          'time; the deck of four with NEXT UP, the weak spot and +4 TODAY; '
          'the button states the store\'s trial; the paywall never opens '
          'by itself', (tester) async {
        final (sink, _) = await pumpRest(tester);
        expect(find.byKey(RestScene.dreamKey), findsOneWidget);
        expect(find.textContaining('IS DREAMING OF'), findsOneWidget);
        expect(find.byKey(RestScene.seeYouKey), findsNothing);
        // The title alone (no done ticks, no countdown in the header).
        expect(find.text('All done for today'), findsOneWidget);
        expect(find.text('Daily Test 4/5'), findsNothing);
        // Today's free ticket, used: USED and the time to the next one
        // (clock 9:00 → 15:00), and the two lines beside it.
        final used = find.byKey(RestScene.usedTicketKey);
        expect(tester.getSize(used), const Size(150, 53));
        expect(find.descendant(of: used, matching: find.text('USED')),
            findsOneWidget);
        expect(find.descendant(of: used, matching: find.text('15:00')),
            findsOneWidget);
        expect(find.descendant(of: used, matching: find.text('NEXT')),
            findsOneWidget);
        expect(
            find.textContaining('Today’s free ticket is used.',
                findRichText: true),
            findsOneWidget);
        expect(find.textContaining('Not sleepy yet?', findRichText: true),
            findsOneWidget);
        // The Premium card: the tag, the allowance, the deck.
        final card = find.byKey(RestScene.premiumCardKey);
        expect(find.descendant(of: card, matching: find.text('PREMIUM')),
            findsOneWidget);
        expect(
            find.descendant(of: card, matching: find.text('5 practices a day')),
            findsOneWidget);
        final deck = find.byKey(RestScene.deckKey);
        for (var i = 0; i < TicketDeck.tickets; i++) {
          expect(find.byKey(TicketDeck.ticketKey(i)), findsOneWidget);
        }
        final spot = humanizeSlug(_weakSpot().errorType);
        for (final text in [
          'NEXT UP',
          spot,
          'AI feedback on every answer',
          '+4',
          'TODAY',
        ]) {
          expect(find.descendant(of: deck, matching: find.text(text)),
              findsOneWidget,
              reason: text);
        }
        expect(
            tester.getSemantics(deck).label, 'Premium: 4 more practices today');
        // The back tickets 7 pt apart diagonally once settled.
        final front = tester.getTopLeft(find.byKey(TicketDeck.ticketKey(0)));
        for (var i = 1; i < TicketDeck.tickets; i++) {
          expect(tester.getTopLeft(find.byKey(TicketDeck.ticketKey(i))) - front,
              Offset(7.0 * i, 7.0 * i));
        }
        final hero = Avatar.values.first.name(en);
        expect(find.text('Wake $hero up · 7 days free'), findsOneWidget);
        expect(tester.getSize(find.byKey(RestScene.wakeKey)).height,
            greaterThanOrEqualTo(50));
        expect(find.byType(PremiumScreen), findsNothing);
        expect(sink.named('paywall_viewed'), isEmpty);
      });

      testWidgets('no weak spot: no dream bubble, the deck names the topics',
          (tester) async {
        await pumpRest(tester, weakSpot: false);
        expect(find.byKey(RestScene.dreamKey), findsNothing);
        expect(
            find.descendant(
                of: find.byKey(RestScene.deckKey),
                matching:
                    find.text('Any of ${practiceTopics().length} topics')),
            findsOneWidget);
      });

      testWidgets(
          'Wake → the companion wakes ("I\'m awake!"), then V13r rises with '
          'source rest_scene; X → V13b once → back to the scene, asleep',
          (tester) async {
        PremiumScreen.resetExitReminder();
        final (sink, _) = await pumpRest(tester);
        await tester.ensureVisible(find.byKey(RestScene.wakeKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(RestScene.wakeKey));
        await tester.pump();
        // v13: the deck gathers into the front ticket first (150 ms) …
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(RestScene.awakeBubbleKey), findsNothing);
        await tester.pump(const Duration(milliseconds: 60));
        final front = tester.getTopLeft(find.byKey(TicketDeck.ticketKey(0)));
        for (var i = 1; i < TicketDeck.tickets; i++) {
          expect(tester.getTopLeft(find.byKey(TicketDeck.ticketKey(i))), front);
        }
        // … then the companion wakes, then the paywall rises.
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(RestScene.awakeBubbleKey), findsOneWidget);
        expect(find.byType(PremiumScreen), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byType(PremiumScreen), findsOneWidget);
        expect(find.byKey(PremiumScreen.restTopKey), findsOneWidget);
        expect(find.byKey(PremiumScreen.restSpotKey), findsOneWidget);
        final viewed = sink.named('paywall_viewed');
        expect(viewed, hasLength(1));
        expect(viewed.single.parameters!['source'],
            AnalyticsService.paywallSourceRestScene);
        expect(AnalyticsService.paywallSourceRestScene, 'rest_scene');

        await tester.tap(find.byKey(PremiumScreen.closeKey));
        await tester.pumpAndSettle();
        expect(find.byKey(PremiumScreen.exitContinueFreeKey), findsOneWidget);
        await tester.tap(find.byKey(PremiumScreen.exitContinueFreeKey));
        await tester.pumpAndSettle();
        expect(find.byType(PremiumScreen), findsNothing);
        expect(find.byKey(HomeScreen.restSceneKey), findsOneWidget);
        expect(find.byKey(RestScene.awakeBubbleKey), findsNothing);
        expect(find.byKey(RestScene.dreamKey), findsOneWidget);
        // The deck spreads again.
        expect(
            tester.getTopLeft(find.byKey(TicketDeck.ticketKey(3))) -
                tester.getTopLeft(find.byKey(TicketDeck.ticketKey(0))),
            const Offset(21, 21));
      });

      testWidgets(
          'v13: V13r from Wake stays on a swipe, a drag down and a system '
          'back; X → V13b → back to the scene', (tester) async {
        PremiumScreen.resetExitReminder();
        await pumpRest(tester);
        await tester.ensureVisible(find.byKey(RestScene.wakeKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(RestScene.wakeKey));
        await tester.pumpAndSettle();
        expect(find.byKey(PremiumScreen.restTopKey), findsOneWidget);
        await expectPaywallHolds(tester);
        await closeWithX(tester, reminder: true);
        expect(find.byKey(HomeScreen.restSceneKey), findsOneWidget);
      }, variant: iOSOnly);

      testWidgets(
          'trial started → PW05r ("<Hero> is ready", "Practise <weak spot>") '
          '→ straight into that weak spot\'s practice, not Home',
          (tester) async {
        final (_, subs) = await pumpRest(tester);
        await tester.ensureVisible(find.byKey(RestScene.wakeKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(RestScene.wakeKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(PremiumScreen.ctaKey));
        await tester.pumpAndSettle();
        expect(subs.purchases, 1);
        // The paywall's hero is the stored profile's (none in this fake).
        expect(find.textContaining('is ready. Let’s go!'), findsOneWidget);
        expect(find.text('4 more sessions today, 5 every day'), findsOneWidget);
        final spot = humanizeSlug(_weakSpot().errorType);
        expect(find.text('Practise $spot'), findsOneWidget);
        await tester.tap(find.byKey(PremiumOnScreen.continueKey));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(PremiumScreen), findsNothing);
        expect(find.byKey(HomeScreen.restPractiseKey), findsOneWidget);
        expect(
            tester
                .widget<WeakSpotDetailScreen>(
                    find.byKey(HomeScreen.restPractiseKey))
                .startPractice,
            isTrue);
      });

      testWidgets(
          'no weak spot: PW05r says "Pick a topic" and opens the topics',
          (tester) async {
        await pumpRest(tester, weakSpot: false);
        await tester.ensureVisible(find.byKey(RestScene.wakeKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(RestScene.wakeKey));
        await tester.pumpAndSettle();
        expect(find.byKey(PremiumScreen.restSpotKey), findsNothing);
        await tester.tap(find.byKey(PremiumScreen.ctaKey));
        await tester.pumpAndSettle();
        expect(find.text('Pick a topic'), findsOneWidget);
        await tester.tap(find.byKey(PremiumOnScreen.continueKey));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(TopicPracticeScreen), findsOneWidget);
      });
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
    // Wide enough that the test font's square glyphs fit at full size.
    await pumpHome(tester, size: const Size(700, 844));
    // Fix round 2 (V14 / V15): one line, the name bold inside it.
    final line = tester.widget<Text>(find.byKey(HomeGreeting.lineKey));
    final root = line.textSpan! as TextSpan;
    final greeting = root.style!;
    final name = root.children!
        .whereType<TextSpan>()
        .firstWhere((t) => t.text == 'Ada')
        .style!;
    TextStyle style(Finder f) => tester.widget<Text>(f).style!;
    final brand = style(find.text('GrammarLens'));
    final section = style(find.text('Topic practice'));
    expect(root.toPlainText(), 'Good morning, Ada');
    expect(greeting.fontSize,
        closeTo(section.fontSize! * HomeScreen.greetingScale, .01));
    expect(greeting.fontSize, greaterThan(section.fontSize!));
    expect(name.fontSize, greeting.fontSize);
    expect(name.fontWeight!.value, greaterThan(greeting.fontWeight!.value));
    expect(greeting.fontSize, lessThan(brand.fontSize!));
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
        // Fix round 2: one line (scaled down, never wrapped); the whole
        // name is read out (the fit itself, in the real font:
        // fix_round2_greeting_test).
        final line = find.byKey(HomeGreeting.lineKey);
        expect(tester.getRect(line).right, lessThanOrEqualTo(width));
        final size =
            (tester.widget<Text>(line).textSpan! as TextSpan).style!.fontSize!;
        expect(tester.getSize(line).height, lessThan(size * 1.6));
        // What VoiceOver reads (HomeGreeting's one label): the whole name.
        expect(tester.widget<HomeGreeting>(find.byType(HomeGreeting)).text,
            'Good morning, Maximiliana Alexandra');

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

  // Fix round 2, item 12 (V15): when Home first opens, the pawn and its
  // next step are above the floating nav bar, on the owner's 6.7" phone and
  // the 6.3" / 6.9" classes, early and late in the month. Measured in the
  // app's font (loaded here, last in this file, so the tests above keep
  // the test font's metrics).
  for (final size in [
    const Size(428, 926),
    const Size(402, 874),
    const Size(440, 956),
  ]) {
    for (final steps in [0, 3, 15, 28]) {
      testWidgets(
          'V15 first view at ${size.width.toInt()} × ${size.height.toInt()}, '
          'step $steps: the pawn and its next step clear the nav bar',
          (tester) async {
        final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
        await (FontLoader('NunitoSans')..addFont(bytes)).load();
        tester.view.physicalSize = size * 3.0;
        tester.view.devicePixelRatio = 3.0;
        tester.view.padding =
            const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: FloatingNavShell(
            selectedIndex: 0,
            onTabChange: (_) {},
            tabs: const [
              NavShellTab(
                  icon: Icons.landscape,
                  activeIcon: Icons.landscape,
                  label: 'Climb'),
              NavShellTab(
                  icon: Icons.history,
                  activeIcon: Icons.history,
                  label: 'Review'),
              NavShellTab(
                  icon: Icons.person,
                  activeIcon: Icons.person,
                  label: 'Profile'),
            ],
            body: HomeScreen(
              active: true,
              userName: 'Maximiliana Johanson',
              claudeService: ClaudeService(),
              storageService: _FakeStorageService()..steps = steps,
              analyticsService: AnalyticsService(),
              subscriptionService: _FakeSubscriptionService(),
              clock: () => DateTime(2026, 11, 4, 15, 0),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final bar = tester.getRect(find.byKey(FloatingNavShell.barKey));
        final pawn = tester.getRect(find
            .descendant(
                of: find.byType(MonthlyMountain),
                matching: find.byType(AvatarTile))
            .first);
        // INTEGRATE 3b: 16 pt of air on every size (fix round 2 allowed
        // 0 at 6.3" on day 0; the window is fitted now).
        const margin = MonthlyMountain.firstViewClearance;
        expect(pawn.bottom, lessThanOrEqualTo(bar.top - margin),
            reason: 'pawn $pawn, bar $bar');
        final next = find.byKey(MonthlyMountain.nextStepKey);
        if (next.evaluate().isNotEmpty) {
          expect(
              tester.getRect(next).bottom, lessThanOrEqualTo(bar.top - margin));
        }
      });
    }
  }

  // INTEGRATE: Home inside the real floating nav shell, at a phone's size
  // with its own safe-area insets, in the app's font.
  Future<void> pumpShell(WidgetTester tester,
      {required Size size,
      required double top,
      required double bottom,
      required _FakeStorageService storage,
      _FakeSubscriptionService? subs,
      ReminderController? reminders,
      AppTextSize textSize = AppTextSize.medium,
      Locale? locale,
      Brightness brightness = Brightness.light}) async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
    try {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    } catch (_) {
      // Without the icon font the icons draw as boxes; same layout.
    }
    tester.view.physicalSize = size * 3.0;
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
        key: _shellBoundary,
        child: MaterialApp(
          theme: buildAppTheme(brightness, textSize: textSize),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: FloatingNavShell(
            selectedIndex: 0,
            onTabChange: (_) {},
            tabs: const [
              NavShellTab(
                  icon: Icons.landscape,
                  activeIcon: Icons.landscape,
                  label: 'Climb'),
              NavShellTab(
                  icon: Icons.history,
                  activeIcon: Icons.history,
                  label: 'Review'),
              NavShellTab(
                  icon: Icons.person,
                  activeIcon: Icons.person,
                  label: 'Profile'),
            ],
            body: HomeScreen(
              active: true,
              userName: 'Ada',
              claudeService: ClaudeService(),
              storageService: storage,
              analyticsService: AnalyticsService(),
              subscriptionService: subs ?? _FakeSubscriptionService(),
              reminders: reminders,
              clock: () => DateTime(2026, 11, 4, 15, 0),
            ),
          ),
        )));
    await tester.pumpAndSettle();
  }

  // The phones INTEGRATE 3a / 3b name, with their safe-area insets: 6.1"
  // (390 × 844), 6.1" Pro class (393 × 852), 6.3" (402 × 874), the
  // iPhone SE (375 × 667), and the 6.7" / 6.9" classes.
  const phones = [
    (Size(390, 844), 47.0, 34.0),
    (Size(393, 852), 59.0, 34.0),
    (Size(402, 874), 62.0, 34.0),
    (Size(375, 667), 20.0, 0.0),
    (Size(428, 926), 47.0, 34.0),
    (Size(440, 956), 62.0, 34.0),
  ];

  group('INTEGRATE 3b: the pawn and its next step on first view', () {
    // November 2026 has 30 days: day 0, mid-month, the last step waiting
    // (29 done) and the summit (30).
    for (final (size, top, bottom) in phones) {
      final se = size.height < 700;
      for (final steps in [0, 15, 29, 30]) {
        testWidgets(
            '${size.width.toInt()} × ${size.height.toInt()}, step $steps: '
            '${se ? 'not covered by' : '16 pt above'} the nav bar',
            (tester) async {
          await pumpShell(tester,
              size: size,
              top: top,
              bottom: bottom,
              storage: _FakeStorageService()..steps = steps);
          final bar = tester.getRect(find.byKey(FloatingNavShell.barKey));
          final pawn = tester.getRect(find
              .descendant(
                  of: find.byType(MonthlyMountain),
                  matching: find.byType(AvatarTile))
              .first);
          final margin = se ? 0.0 : MonthlyMountain.firstViewClearance;
          expect(pawn.bottom, lessThanOrEqualTo(bar.top - margin),
              reason: 'pawn $pawn, bar $bar');
          expect(pawn.top, greaterThan(0));
          final next = find.byKey(MonthlyMountain.nextStepKey);
          if (steps < 30) {
            expect(next, findsOneWidget);
            expect(tester.getRect(next).bottom,
                lessThanOrEqualTo(bar.top - margin));
          }
          final window = tester.getSize(find.byType(MonthlyMountain)).height;
          // 6.7" and 6.9" keep the full window; smaller phones get a
          // shorter one, never below the minimum.
          if (size.height >= 900) {
            expect(window, ClimbCamera.fullWindowHeight);
          } else {
            expect(window, lessThan(ClimbCamera.fullWindowHeight));
            expect(window, greaterThanOrEqualTo(ClimbCamera.minWindowHeight));
          }
          // The bubble never covers the pawn; on the SE's short window it
          // is left out.
          final bubble = find.byType(SpeechBubble);
          if (se) {
            expect(bubble, findsNothing);
          } else if (steps < 25) {
            expect(tester.getRect(bubble).bottom, lessThan(pawn.top));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a screen shown alone (no nav bar) keeps the full window',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService()..steps = 3);
      expect(tester.getSize(find.byType(MonthlyMountain)).height,
          ClimbCamera.fullWindowHeight);
    });
  });

  group('INTEGRATE 3a: V24f with "Remind me tomorrow"', () {
    _FakeStorageService restDay({bool asked = true}) => _FakeStorageService()
      ..steps = 3
      ..freeUsed = 1
      ..weakSpots = [_weakSpot()]
      ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5)
      ..reminderSettings = ReminderSettings(
          ask: asked ? ReminderAsk.declined : ReminderAsk.notAsked);

    ReminderController remindersFor(_FakeStorageService storage) =>
        ReminderController(
            storage: storage,
            bridge: FakeNativeBridge()
              ..permission = NotificationPermission.notDetermined);

    // Fix round 5, items 1 and 2 (SPEC V24f v13 "Panel", V24 v13, §1.27,
    // §1.30): the scene full-bleed from the top, the night panel attached
    // under it; the panel fits its content and ends just above the nav bar
    // (the reminder row 8 pt above it: no empty band), the scene fills the
    // rest, the art never scaled (the sheet never starts below its lower
    // edge), the camp whole at least 12 pt above the panel; no scroll
    // extent at 390 × 844 and larger at the default and the next text
    // size; the SE and the largest text size may scroll, the row
    // reachable. "Default" is the app's Medium, "next" its Large,
    // "largest" its Large with the system's largest standard size
    // (xxxLarge, × 1.35) on top (F4-2). The five sizes are the phones from
    // 390 × 844 up; the SE is checked too.
    const textSizes = [
      ('default', AppTextSize.medium, 1.0),
      ('next', AppTextSize.large, 1.0),
      ('largest', AppTextSize.large, 1.35),
    ];
    for (final premium in [false, true]) {
      for (final (label, textSize, system) in textSizes) {
        for (final (size, top, bottom) in phones) {
          testWidgets(
              'v13 ${premium ? 'V24' : 'V24f'} ${size.width.toInt()} × '
              '${size.height.toInt()}, $label text: the panel ends just '
              'above the bar, the scene fills the rest', (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = system;
            addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue);
            final storage = restDay()
              ..sessions = premium ? StorageService.dailySessionLimit : 0;
            final reminders = remindersFor(storage);
            addTearDown(reminders.dispose);
            Future<void> pump(Brightness brightness) => pumpShell(tester,
                size: size,
                top: top,
                bottom: bottom,
                storage: storage,
                subs: premium
                    ? _FakeSubscriptionService(hasAccess: true)
                    : _FakeSubscriptionService(offering: _restOffering()),
                reminders: reminders,
                textSize: textSize,
                brightness: brightness);
            await pump(Brightness.light);
            expect(tester.takeException(), isNull);
            _expectRestLayout(tester,
                size: size,
                top: top,
                premium: premium,
                oneScreen: size.height >= 800 && label != 'largest',
                record: '${premium ? 'V24' : 'V24f'} | ${size.width.toInt()} × '
                    '${size.height.toInt()} | $label');
            if (label != 'largest') {
              final name = '${premium ? 'V24' : 'V24f'}-${size.width.toInt()}x'
                  '${size.height.toInt()}-$label';
              await _captureShell(tester, name, round: 5);
              if (Platform.environment['FIX5_CAPTURE'] == '1') {
                await pump(Brightness.dark);
                await _captureShell(tester, name, dark: true, round: 5);
                await pump(Brightness.light);
              }
            }
            // Reachable: scrolled to the end, the row above the bar and
            // its switch hit-testable (the position read again: the
            // captures pump the page anew).
            final end = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            end.jumpTo(end.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(
                tester.getRect(find.byType(RestReminderRow)).bottom,
                lessThanOrEqualTo(
                    tester.getRect(find.byKey(FloatingNavShell.barKey)).top));
            expect(find.byKey(RestReminderRow.switchKey).hitTestable(),
                findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    // Late in the month the camp stands high on the mountain, where the
    // art's top edge would come into view: the art starts lower and its
    // sky is mirrored above it; the camp keeps its place, whole, and the
    // dream bubble stays under the status bar's edge. Early in the month
    // (step 0, 1) on the tallest phones the camp and the art move down
    // together so the art still reaches the panel.
    for (final (steps, size, top, bottom) in [
      (20, const Size(390, 844), 47.0, 34.0),
      (26, const Size(390, 844), 47.0, 34.0),
      (30, const Size(390, 844), 47.0, 34.0),
      (0, const Size(440, 956), 62.0, 34.0),
      (1, const Size(428, 926), 47.0, 34.0),
    ]) {
      for (final premium in [false, true]) {
        testWidgets(
            'v13 ${premium ? 'V24' : 'V24f'} step $steps, '
            '${size.width.toInt()} × ${size.height.toInt()}: the camp '
            'whole, the art unscaled, no empty band', (tester) async {
          final storage = restDay()
            ..steps = steps
            ..sessions = premium ? StorageService.dailySessionLimit : 0;
          final reminders = remindersFor(storage);
          addTearDown(reminders.dispose);
          await pumpShell(tester,
              size: size,
              top: top,
              bottom: bottom,
              storage: storage,
              subs: premium
                  ? _FakeSubscriptionService(hasAccess: true)
                  : _FakeSubscriptionService(offering: _restOffering()),
              reminders: reminders);
          expect(tester.takeException(), isNull);
          _expectRestLayout(tester,
              size: size,
              top: top,
              premium: premium,
              oneScreen: true,
              record: '${premium ? 'V24' : 'V24f'} step $steps | '
                  '${size.width.toInt()} × ${size.height.toInt()} | default');
          if (steps >= 20) {
            final companion = tester.getRect(find
                .descendant(
                    of: find.byKey(RestScene.sceneKey),
                    matching: find.byType(CompanionView))
                .first);
            // The board's place: the companion's top 127 pt (V24f) or 207
            // pt (V24) under the safe area.
            expect(
                companion.top,
                closeTo(
                    top +
                        (premium
                            ? RestScene.bandAboveCampPremium
                            : RestScene.bandAboveCamp),
                    1));
          }
          await _captureShell(
              tester,
              '${premium ? 'V24' : 'V24f'}-${size.width.toInt()}x'
              '${size.height.toInt()}-step$steps',
              round: 5);
        });
      }
    }

    // v13 in Turkish on the owner's phone (428 × 926, the app's Large
    // text): one screen, the row just above the bar.
    for (final premium in [false, true]) {
      testWidgets(
          'v13 ${premium ? 'V24' : 'V24f'} in Turkish, 428 × 926, next text: '
          'one screen', (tester) async {
        final storage = restDay()
          ..sessions = premium ? StorageService.dailySessionLimit : 0;
        final reminders = remindersFor(storage);
        addTearDown(reminders.dispose);
        Future<void> pump(Brightness brightness) => pumpShell(tester,
            size: const Size(428, 926),
            top: 47,
            bottom: 34,
            storage: storage,
            subs: premium
                ? _FakeSubscriptionService(hasAccess: true)
                : _FakeSubscriptionService(offering: _restOffering()),
            reminders: reminders,
            textSize: AppTextSize.large,
            locale: const Locale('tr'),
            brightness: brightness);
        await pump(Brightness.light);
        expect(tester.takeException(), isNull);
        _expectRestLayout(tester,
            size: const Size(428, 926),
            top: 47,
            premium: premium,
            oneScreen: true,
            record: '${premium ? 'V24' : 'V24f'} (tr) | 428 × 926 | next');
        if (!premium) {
          final deck = find.byKey(RestScene.deckKey);
          expect(find.descendant(of: deck, matching: find.text('SIRADAKİ')),
              findsOneWidget);
          expect(find.descendant(of: deck, matching: find.text('BUGÜN')),
              findsOneWidget);
        } else {
          expect(find.text('SONRAKİ GÜNLÜK TEST · 4. ADIM'), findsOneWidget);
        }
        final name = '${premium ? 'V24' : 'V24f'}-428x926-next-tr';
        await _captureShell(tester, name, round: 5);
        if (Platform.environment['FIX5_CAPTURE'] == '1') {
          await pump(Brightness.dark);
          await _captureShell(tester, name, dark: true, round: 5);
        }
      });
    }

    testWidgets(
        'N01 opens over whichever rest scene comes first: V24 (Premium)',
        (tester) async {
      final storage = _FakeStorageService()
        ..steps = 3
        ..sessions = StorageService.dailySessionLimit
        ..todaysDailyTest = _completedDailyTestSet(correct: 4, total: 5)
        ..reminderSettings = const ReminderSettings();
      final reminders = remindersFor(storage);
      addTearDown(reminders.dispose);
      await pumpHome(tester,
          storageService: storage,
          subscriptionService: _FakeSubscriptionService(hasAccess: true),
          reminders: reminders);
      expect(find.byKey(HomeScreen.restSceneKey), findsOneWidget);
      expect(find.byKey(RestScene.premiumCardKey), findsNothing);
      expect(find.byType(ReminderSoftAsk), findsOneWidget);
      await tester.tap(find.byKey(ReminderSoftAsk.notNowKey));
      await tester.pumpAndSettle();
      expect(storage.reminderSettings!.ask, ReminderAsk.declined);
      expect(find.byKey(RestReminderRow.switchKey), findsOneWidget);
    });

    testWidgets('N01 opens over whichever rest scene comes first: V24f (free)',
        (tester) async {
      final storage = restDay(asked: false);
      final reminders = remindersFor(storage);
      addTearDown(reminders.dispose);
      await pumpHome(tester,
          storageService: storage,
          subscriptionService:
              _FakeSubscriptionService(offering: _restOffering()),
          reminders: reminders);
      expect(find.byKey(RestScene.premiumCardKey), findsOneWidget);
      expect(find.byType(ReminderSoftAsk), findsOneWidget);
      // The question opened by itself; the paywall did not.
      expect(find.byType(PremiumScreen), findsNothing);
    });
  });
}

/// V24f → V13r: an annual plan with a 7-day free trial (the paywall's
/// preselected plan) and a monthly one.
Offering _restOffering() {
  const context = PresentedOfferingContext('default', null, null);
  const annual = Package(
    '\$rc_annual',
    PackageType.annual,
    StoreProduct(
        'grammarlens_premium_annual', '', 'Annual', 49.99, '\$49.99', 'USD',
        introductoryPrice:
            IntroductoryPrice(0, '\$0.00', 'P1W', 1, PeriodUnit.week, 1),
        subscriptionPeriod: 'P1Y'),
    context,
  );
  const monthly = Package(
    '\$rc_monthly',
    PackageType.monthly,
    StoreProduct(
        'grammarlens_premium_monthly', '', 'Monthly', 5.99, '\$5.99', 'USD',
        subscriptionPeriod: 'P1M'),
    context,
  );
  return const Offering('default', '', {}, [monthly, annual],
      monthly: monthly, annual: annual);
}

final _shellBoundary = GlobalKey();

/// Fix round 3: with `FIX3_CAPTURE=1`, writes what [pumpShell] shows to
/// `build/fix3-captures/[dark/]<name>.png` (the sizes no simulator has).
/// Fix round 4, item 1: the measured numbers, one table row per render
/// (`FIX4_CAPTURE=1`: `build/fix4-captures/v24-numbers.md`).
void _recordV24(String row, {int round = 4}) {
  if (Platform.environment['FIX${round}_CAPTURE'] != '1') return;
  final out = File('build/fix$round-captures/v24-numbers.md');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('| $row |\n', mode: FileMode.append);
}

/// Fix round 5 (SPEC V24f v13 "Panel", V24 v13): the rest scene's layout
/// on [size]: full-bleed scene, the panel attached under it, the camp
/// whole at least 12 pt above the panel and the fire at the companion's
/// front right on its ground, the art never scaled (the scene no taller
/// than the art below its top), the dream bubble under the status bar;
/// with [oneScreen], no scroll extent and the reminder row 8 pt above the
/// nav bar (the panel ends just above the bar: no empty band).
void _expectRestLayout(WidgetTester tester,
    {required Size size,
    required double top,
    required bool premium,
    required bool oneScreen,
    required String record}) {
  final scene = tester.getRect(find.byKey(RestScene.sceneKey));
  final sheet = tester.getRect(find.byKey(RestScene.sheetKey));
  final bar = tester.getRect(find.byKey(FloatingNavShell.barKey));
  expect(scene.top, 0);
  expect(scene.left, 0);
  expect(scene.width, size.width);
  expect(sheet.left, 0);
  expect(sheet.width, size.width);
  expect(sheet.top, closeTo(scene.bottom - RestScene.sheetRadius, .5));
  final companion = tester.getRect(find
      .descendant(
          of: find.byKey(RestScene.sceneKey),
          matching: find.byType(CompanionView))
      .first);
  final fire = tester.getRect(find.descendant(
      of: find.byKey(RestScene.sceneKey), matching: find.byType(Campfire)));
  final tent = tester.getRect(find.descendant(
      of: find.byKey(RestScene.sceneKey),
      matching: find.byWidgetPredicate((w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('tent'))));
  final campTop = [tent.top, companion.top, fire.top].reduce(math.min);
  final campBottom =
      [tent.bottom, companion.bottom, fire.bottom].reduce(math.max);
  expect(campTop, greaterThanOrEqualTo(top), reason: 'camp top');
  expect(campBottom, lessThanOrEqualTo(sheet.top - 12 + .5),
      reason: 'camp $campBottom, sheet ${sheet.top}');
  expect(fire.left, greaterThanOrEqualTo(0));
  expect(fire.right, lessThanOrEqualTo(size.width));
  final s = companion.height;
  expect(fire.left, greaterThan(companion.center.dx));
  expect(
      fire.bottom -
          Campfire.logsHeight /
              Campfire.boxHeight *
              fire.height *
              (1 - Campfire.pileBase),
      closeTo(companion.top + RestScene.feetShare * s, .5));
  // The art at the boards' scale, never scaled up: the mountain's box is
  // no taller than the art.
  final art = tester.getRect(find.descendant(
      of: find.byKey(RestScene.sceneKey),
      matching: find.byType(MountainScene)));
  final artHeight = size.width * RestScene.artWidthShare / climbImageAspect;
  expect(art.height, lessThanOrEqualTo(artHeight + .5), reason: 'art scaled');
  expect(art.bottom, closeTo(scene.bottom, .5));
  if (!premium) {
    expect(tester.getRect(find.byKey(RestScene.dreamKey)).top,
        greaterThanOrEqualTo(top));
    expect(find.byKey(RestScene.usedTicketKey), findsOneWidget);
    expect(find.byKey(RestScene.deckKey), findsOneWidget);
  } else {
    expect(find.byKey(RestScene.doneTilesKey), findsOneWidget);
    expect(find.byKey(RestScene.nextTestKey), findsOneWidget);
  }
  final row = tester.getRect(find.byType(RestReminderRow));
  final extent = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .maxScrollExtent;
  double? wakeClear;
  if (!premium) {
    wakeClear = bar.top - tester.getRect(find.byKey(RestScene.wakeKey)).bottom;
  }
  final rowClear = bar.top - row.bottom;
  if (oneScreen) {
    expect(extent, 0, reason: 'scroll extent');
    expect(rowClear, closeTo(RestScene.anchorClearance, .5),
        reason: 'row ${rowClear}pt above the bar');
    if (wakeClear != null) expect(wakeClear, greaterThan(rowClear));
  }
  _recordV24(
      '$record | ${sheet.top.toStringAsFixed(1)} | '
      '${(sheet.top - campBottom).toStringAsFixed(1)} | '
      '${rowClear.toStringAsFixed(1)} | '
      '${wakeClear?.toStringAsFixed(1) ?? '–'} | '
      '${extent.toStringAsFixed(1)}',
      round: 5);
}

Future<void> _captureShell(WidgetTester tester, String name,
    {bool dark = false, int round = 3}) async {
  if (Platform.environment['FIX${round}_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final render = _shellBoundary.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out =
        File('build/fix$round-captures/${dark ? 'dark/' : ''}$name.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
