import 'package:flutter/foundation.dart';

/// Debug builds only: `--dart-define=CLIMB_DEBUG_DAY=<n>` makes the Monthly
/// Climb scene show step n of the month (the avatar's place, the passed-day
/// dots, the shrink at the summit), so any day can be checked on a device.
///
/// Display only: the real progress, the Daily Test flow and `dayKey` are
/// untouched, and so are the card's month and step chips. In profile and
/// release builds [kDebugMode] is the constant false, so [value] is always
/// null there and the define has no effect.
abstract final class ClimbDebugDay {
  static const _defined =
      int.fromEnvironment('CLIMB_DEBUG_DAY', defaultValue: -1);

  static int? _forTesting;

  /// Stands in for the define in tests, which cannot pass one. Still
  /// ignored outside debug builds.
  @visibleForTesting
  static set valueForTesting(int? value) => _forTesting = value;

  /// The step to show instead of the real one, or null.
  static int? get value =>
      resolve(debug: kDebugMode, defined: _forTesting ?? _defined);

  /// [defined] (−1 when not set) applies only when [debug].
  @visibleForTesting
  static int? resolve({required bool debug, required int defined}) =>
      debug && defined >= 0 ? defined : null;
}
