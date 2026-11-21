import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The motion tokens (`docs/design/ui-polish/handoff/SPEC.md` §3.3): every
/// duration and curve of the UI polish components comes from here, never
/// an ad-hoc value in a widget.
///
/// Reduce Motion (`MediaQuery.disableAnimations`): loops stop, entrances
/// become a [fast] fade, confetti and rays do not run ([reduced]).
abstract final class AppMotion {
  /// Taps, small state changes, the Reduce Motion fade.
  static const Duration fast = Duration(milliseconds: 150);

  /// Cross-fades, pops, selection frames.
  static const Duration base = Duration(milliseconds: 250);

  /// Colour changes of a whole card, page slides.
  static const Duration slow = Duration(milliseconds: 400);

  /// Medals, badges, step arrivals.
  static const Duration celebrate = Duration(milliseconds: 800);

  /// Sheets spring in from the bottom (SPEC §3.6: 450 ms).
  static const Duration sheet = Duration(milliseconds: 450);

  /// The pressable button's travel (V00-MotionSystem: 80 ms).
  static const Duration press = Duration(milliseconds: 80);

  /// Entrances.
  static const Curve enter = Curves.easeOutCubic;

  /// Pops.
  static const Curve pop = Curves.easeOutBack;

  /// Loops.
  static const Curve loop = Curves.easeInOut;

  /// Sheets and pages: an underdamped spring, close to
  /// `SpringDescription(mass: 1, stiffness: 300, damping: 24)`.
  static const Curve spring = _SpringCurve();

  /// Exits.
  static const Curve exit = Curves.easeIn;

  /// Stagger between items entering one after another.
  static const Duration stagger = Duration(milliseconds: 60);

  /// The boards' "nudge" (gl-nudge) at [t] of its period, 0 to 1: still
  /// until 60 %, out to 1 at 75 %, back to 1/3 at 88 %, home at 100 %.
  /// The hint knob (V07) and "See plans" (V13) scale it to their distance.
  static double nudge(double t) {
    double ease(double a, double b, double from, double to) =>
        from + (to - from) * Curves.easeInOut.transform((t - a) / (b - a));
    if (t < .6) return 0;
    if (t < .75) return ease(.6, .75, 0, 1);
    if (t < .88) return ease(.75, .88, 1, 1 / 3);
    return ease(.88, 1, 1 / 3, 0);
  }

  /// Whether motion is reduced here (the system's Reduce Motion).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Tests switch the ambient loops off (`test/flutter_test_config.dart`),
  /// so `pumpAndSettle` can settle; a test of a loop turns them back on.
  @visibleForTesting
  static bool loopsEnabled = true;

  /// Whether ambient loops (breathe, float, shine, pulse, flicker) run
  /// here: not under Reduce Motion, and not while [TickerMode] is off (a
  /// tab or route that is not visible).
  static bool loopsOn(BuildContext context) =>
      loopsEnabled && !reduced(context) && TickerMode.valuesOf(context).enabled;

  /// [duration], or [fast] when motion is reduced (an entrance becomes a
  /// short fade).
  static Duration entrance(BuildContext context, Duration duration) =>
      reduced(context) ? fast : duration;

  /// [duration], or zero when motion is reduced (a state change that is
  /// not an entrance just happens).
  static Duration orInstant(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// A critically-under-damped spring as a [Curve]: overshoots by about 4 %
/// and settles, the sheets' and pages' feel.
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    // x(t) = 1 - e^(-z w t) (cos(wd t) + (z w / wd) sin(wd t)), normalised
    // so the curve ends exactly at 1.
    const zeta = 0.72;
    const omega = 11.0;
    final wd = omega * math.sqrt(1 - zeta * zeta);
    double x(double t) =>
        1 -
        math.exp(-zeta * omega * t) *
            (math.cos(wd * t) + (zeta * omega / wd) * math.sin(wd * t));
    return x(t) / x(1);
  }
}
