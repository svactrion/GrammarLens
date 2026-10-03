import 'package:flutter/foundation.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';
import '../models/welcome_badge.dart';
import '../services/monthly_medal_rules.dart';
import 'debug_tools.dart';

/// Profile's medal shelf, filled from [sample] instead of storage.
typedef SampleCollection = ({
  MonthlyMedalProgress progress,
  List<MonthlyMedalResult> results,
  WelcomeBadge welcomeBadge,
  Map<(int, int), String> themeIds,
});

/// P6 (1.1.0 release preparation): the debug panel's "sample collection".
/// While on, Profile's "Medal collection" shows [sample] (the Welcome badge
/// and seven finished months across the four themes and every tier, plus
/// the running month) instead of what is stored, so the App Store
/// screenshot of the shelf can be taken without months of real use.
///
/// Memory only and display only: no stored record is read for the shelf or
/// written, past months are not finalized, and `profile_medals_viewed` is
/// not sent while it is on. Debug and profile builds only; in a release
/// build [kReleaseMode] is the constant true, so [enabled] is always false
/// there.
abstract final class DebugSampleCollection {
  /// The debug panel's switch, in memory only (off at every launch).
  static bool runtime = false;

  /// Whether Profile shows the sample collection.
  static bool get enabled =>
      !kReleaseMode && DebugTools.enabledForTesting && runtime;

  /// The tiers and themes of the seven finished months, the most recent
  /// first: every tier at least twice, every theme at least once.
  static final _finished = [
    (MedalTier.gold, ClimbThemes.redCanyon.id),
    (MedalTier.silver, ClimbThemes.glacierPeak.id),
    (MedalTier.gold, ClimbThemes.emberPeak.id),
    (MedalTier.bronze, ClimbThemes.greenSlope.id),
    (MedalTier.silver, ClimbThemes.redCanyon.id),
    (MedalTier.bronze, ClimbThemes.glacierPeak.id),
    (MedalTier.gold, ClimbThemes.emberPeak.id),
  ];

  /// The clock [current] reads; a test sets it.
  @visibleForTesting
  static DateTime Function() clockForTesting = DateTime.now;

  /// [sample] for today.
  static SampleCollection current() => sample(clockForTesting());

  /// The sample, relative to [now]'s month: the running month at Silver on
  /// the theme the calendar gives it, the seven months before it finished.
  static SampleCollection sample(DateTime now) {
    final year = now.year, month = now.month;
    (int, int) back(int n) {
      final d = DateTime(year, month - n);
      return (d.year, d.month);
    }

    final results = <MonthlyMedalResult>[];
    final themeIds = <(int, int), String>{};
    for (final (i, (tier, theme)) in _finished.indexed) {
      final (y, m) = back(i + 1);
      final score = MonthlyMedalRules.threshold(y, m, tier) + 4;
      final days = DateTime(y, m + 1, 0).day;
      results.add(MonthlyMedalResult(
          year: y,
          month: m,
          score: score,
          maxScore: MonthlyMedalRules.maxScore(y, m),
          activeDays: days - 3 - i % 3,
          correct: 0,
          wrong: 0,
          skipped: 0,
          tier: MonthlyMedalRules.tierFor(year: y, month: m, score: score),
          ruleVersion: 1,
          finalizedAt: DateTime(y, m + 1, 1)));
      themeIds[(y, m)] = theme;
    }
    themeIds[(year, month)] = ClimbThemeRotation.shownFor(year, month).id;
    final (wy, wm) = back(_finished.length);
    return (
      progress: MonthlyMedalProgress(
          year: year,
          month: month,
          score:
              MonthlyMedalRules.threshold(year, month, MedalTier.silver) + 12,
          maxScore: MonthlyMedalRules.maxScore(year, month),
          activeDays: 16,
          correct: 0,
          wrong: 0,
          skipped: 0),
      results: results,
      welcomeBadge: WelcomeBadge(
          earnedAt: DateTime(wy, wm, 3), ruleVersion: 1, backfilled: false),
      themeIds: themeIds,
    );
  }
}
