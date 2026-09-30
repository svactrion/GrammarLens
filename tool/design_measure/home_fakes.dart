// Home with fixed data, for measuring and rendering. Measuring code only.
import 'package:flutter/material.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';

/// A free user.
class DesignSubs extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

/// [steps] climbed this month with [correct] and [wrong] answers; no Daily
/// Test done today; no weak spots.
class DesignStorage extends StorageService {
  final int steps, correct, wrong;
  DesignStorage({required this.steps, this.correct = 0, this.wrong = 0});

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: steps, correct: correct, wrong: wrong, skipped: 0);
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

/// The real Home inside the real navigation shell. Text size goes only
/// through `buildAppTheme(textSize:)`, as in the app.
Widget designHome({
  required DateTime clock,
  required StorageService storage,
  AppTextSize textSize = AppTextSize.medium,
  Brightness brightness = Brightness.light,
  String userName = 'Ada',
}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness, textSize: textSize),
      home: FloatingNavShell(
        body: HomeScreen(
          active: true,
          userName: userName,
          avatar: Avatar.values.first,
          claudeService: ClaudeService(),
          storageService: storage,
          analyticsService: AnalyticsService(),
          subscriptionService: DesignSubs(),
          clock: () => clock,
        ),
        tabs: const [
          NavShellTab(
              icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
          NavShellTab(
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              label: 'Review'),
          NavShellTab(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile'),
        ],
        selectedIndex: 0,
        onTabChange: (_) {},
      ),
    );
