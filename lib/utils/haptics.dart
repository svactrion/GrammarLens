import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// The haptic map (`docs/design/ui-polish/handoff/SPEC.md` §3.4) over
/// Flutter's [HapticFeedback]. Every haptic of the UI polish goes through
/// here.
///
/// The system setting is followed by the platform: on iOS the feedback
/// generators behind [HapticFeedback] do nothing when System Haptics are off.
///
/// Rules (SPEC §3.4): at most one haptic when a screen opens; none in loops;
/// never a hard error buzz (warning is two light taps).
abstract final class HapticMap {
  /// Choices, slider stops, switches, picker steps.
  static void selection() => _play(_Kind.selection);

  /// Taps, small progress.
  static void light() => _play(_Kind.light);

  /// Primary buttons, the ticket.
  static void medium() => _play(_Kind.medium);

  /// Medium, then light after 90 ms.
  static void success() => _play(_Kind.success);

  /// Light, then light after 80 ms (a wrong answer, errors).
  static void warning() => _play(_Kind.warning);

  /// Only the irreversible Reset confirmation.
  static void heavy() => _play(_Kind.heavy);

  /// Two light taps 90 ms apart (Q04: a partly right answer).
  static void lightTwice() => _play(_Kind.lightTwice);

  /// Tests: every haptic played, by name, instead of the platform call.
  @visibleForTesting
  static List<String>? log;

  static void _play(_Kind kind) {
    final log = HapticMap.log;
    if (log != null) {
      log.add(kind.name);
      return;
    }
    switch (kind) {
      case _Kind.selection:
        unawaited(HapticFeedback.selectionClick());
      case _Kind.light:
        unawaited(HapticFeedback.lightImpact());
      case _Kind.medium:
        unawaited(HapticFeedback.mediumImpact());
      case _Kind.heavy:
        unawaited(HapticFeedback.heavyImpact());
      case _Kind.success:
        unawaited(HapticFeedback.mediumImpact());
        Timer(const Duration(milliseconds: 90),
            () => unawaited(HapticFeedback.lightImpact()));
      case _Kind.warning:
        unawaited(HapticFeedback.lightImpact());
        Timer(const Duration(milliseconds: 80),
            () => unawaited(HapticFeedback.lightImpact()));
      case _Kind.lightTwice:
        unawaited(HapticFeedback.lightImpact());
        Timer(const Duration(milliseconds: 90),
            () => unawaited(HapticFeedback.lightImpact()));
    }
  }
}

enum _Kind { selection, light, medium, success, warning, heavy, lightTwice }
