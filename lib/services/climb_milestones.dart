import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import '../widgets/monthly_climb/climb_save_points.dart';
import 'monthly_medal_rules.dart';
import 'storage_service.dart';

/// What one Daily Test completion reached in its month (Batch 5, N8, N12,
/// N15, N24): a tier, and the save points (the flag included) its step
/// arrived at.
///
/// Computed after the save, from the set's own month: "after" is the
/// month's progress as stored, "before" is after minus this completion. A
/// set completes once and the score only grows (ledger rows are only
/// added), so each tier and each save point is reached on exactly one
/// completion a month: no record is needed to show it once (N24).
class ClimbMilestones {
  final int year, month;

  /// The month's theme, the one its medal and scene are drawn in.
  final ClimbTheme theme;

  /// The tier this completion crossed into, or null. One completion is
  /// worth at most 10 points and every tier band at least 70, so it never
  /// crosses two.
  final MedalTier? tier;

  /// The save points (and the flag, on the month's last step) whose step
  /// this completion reached, in trail order.
  final List<ClimbSavePoint> savePoints;

  /// The month's steps and score after this completion.
  final int steps, score;

  const ClimbMilestones({
    required this.year,
    required this.month,
    required this.theme,
    required this.tier,
    required this.savePoints,
    required this.steps,
    required this.score,
  });

  bool get isEmpty => tier == null && savePoints.isEmpty;

  /// The milestones between two states of [year]/[month], pure.
  static ClimbMilestones between({
    required int year,
    required int month,
    required ClimbTheme theme,
    required int stepsBefore,
    required int stepsAfter,
    required int scoreBefore,
    required int scoreAfter,
  }) {
    final before =
        MonthlyMedalRules.tierFor(year: year, month: month, score: scoreBefore);
    final after =
        MonthlyMedalRules.tierFor(year: year, month: month, score: scoreAfter);
    final days = DateTime(year, month + 1, 0).day;
    return ClimbMilestones(
      year: year,
      month: month,
      theme: theme,
      tier: after != null && (before == null || after.index > before.index)
          ? after
          : null,
      savePoints: [
        for (final p in [
          ...ClimbSavePoints.all,
          if (theme.hasSummitFlag) ClimbSavePoints.flag,
        ])
          if (stepsBefore < p.reachedOn(days) &&
              p.reachedOn(days) <= stepsAfter)
            p,
      ],
      steps: stepsAfter,
      score: scoreAfter,
    );
  }

  /// The milestones of the completion just saved for the set of [day]
  /// (`YYYY-MM-DD`), which earned [step] (0/1) and [points]. Null when
  /// that month is already finalized (a set finished after its month was
  /// frozen, N24: no celebration, no label, no event) or when storage
  /// cannot answer: a missed celebration is better than a wrong one.
  static Future<ClimbMilestones?> afterCompletion({
    required StorageService storage,
    required String day,
    required int step,
    required int points,
  }) async {
    try {
      final parts = day.split('-');
      final year = int.parse(parts[0]), month = int.parse(parts[1]);
      final results = await storage.getMonthlyMedalResults();
      if (results.any((r) => r.year == year && r.month == month)) return null;
      final progress = await storage.getClimbProgress(year, month);
      final score = MonthlyMedalRules.score(
          correct: progress.correct, wrong: progress.wrong);
      final theme =
          ClimbThemes.byId(await storage.resolveClimbMonthTheme(year, month));
      return between(
        year: year,
        month: month,
        theme: theme,
        stepsBefore: progress.steps - step,
        stepsAfter: progress.steps,
        scoreBefore: score - points,
        scoreAfter: score,
      );
    } catch (_) {
      return null;
    }
  }
}
