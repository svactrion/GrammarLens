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
import 'premium_screen.dart';
import 'welcome_screen.dart';

/// Welcome → Onboarding → Daily Test → Result-with-Premium-pitch, shown once
/// on first launch (PRD v2 §4, §12.3's Day-0 sequence). Every step but the
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
/// [PremiumScreen.onDone] both exist to let this flow reach the finish line
/// through plain widget swaps instead, with the sole exception of the
/// (fully reversible) excursion into a real, pushed [PremiumScreen] when
/// the user actually taps "Start free trial."
class FirstLaunchFlow extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;

  /// Called once when the flow ends. [pendingClimb] is non-null only when the
  /// Day-0 Daily Test was saved and earned a step, so the Home that replaces
  /// this flow can animate that step instead of mounting already advanced.
  final void Function(UserProfile profile, {PendingClimb? pendingClimb})
      onComplete;

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

  /// Whether the Day-0 result is safely on disk. The result screen saves in
  /// the background; until it has, the way out of the flow stays disabled so
  /// Home cannot be built (and read the ledger) ahead of the write.
  bool _resultSaved = false;
  PendingClimb? _pendingClimb;

  late final DailyTestService _dailyTestService = DailyTestService(
    claudeService: widget.claudeService,
    storageService: widget.storageService,
  );

  Future<void> _completeOnboarding(UserProfile profile) async {
    setState(() => _saving = true);
    try {
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
      // A set that was already completed (a debug onboarding reset can land
      // on one) is never saved again, so there is nothing to wait for.
      _resultSaved = set.isCompleted;
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
      _resultSaved = true;
      _pendingClimb = step > 0 ? (day: set.day, step: step) : null;
    });
  }

  /// The Day-0 flow's actual finish line — the profile was already saved
  /// in [_completeOnboarding]; this just hands it to [FirstLaunchFlow.
  /// onComplete] so app.dart swaps in the tabbed Home shell. Reached from
  /// three places, all equally valid endings (PRD v2 §12.3): abandoning
  /// Daily Test itself, tapping "Maybe later" on the result screen's
  /// pitch, or dismissing the real [PremiumScreen] (whether that's via its
  /// own "Maybe later" or after a trial actually started).
  void _finish() {
    widget.onComplete(_profile!, pendingClimb: _pendingClimb);
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
          bottomBuilder: (context) => _DayZeroPaywallCta(
            enabled: _resultSaved,
            storageService: widget.storageService,
            analyticsService: widget.analyticsService,
            onDone: _finish,
          ),
        );
    }
  }
}

/// The Day-0 result screen's ending (PRD v2 §12.3), replacing the plain
/// "back to Home" a Home-reached Daily Test leaves this slot empty for
/// (see DailyTestResultScreen's own doc comment). Deliberately light: a
/// one-line pitch plus the two ways out, not a duplicate of PremiumScreen's
/// own pitch/pricing card — that real screen is one tap away via "Start
/// free trial," this is just the invitation to go there.
class _DayZeroPaywallCta extends StatelessWidget {
  // Named to match PremiumScreen.onDone, not just "onSkip": this same
  // callback is threaded through to that screen's own onDone too, so it
  // fires whether the user taps "Maybe later" right here, taps the
  // Premium screen's own "Maybe later," or actually starts a trial and
  // taps "Continue" there — all three are "done here" moments (PRD v2
  // §12.3: whichever path, it ends on Home).
  final VoidCallback onDone;

  /// False while the result is still being saved: both ways out stay
  /// disabled, as the Home-reached result screen's own button does.
  final bool enabled;
  final StorageService storageService;
  final AnalyticsService analyticsService;

  const _DayZeroPaywallCta({
    required this.enabled,
    required this.storageService,
    required this.analyticsService,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Like the personalized feedback?',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Topic Practice gives you that same plain-language feedback '
              'on your own mistakes — and you can try it free.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: !enabled
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PremiumScreen(
                            storageService: storageService,
                            analyticsService: analyticsService,
                            analyticsSource:
                                AnalyticsService.paywallSourceOnboarding,
                            onDone: onDone,
                          ),
                        ),
                      );
                    },
              child: const Text('Start free trial'),
            ),
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: enabled ? onDone : null,
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }
}
