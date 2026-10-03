import 'package:flutter/foundation.dart';

import '../../models/climb_theme.dart';
import '../../models/medal_tier.dart';
import '../../services/month_transition.dart';
import '../../services/monthly_medal_rules.dart';
import 'climb_debug_theme.dart';

/// What `CLIMB_DEBUG_MONTH_CARD` replays (Batch 6, M9, M17).
enum ClimbDebugMonthCardValue {
  summaryGold('summary_gold'),
  summaryNone('summary_none'),
  summaryNear('summary_near'),
  fresh('fresh'),
  firstRun('first_run');

  final String wireName;
  const ClimbDebugMonthCardValue(this.wireName);
}

/// Debug and profile builds only (M17): `--dart-define=CLIMB_DEBUG_MONTH_CARD=
/// <summary_gold|summary_none|summary_near|fresh|first_run>` replays the
/// month card (or, for `first_run`, the first run's zoom) with sample data
/// on every launch and hot restart, so it can be checked, and the zoom's
/// frame times measured in a profile build, without waiting for a month to
/// change.
///
/// The replay never reads or writes the stored "seen" records
/// (`one_time_flags`) and sends no events (M18), unless
/// `--dart-define=CLIMB_DEBUG_MONTH_CARD_EVENTS=true` is also passed, for a
/// DebugView check. Works with `CLIMB_DEBUG_DAY` (the scene's step, so the
/// zoom ends on it) and `CLIMB_DEBUG_THEME` (the card names that theme).
/// In release builds [kReleaseMode] is the constant true, so [value] is
/// always null there and the define has no effect.
abstract final class ClimbDebugMonthCard {
  static const _defined = String.fromEnvironment('CLIMB_DEBUG_MONTH_CARD');
  static const _eventsDefined =
      bool.fromEnvironment('CLIMB_DEBUG_MONTH_CARD_EVENTS');

  static String? _forTesting;
  static bool? _eventsForTesting;

  /// Stands in for the define in tests, which cannot pass one. Still
  /// ignored in release builds.
  @visibleForTesting
  static set valueForTesting(String? value) => _forTesting = value;

  /// Stands in for `CLIMB_DEBUG_MONTH_CARD_EVENTS` in tests.
  @visibleForTesting
  static set eventsForTesting(bool? value) => _eventsForTesting = value;

  /// The replay, or null.
  static ClimbDebugMonthCardValue? get value =>
      resolve(enabled: !kReleaseMode, defined: _forTesting ?? _defined);

  /// Whether the replay sends its events (off by default, M18).
  static bool get sendsEvents =>
      value != null && (_eventsForTesting ?? _eventsDefined);

  /// [defined] ('' when not set) applies only when [enabled] (not release)
  /// and only when it names a value.
  @visibleForTesting
  static ClimbDebugMonthCardValue? resolve(
      {required bool enabled, required String defined}) {
    if (!enabled || defined.isEmpty) return null;
    for (final v in ClimbDebugMonthCardValue.values) {
      if (v.wireName == defined) return v;
    }
    return null;
  }

  /// The sample card for [v] in the month of [now]: last month's numbers
  /// from the medal rules (never hard-coded thresholds), the month's
  /// calendar theme or `CLIMB_DEBUG_THEME`'s (for last month's medal too).
  /// Null for `first_run`, which
  /// has no card.
  static MonthCardData? sample(ClimbDebugMonthCardValue v, DateTime now) {
    final (py, pm) = MonthTransition.previousMonth(now.year, now.month);
    final theme = ClimbDebugTheme.value ??
        ClimbThemeRotation.shownFor(now.year, now.month);
    // Last month's medal: `CLIMB_DEBUG_THEME`'s theme too, so each theme's
    // medal can be checked in the card (Batch 5).
    final previousTheme =
        ClimbDebugTheme.value ?? ClimbThemeRotation.shownFor(py, pm);
    final days = DateTime(py, pm + 1, 0).day;
    int threshold(MedalTier t) => MonthlyMedalRules.threshold(py, pm, t);
    MonthCardData summary(int steps, int score) => MonthCardData(
          year: now.year,
          month: now.month,
          theme: theme,
          variant: MonthCardVariant.summary,
          previousTheme: previousTheme,
          previousYear: py,
          previousMonth: pm,
          tier: MonthlyMedalRules.tierFor(year: py, month: pm, score: score),
          steps: steps,
          days: days,
          score: score,
          nearMiss: MonthlyMedalRules.nearMiss(py, pm, score),
        );
    return switch (v) {
      ClimbDebugMonthCardValue.summaryGold => summary(
          days - 4,
          (threshold(MedalTier.gold) + 12)
              .clamp(0, MonthlyMedalRules.maxScore(py, pm))),
      ClimbDebugMonthCardValue.summaryNone =>
        summary(6, (threshold(MedalTier.bronze) - 33).clamp(0, 1 << 30)),
      ClimbDebugMonthCardValue.summaryNear => summary(days - 7,
          threshold(MedalTier.gold) - MonthlyMedalRules.nearMissPoints),
      ClimbDebugMonthCardValue.fresh => MonthCardData(
          year: now.year,
          month: now.month,
          theme: theme,
          variant: MonthCardVariant.fresh,
          previousYear: py,
          previousMonth: pm),
      ClimbDebugMonthCardValue.firstRun => null,
    };
  }
}
