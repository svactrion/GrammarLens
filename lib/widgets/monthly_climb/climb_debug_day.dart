import 'package:flutter/foundation.dart';

import '../../utils/debug_tools.dart';
import 'climb_debug_controls.dart';

/// Debug and profile builds only (N27): the Monthly Climb scene shows step
/// n of the month (the avatar's place, the passed-day dots, the shrink at
/// the summit) instead of the real progress, so any day can be checked on a
/// device. Set with `--dart-define=CLIMB_DEBUG_DAY=<n>` at launch, or
/// changed while the app runs from the debug panel ([runtime]).
///
/// Display only: the real progress, the Daily Test flow and `dayKey` are
/// untouched, and so are the card's month and step chips. In release builds
/// [kReleaseMode] is the constant true, so [value] is always null there and
/// neither the define nor the panel has any effect.
abstract final class ClimbDebugDay {
  static const _defined =
      int.fromEnvironment('CLIMB_DEBUG_DAY', defaultValue: -1);

  static int? _forTesting;
  static int? _runtime;

  /// Stands in for the define in tests, which cannot pass one. Still
  /// ignored in release builds.
  @visibleForTesting
  static set valueForTesting(int? value) => _forTesting = value;

  /// The debug panel's day (N27), in memory only: a step, or −1 for the
  /// real progress. Null: the define's value (the start of a launch).
  static int? get runtime => _runtime;
  static set runtime(int? value) {
    _runtime = value;
    ClimbDebugControls.instance.settingsChanged();
  }

  /// The step to show instead of the real one, or null.
  static int? get value => resolve(
      enabled: !kReleaseMode && DebugTools.enabledForTesting,
      defined: _forTesting ?? _runtime ?? _defined);

  /// [defined] (−1 when not set) applies only when [enabled] (not release).
  @visibleForTesting
  static int? resolve({required bool enabled, required int defined}) =>
      enabled && defined >= 0 ? defined : null;
}
