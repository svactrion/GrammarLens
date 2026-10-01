import 'package:flutter/foundation.dart';

import '../../models/climb_theme.dart';

/// Debug builds only: `--dart-define=CLIMB_DEBUG_THEME=<theme id>` makes the
/// Monthly Climb scene show that theme (`green_slope`, `ember_peak`,
/// `glacier_peak`, `red_canyon`), so any theme can be checked on a device
/// in any month. Combines with `CLIMB_DEBUG_DAY` (`ClimbDebugDay`).
///
/// Display only: the month's recorded theme (`climb_month_themes`), the
/// rotation, the Daily Test and `dayKey` are untouched. An unknown id has
/// no effect. In profile and release builds [kDebugMode] is the constant
/// false, so [value] is always null there and the define has no effect.
abstract final class ClimbDebugTheme {
  static const _defined = String.fromEnvironment('CLIMB_DEBUG_THEME');

  static String? _forTesting;

  /// Stands in for the define in tests, which cannot pass one. Still
  /// ignored outside debug builds.
  @visibleForTesting
  static set valueForTesting(String? id) => _forTesting = id;

  /// The theme to show instead of the month's, or null.
  static ClimbTheme? get value =>
      resolve(debug: kDebugMode, defined: _forTesting ?? _defined);

  /// [defined] ('' when not set) applies only when [debug] and only when it
  /// names a theme.
  @visibleForTesting
  static ClimbTheme? resolve({required bool debug, required String defined}) {
    if (!debug || defined.isEmpty) return null;
    for (final theme in ClimbThemes.all) {
      if (theme.id == defined) return theme;
    }
    return null;
  }
}
