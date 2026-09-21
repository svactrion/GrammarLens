import 'package:flutter/material.dart';

import '../models/practice_length.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_messenger.dart';
import 'ai_consent_screen.dart';
import 'practice_length_picker.dart';
import 'practice_screen.dart';
import 'premium_screen.dart';

/// Checks entitlement, quota and the user's permission to send answers to the
/// AI provider, shows the "how many questions" length
/// picker for a full-access user (a free user skips straight to the
/// shortest length — see below), then generates a fresh practice set for
/// [topic] and pushes [PracticeScreen].
///
/// Shared by TopicPracticeScreen and ReviewScreen (weak-spot detail's
/// "Practice this") so the entitlement/quota → pick-length → generate →
/// navigate → handle-errors sequence lives in exactly one place and can't
/// drift apart between entry points — this is the single choke point every
/// real generation goes through, not a navigation guard a caller can be
/// missing (docs/build-log.md's 2026-09-05 note on why the Review path used
/// to skip it entirely).
///
/// [subscriptionService] is required, not optional: every caller checks
/// entitlement here, the same way every caller already checks
/// [StorageService.dailySessionLimit] here — there is no parameter to skip
/// this.
///
/// [setGenerating] toggles the caller's own loading flag (the caller is
/// responsible for its own `mounted` check, since a `State`'s `setState`
/// isn't reachable from here). [onReturned] runs after the pushed screen is
/// popped, e.g. to refresh a list that the practice session may have changed.
Future<void> launchPracticeSet({
  required BuildContext context,
  required Topic topic,
  required ClaudeService claudeService,
  required StorageService storageService,
  required AnalyticsService analyticsService,
  required SubscriptionService subscriptionService,
  required void Function(bool generating) setGenerating,
  required String errorPrefix,
  VoidCallback? onReturned,
}) async {
  bool hasFullAccess;
  try {
    hasFullAccess = await subscriptionService.hasFullAccess;
  } catch (_) {
    // Fails closed, same posture as SubscriptionService.hasFullAccess
    // itself — never grant the free path's shorter/rarer session to a
    // check that couldn't actually confirm anything.
    hasFullAccess = false;
  }

  // Free tier's own daily boundary (PRD v2 §12.2): Topic Practice is
  // supposed to be fully locked for a free user, and this is the one real
  // generation a free user can still reach ("Practice this" from a weak
  // spot). Checked before the global cost cap below, since it's the
  // smaller/more specific of the two — a free user who's already used
  // today's one session should see the paywall, not the generic "come
  // back tomorrow" dialog meant for the cost guardrail.
  if (!hasFullAccess) {
    int freePracticeCount;
    try {
      freePracticeCount = await storageService.getFreePracticeCountForToday();
    } catch (_) {
      freePracticeCount = 0;
    }
    if (!context.mounted) return;
    if (freePracticeCount >= StorageService.freeDailyPracticeLimit) {
      analyticsService.freePracticeQuotaExhausted();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PremiumScreen(
            storageService: storageService,
            analyticsService: analyticsService,
            analyticsSource: AnalyticsService.paywallSourcePracticeLaunch,
            subscriptionService: subscriptionService,
            sourceContext: topic.title,
          ),
        ),
      );
      return;
    }
  }

  // Checked next, before the length picker even opens — no point asking
  // "how many questions" for a session that's about to be refused (PRD v2
  // §10.1's daily cost cap). Falls back to "allow" on a storage read
  // failure rather than blocking practice entirely over it, same as the
  // rest of the app treats local-storage hiccups (see app.dart's profile
  // and theme loads). Applies to every user regardless of entitlement,
  // unchanged from before this batch.
  int sessionCount;
  try {
    sessionCount = await storageService.getSessionCountForToday();
  } catch (_) {
    sessionCount = 0;
  }
  if (!context.mounted) return;
  if (sessionCount >= StorageService.dailySessionLimit) {
    await _showDailyLimitReachedDialog(context);
    return;
  }

  // Permission to send answers to the AI provider (App Review guideline
  // 5.1.2(i)). Checked here, in the one function every real generation goes
  // through, and never passed in by the caller. It sits before the length
  // picker so a user who says no is not asked to choose a length first, and
  // before anything is generated or counted: declining records no session and
  // spends none of the free tier's practice. The answers themselves leave the
  // device later, at scoring, but this is the last point before a session
  // exists at all.
  final mayUseAi = await ensureAiConsent(
    context: context,
    storageService: storageService,
  );
  if (!mayUseAi || !context.mounted) return;

  PracticeLength length;
  if (hasFullAccess) {
    final lastLength = await storageService.getPracticeLength();
    if (!context.mounted) return;
    final picked = await showPracticeLengthPicker(
      context: context,
      initial: lastLength,
    );
    if (picked == null) return;
    length = picked;
    await storageService.setPracticeLength(length);
  } else {
    // No picker for a free user (this batch's decision): the longest set
    // is also the most expensive generation, and letting a free session
    // pick it would mean the free tier's one daily shot could cost as much
    // as a premium one. Deliberately not persisted via setPracticeLength —
    // this isn't a preference the user chose, so it shouldn't silently
    // overwrite whatever length they'd actually picked before (or will
    // once they have full access and the picker is back).
    length = PracticeLength.quick;
  }

  setGenerating(true);
  try {
    final deviceId = await storageService.getOrCreateDeviceId();
    final practiceSet = await claudeService.generatePracticeSet(
      topic,
      deviceId: deviceId,
      count: length.questionCount,
    );
    // Counted once generation actually succeeds — the LLM call this cap
    // exists to bound has happened, so it counts even if the user later
    // backs out of the session itself without answering. Best-effort: a
    // failed usage-count write shouldn't block a session the generation
    // cost has already been paid for.
    try {
      await storageService.recordSessionStarted();
      if (!hasFullAccess) {
        await storageService.recordFreePracticeStarted();
        analyticsService.freePracticeUsed();
      }
    } catch (_) {
      // Ignored — see comment above.
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(
          topic: topic,
          practiceSet: practiceSet,
          claudeService: claudeService,
          storageService: storageService,
          analyticsService: analyticsService,
        ),
      ),
    );
    onReturned?.call();
  } catch (e) {
    if (!context.mounted) return;
    AppMessenger.show('$errorPrefix: $e');
  } finally {
    setGenerating(false);
  }
}

Future<void> _showDailyLimitReachedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('That\'s all for today'),
      content: const Text(
        'You\'ve used all ${StorageService.dailySessionLimit} practice '
        'sessions for today. Come back tomorrow for more — your progress '
        'is saved.',
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ),
      ],
    ),
  );
}

