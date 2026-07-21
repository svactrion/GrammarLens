import 'package:flutter/material.dart';

import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/error_banner.dart';
import 'practice_screen.dart';

/// Generates a fresh practice set for [topic] and pushes [PracticeScreen].
///
/// Shared by HomeScreen and ReviewScreen so the generate → navigate →
/// handle-errors sequence lives in exactly one place and can't drift apart
/// between the two entry points.
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
  required void Function(bool generating) setGenerating,
  required String errorPrefix,
  VoidCallback? onReturned,
}) async {
  setGenerating(true);
  try {
    final practiceSet = await claudeService.generatePracticeSet(topic);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeScreen(
          topic: topic,
          practiceSet: practiceSet,
          claudeService: claudeService,
          storageService: storageService,
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
