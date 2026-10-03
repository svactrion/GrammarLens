import 'package:flutter/foundation.dart';

import '../../models/medal_tier.dart';
import '../../utils/debug_tools.dart';
import 'climb_save_points.dart';

/// What `CLIMB_DEBUG_MILESTONE` plays (Batch 5, N13, N22).
enum ClimbDebugMilestoneValue {
  bronze('bronze'),
  silver('silver'),
  gold('gold'),
  firstCamp('first_camp'),
  halfwayHut('halfway_hut'),
  mountainSpring('mountain_spring'),
  highCamp('high_camp'),
  summit('summit');

  final String wireName;
  const ClimbDebugMilestoneValue(this.wireName);

  /// The tier this value celebrates, or null for a save point.
  MedalTier? get tier => switch (this) {
        bronze => MedalTier.bronze,
        silver => MedalTier.silver,
        gold => MedalTier.gold,
        _ => null,
      };

  /// The save point (or the flag, for `summit`) this value walks onto, or
  /// null for a tier.
  ClimbSavePoint? get savePoint => tier != null
      ? null
      : [...ClimbSavePoints.all, ClimbSavePoints.flag]
          .firstWhere((p) => p.eventId == wireName);
}

/// Debug and profile builds only (N22, widened by N27):
/// `--dart-define=CLIMB_DEBUG_MILESTONE=<bronze|silver|
/// gold|first_camp|halfway_hut|mountain_spring|high_camp|summit>` plays a
/// milestone on every launch and hot restart, so the celebration and the
/// save point label can be checked on a device without earning them.
///
/// - A tier opens the celebration layer over Home, for the current month
///   and its theme (or `CLIMB_DEBUG_THEME`'s), after the month card if
///   `CLIMB_DEBUG_MONTH_CARD` replays one.
/// - A save point mounts the scene one step before that save point's step
///   in the current month and hops onto it once Home is shown and no zoom
///   runs, so the light-up and the label play. For the scene it takes the
///   place of `CLIMB_DEBUG_DAY`; `CLIMB_DEBUG_THEME` still picks the theme.
///
/// The debug panel plays the same milestones while the app runs (N27,
/// `ClimbDebugControls`).
///
/// Display only: it reads and writes no stored record and sends no event.
/// In release builds [kReleaseMode] is the constant true, so [value] is
/// always null there and the define has no effect.
abstract final class ClimbDebugMilestone {
  static const _defined = String.fromEnvironment('CLIMB_DEBUG_MILESTONE');

  static String? _forTesting;

  /// Stands in for the define in tests, which cannot pass one. Still
  /// ignored in release builds.
  @visibleForTesting
  static set valueForTesting(String? value) => _forTesting = value;

  /// The milestone to play, or null.
  static ClimbDebugMilestoneValue? get value => resolve(
      enabled: !kReleaseMode && DebugTools.enabledForTesting,
      defined: _forTesting ?? _defined);

  /// [defined] ('' when not set) applies only when [enabled] (not release)
  /// and only when it names a value.
  @visibleForTesting
  static ClimbDebugMilestoneValue? resolve(
      {required bool enabled, required String defined}) {
    if (!enabled || defined.isEmpty) return null;
    for (final v in ClimbDebugMilestoneValue.values) {
      if (v.wireName == defined) return v;
    }
    return null;
  }
}
