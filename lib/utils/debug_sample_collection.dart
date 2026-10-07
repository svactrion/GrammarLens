import 'package:flutter/foundation.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';
import '../models/welcome_badge.dart';
import '../services/monthly_medal_rules.dart';
import '../widgets/monthly_climb/climb_debug_month_card.dart';
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
/// and eight finished months across the four themes and every tier, plus
/// the running month) instead of what is stored, so the App Store
/// screenshot of the shelf can be taken without months of real use.
///
/// It agrees with the rest of the app's screenshots: last month is the
/// month card's Gold summary (`ClimbDebugMonthCard`'s `summary_gold`:
/// theme, tier, steps, points), and the running month is the real one
/// (Profile passes the stored progress in), so it matches Home.
///
/// Memory only and display only: nothing is written, past months are not
/// finalized, the only stored record read is the running month's progress,
/// and `profile_medals_viewed` is not sent while it is on. Debug and profile builds only; in a release
/// build [kReleaseMode] is the constant true, so [enabled] is always false
/// there.
abstract final class DebugSampleCollection {
  /// The debug panel's switch, in memory only (off at every launch).
  static bool runtime = false;

  /// Whether Profile shows the sample collection.
  static bool get enabled =>
      !kReleaseMode && DebugTools.enabledForTesting && runtime;

  /// The tiers and themes of the seven months before last month, the most
  /// recent first: every tier at least twice, every theme at least once.
  /// With last month, the Welcome badge and the running month the shelf has
  /// ten slots: two full rows of five on an iPhone, eight and two on an
  /// iPad (no medal alone on a row).
  static final _earlier = [
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

  /// [sample] for today, with the running month's stored [progress] when
  /// there is one.
  static SampleCollection current({MonthlyMedalProgress? progress}) =>
      sample(clockForTesting(), progress: progress);

  /// The sample, relative to [now]'s month: last month as the month card's
  /// Gold summary shows it, the seven months before it finished, and the
  /// running month: [progress] (the stored one) or, without it, Silver on
  /// the theme the calendar gives the month.
  static SampleCollection sample(DateTime now,
      {MonthlyMedalProgress? progress}) {
    final year = now.year, month = now.month;
    (int, int) back(int n) {
      final d = DateTime(year, month - n);
      return (d.year, d.month);
    }

    final results = <MonthlyMedalResult>[];
    final themeIds = <(int, int), String>{};
    final card =
        ClimbDebugMonthCard.sample(ClimbDebugMonthCardValue.summaryGold, now)!;
    final (py, pm) = (card.previousYear, card.previousMonth);
    results.add(MonthlyMedalResult(
        year: py,
        month: pm,
        score: card.score,
        maxScore: MonthlyMedalRules.maxScore(py, pm),
        activeDays: card.steps,
        correct: 0,
        wrong: 0,
        skipped: 0,
        tier: card.tier,
        ruleVersion: 1,
        finalizedAt: DateTime(py, pm + 1, 1)));
    themeIds[(py, pm)] = card.previousTheme.id;
    for (final (i, (tier, theme)) in _earlier.indexed) {
      final (y, m) = back(i + 2);
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
    // As Home shows it (and the month card names it as "Next").
    themeIds[(year, month)] = card.theme.id;
    final (wy, wm) = back(_earlier.length + 1);
    return (
      progress: progress ??
          MonthlyMedalProgress(
              year: year,
              month: month,
              score:
                  MonthlyMedalRules.threshold(year, month, MedalTier.silver) +
                      12,
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
