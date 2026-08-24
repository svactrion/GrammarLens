import 'package:flutter/material.dart';

import '../models/practice_length.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/error_banner.dart';
import 'practice_length_picker.dart';
import 'practice_screen.dart';

/// Shows the "how many questions" length picker, then generates a fresh
/// practice set for [topic] and pushes [PracticeScreen].
///
/// Shared by TopicPracticeScreen and ReviewScreen (weak-spot detail's
/// "Practice this")
/// so the pick-length → generate → navigate → handle-errors sequence lives
/// in exactly one place and can't drift apart between entry points.
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
  required void Function(bool generating) setGenerating,
  required String errorPrefix,
  VoidCallback? onReturned,
}) async {
  // Checked first, before the length picker even opens — no point asking
  // "how many questions" for a session that's about to be refused (PRD v2
  // §10.1's daily cost cap). Falls back to "allow" on a storage read
  // failure rather than blocking practice entirely over it, same as the
  // rest of the app treats local-storage hiccups (see app.dart's profile
  // and theme loads).
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

  final lastLength = await storageService.getPracticeLength();
  if (!context.mounted) return;
  final length = await showPracticeLengthPicker(
    context: context,
    initial: lastLength,
  );
  if (length == null) return;
  await storageService.setPracticeLength(length);

  setGenerating(true);
  try {
    final practiceSet = await claudeService.generatePracticeSet(
      topic,
      count: length.questionCount,
    );
    // Counted once generation actually succeeds — the LLM call this cap
    // exists to bound has happened, so it counts even if the user later
    // backs out of the session itself without answering. Best-effort: a
    // failed usage-count write shouldn't block a session the generation
    // cost has already been paid for.
    try {
      await storageService.recordSessionStarted();
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
    showErrorSnackBar(context, '$errorPrefix: $e');
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

