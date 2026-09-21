import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_test_completion.dart';
import '../models/daily_test_set.dart';
import '../models/pending_climb.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/daily_test_service.dart';
import '../services/storage_service.dart';
import '../utils/app_messenger.dart';
import '../utils/loading_view.dart';
import 'daily_test_result_screen.dart';
import 'daily_test_screen.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart';

/// Welcome → Onboarding → Daily Test → Result, shown once on first launch
/// (PRD v2 §4, §12.3's Day-0 sequence). Every step but the
/// last swaps a local `_step` between plain widgets rather than pushing
/// routes — no nested Navigator, no route to leave behind once the flow
/// completes and [onComplete] hands control back to the app shell, which
/// then swaps this whole widget out for the tabbed Home shell by rebuilding
/// with a non-null profile (see app.dart).
///
/// This matters for [dailyTest]/[dailyTestResult] specifically: were they
/// reached via `Navigator.push` instead, [onComplete] firing wouldn't
/// visibly do anything — the pushed route would just keep showing on top,
/// since nothing here is popping it. [DailyTestScreen.onFinished] and
/// [DailyTestResultScreen.onDone] both exist to let this flow reach the finish
/// line through plain widget swaps instead.
class FirstLaunchFlow extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;

  /// Called once when the flow ends. [pendingClimb] is non-null only when the
  /// Day-0 Daily Test was saved and earned a step, so the Home that replaces
  /// this flow can animate that step instead of mounting already advanced.
  /// [dayZeroCompleted] is true only when the user finished the test and left
  /// through the result screen's button; leaving the test unfinished is false.
  /// It is what makes Home offer the first-day paywall.
  final void Function(
    UserProfile profile, {
    PendingClimb? pendingClimb,
    bool dayZeroCompleted,
  }) onComplete;

  const FirstLaunchFlow({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.onComplete,
  });

  @override
  State<FirstLaunchFlow> createState() => _FirstLaunchFlowState();
}

enum _Step { welcome, onboarding, dailyTest, dailyTestResult }

class _FirstLaunchFlowState extends State<FirstLaunchFlow> {
  _Step _step = _Step.welcome;
  bool _saving = false;
  UserProfile? _profile;
  DailyTestSet? _dailyTestSet;
  Map<String, String> _dailyTestAnswers = const {};

  /// Set when the result screen's save lands. The screen keeps its own button
  /// disabled until then, so Home cannot be built (and read the ledger) ahead
  /// of the write.
  PendingClimb? _pendingClimb;

  late final DailyTestService _dailyTestService = DailyTestService(
    claudeService: widget.claudeService,
    storageService: widget.storageService,
  );

  Future<void> _completeOnboarding(UserProfile profile) async {
    setState(() => _saving = true);
    try {
      // The first Daily Test is the fixed set that ships with the app, written
      // before the profile so that anything that can happen once the profile
      // exists (the user closes the app mid-test and opens the test from Home)
      // finds it already on disk. A failure here is not fatal: with no set
      // stored, the Daily Test screen generates one as it always did.
      try {
        await _dailyTestService.seedDayZeroSet();
      } catch (_) {}
      await widget.storageService.saveUserProfile(profile);
      unawaited(widget.analyticsService.onboardingCompleted());
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _saving = false;
        _step = _Step.dailyTest;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppMessenger.show('Could not save your profile: $e');
    }
  }

  void _onDailyTestFinished(DailyTestSet set, Map<String, String> answers) {
    setState(() {
      _dailyTestSet = set;
      _dailyTestAnswers = answers;
      _pendingClimb = null;
      _step = _Step.dailyTestResult;
    });
  }

  /// The result screen's save finished. Records what Home has to animate; the
  /// step comes from the same completion rule the ledger write used.
  void _onResultSaved() {
    if (!mounted) return;
    final set = _dailyTestSet!;
    final step = DailyTestCompletion(
      set: set,
      answers: _dailyTestAnswers,
      completedAt: DateTime.now(),
    ).step;
    setState(() {
      _pendingClimb = step > 0 ? (day: set.day, step: step) : null;
    });
  }

  /// The Day-0 flow's actual finish line — the profile was already saved
  /// in [_completeOnboarding]; this just hands it to [FirstLaunchFlow.
  /// onComplete] so app.dart swaps in the tabbed Home shell. Reached from two
  /// places, both equally valid endings (PRD v2 §12.3): abandoning Daily Test
  /// itself, or the result screen's one button ("Start my climb" after the
  /// confetti, or "Continue"): only the second counts as [completed].
  void _finish({bool completed = false}) {
    widget.onComplete(
      _profile!,
      pendingClimb: _pendingClimb,
      dayZeroCompleted: completed,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return const LoadingView(message: 'Setting things up…');
    }
    switch (_step) {
      case _Step.welcome:
        return WelcomeScreen(
          onGetStarted: () => setState(() => _step = _Step.onboarding),
        );
      case _Step.onboarding:
        return OnboardingScreen(onComplete: _completeOnboarding);
      case _Step.dailyTest:
        return DailyTestScreen(
          dailyTestService: _dailyTestService,
          analyticsService: widget.analyticsService,
          onFinished: _onDailyTestFinished,
          // Leaving the very first Daily Test is closer to "not ready yet"
          // than "go back" — there's nothing before it to return to in
          // this flow, so treat it the same as skipping the paywall pitch
          // entirely and land straight on Home.
          onExit: _finish,
        );
      case _Step.dailyTestResult:
        return DailyTestResultScreen(
          dailyTestSet: _dailyTestSet!,
          answers: _dailyTestAnswers,
          dailyTestService: _dailyTestService,
          analyticsService: widget.analyticsService,
          isDay0: true,
          onCompletionSaved: _onResultSaved,
          onDone: () => _finish(completed: true),
        );
    }
  }
}
