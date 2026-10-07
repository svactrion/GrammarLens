// The month card's test harness (Batch 6): an in-memory storage and the
// real Home in the real tab shell, on 1 November 2026.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'recording_analytics_sink.dart';

/// A free user.
class _Subs extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

/// The month card's storage, in memory: flags, last month's steps and its
/// frozen result, a returning user.
class CardStorage extends StorageService {
  final Set<String> flags = {};
  bool usedBefore = true;
  int previousSteps = 24;
  MonthlyMedalResult? frozen;

  CardStorage({int score = 228, int steps = 24}) {
    previousSteps = steps;
    frozen = _result(score, steps);
  }

  static MonthlyMedalResult _result(int score, int steps) => MonthlyMedalResult(
        year: 2026,
        month: 10,
        score: score,
        maxScore: MonthlyMedalRules.maxScore(2026, 10),
        activeDays: steps,
        correct: 0,
        wrong: 0,
        skipped: 0,
        tier: MonthlyMedalRules.tierFor(year: 2026, month: 10, score: score),
        ruleVersion: 1,
        finalizedAt: DateTime(2026, 11, 1),
      );

  @override
  Future<bool> hasOneTimeFlag(String key) async => flags.contains(key);
  @override
  Future<bool> claimOneTimeFlag(String key) async => flags.add(key);
  @override
  Future<bool> hasClimbHistoryBefore(int year, int month) async => usedBefore;
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (
        steps: year == 2026 && month == 10 ? previousSteps : 0,
        correct: 0,
        wrong: 0,
        skipped: 0
      );
  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async =>
      [if (frozen != null) frozen!];
  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => null;
  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => null;
  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      const [];
}

final sheetFinder = find.byType(MonthCardSheet);
final mountainFinder = find.byType(MonthlyMountain);

/// The real Home in the real tab shell, on 1 November 2026.
Future<void> pumpHome(
  WidgetTester tester,
  StorageService storage, {
  // Batch 5 (N30): the centred medal makes the fullest summary card taller;
  // in the test font (wider and taller than the app's) it scrolls at
  // 375 × 812, and a drag on a scrolling sheet scrolls instead of closing
  // it. 430 × 932 keeps the default card unscrolled; screen-specific tests
  // pass their own size.
  Size screen = const Size(430, 932),
  AppTextSize textSize = AppTextSize.medium,
  RecordingAnalyticsSink? sink,
  Key? key,
}) async {
  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    key: key,
    theme: buildAppTheme(Brightness.light, textSize: textSize),
    home: FloatingNavShell(
      body: HomeScreen(
        userName: 'Ada',
        avatar: Avatar.values.first,
        claudeService: ClaudeService(),
        storageService: storage,
        analyticsService:
            AnalyticsService(sink: sink ?? RecordingAnalyticsSink()),
        subscriptionService: _Subs(),
        clock: () => DateTime(2026, 11, 1, 9),
      ),
      tabs: const [
        NavShellTab(
            icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
        NavShellTab(
            icon: Icons.history, activeIcon: Icons.history, label: 'Review'),
      ],
      selectedIndex: 0,
      onTabChange: (_) {},
    ),
  ));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> settleZoom(WidgetTester tester) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}
