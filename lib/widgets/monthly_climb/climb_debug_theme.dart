import 'package:flutter/foundation.dart';

import '../../models/climb_theme.dart';
import '../../utils/debug_tools.dart';
import 'climb_debug_controls.dart';

/// Debug and profile builds only (N27): the Monthly Climb scene shows a
/// theme (`green_slope`, `ember_peak`, `glacier_peak`, `red_canyon`)
/// instead of the month's, so any theme can be checked on a device in any
/// month. Set with `--dart-define=CLIMB_DEBUG_THEME=<theme id>` at launch,
/// or changed while the app runs from the debug panel ([runtime]). Combines
/// with `CLIMB_DEBUG_DAY` (`ClimbDebugDay`).
///
/// Display only: the month's recorded theme (`climb_month_themes`), the
/// rotation, the Daily Test and `dayKey` are untouched. An unknown id has
/// no effect. In release builds [kReleaseMode] is the constant true, so
/// [value] is always null there.
abstract final class ClimbDebugTheme {
  static const _defined = String.fromEnvironment('CLIMB_DEBUG_THEME');

  static String? _forTesting;
  static String? _runtime;

  /// Stands in for the define in tests, which cannot pass one. Still
  /// ignored in release builds.
  @visibleForTesting
  static set valueForTesting(String? id) => _forTesting = id;

  /// The debug panel's theme (N27), in memory only: a theme id, or '' for
  /// the month's real theme. Null: the define's value.
  static String? get runtime => _runtime;
  static set runtime(String? id) {
    _runtime = id;
    ClimbDebugControls.instance.settingsChanged();
  }

  /// The theme to show instead of the month's, or null.
  static ClimbTheme? get value => resolve(
      enabled: !kReleaseMode && DebugTools.enabledForTesting,
      defined: _forTesting ?? _runtime ?? _defined);

  /// [defined] ('' when not set) applies only when [enabled] (not release)
  /// and only when it names a theme.
  @visibleForTesting
  static ClimbTheme? resolve({required bool enabled, required String defined}) {
    if (!enabled || defined.isEmpty) return null;
    for (final theme in ClimbThemes.all) {
      if (theme.id == defined) return theme;
    }
    return null;
  }
}
