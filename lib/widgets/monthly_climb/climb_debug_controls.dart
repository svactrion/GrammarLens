import 'package:flutter/foundation.dart';

import '../../utils/debug_tools.dart';
import 'climb_debug_milestone.dart';
import 'climb_debug_month_card.dart';

/// A replay asked for from the debug panel (N27): a milestone or a month
/// card, numbered so the same one can be asked for again and again.
@immutable
class ClimbDebugPlay {
  final ClimbDebugMilestoneValue? milestone;
  final ClimbDebugMonthCardValue? monthCard;
  final int id;
  const ClimbDebugPlay._({this.milestone, this.monthCard, required this.id});
}

/// The debug panel's link to the scene and Home (Batch 5, N27): the
/// `CLIMB_DEBUG_*` settings changed while the app runs, in debug and
/// profile builds. It notifies when the day or the theme changes and when
/// a replay is asked for; the app shell then shows Home, and Home takes
/// the replay ([takePlay]) once it is visible.
///
/// Memory only: nothing here is stored, so a relaunch starts again from
/// the `--dart-define` values. In release builds [available] is the
/// constant false, so the panel and everything behind it are compiled out.
class ClimbDebugControls extends ChangeNotifier {
  ClimbDebugControls._();
  static final instance = ClimbDebugControls._();

  /// Whether the panel and its run-time settings exist: debug and profile
  /// builds (N27). [DebugTools.enabledForTesting] lets a test see the app
  /// as a release build would.
  static bool get available => !kReleaseMode && DebugTools.enabledForTesting;

  ClimbDebugPlay? _pending;
  int _ids = 0;

  /// The replay waiting for Home, if any.
  ClimbDebugPlay? get pending => _pending;

  void playMilestone(ClimbDebugMilestoneValue value) =>
      _ask(ClimbDebugPlay._(milestone: value, id: ++_ids));

  void playMonthCard(ClimbDebugMonthCardValue value) =>
      _ask(ClimbDebugPlay._(monthCard: value, id: ++_ids));

  void _ask(ClimbDebugPlay play) {
    if (!available) return;
    _pending = play;
    notifyListeners();
  }

  /// Hands the waiting replay to Home, once.
  ClimbDebugPlay? takePlay() {
    final play = _pending;
    _pending = null;
    return play;
  }

  /// Counts the panel's day and theme changes: the scene listens to it and
  /// redraws (replays notify the controls themselves).
  final settingsRevision = ValueNotifier<int>(0);

  /// The day or the theme changed: the scene redraws.
  void settingsChanged() {
    if (available) settingsRevision.value++;
  }

  @visibleForTesting
  void resetForTesting() => _pending = null;
}
