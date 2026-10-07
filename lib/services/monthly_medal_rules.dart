import '../models/daily_test_set.dart';
import '../models/medal_tier.dart';

abstract final class MonthlyMedalRules {
  static const ruleVersion = 1;

  /// Points per answer (rule v1): correct +2, wrong +1, skipped +0.
  static const pointsPerCorrect = 2;
  static const pointsPerWrong = 1;

  static int score({required int correct, required int wrong}) =>
      correct * pointsPerCorrect + wrong * pointsPerWrong;

  /// Every question of every day of the month answered correctly:
  /// days × [DailyTestSet.questionCount] × [pointsPerCorrect] (5 × 2 = 10 a
  /// day).
  static int maxScore(int year, int month) =>
      DateTime(year, month + 1, 0).day *
      DailyTestSet.questionCount *
      pointsPerCorrect;

  static int threshold(int year, int month, MedalTier tier) {
    final percent = switch (tier) {
      MedalTier.bronze => 25,
      MedalTier.silver => 50,
      MedalTier.gold => 75,
    };
    return (maxScore(year, month) * percent + 99) ~/ 100;
  }

  static MedalTier? tierFor({
    required int year,
    required int month,
    required int score,
  }) {
    if (score >= threshold(year, month, MedalTier.gold)) {
      return MedalTier.gold;
    }
    if (score >= threshold(year, month, MedalTier.silver)) {
      return MedalTier.silver;
    }
    if (score >= threshold(year, month, MedalTier.bronze)) {
      return MedalTier.bronze;
    }
    return null;
  }

  /// Batch 6, M15: the month card's near-miss line shows when the gap to
  /// the next tier is at most this many points (and never at Gold). One
  /// fully answered day is worth at least this much
  /// ([DailyTestSet.questionCount] × [pointsPerWrong]). Reviewed again if
  /// Batch 5 changes the rule.
  static const nearMissPoints = 5;

  /// The next tier above [score] in [year]/[month] and the points still
  /// missing to it, or null at Gold. The month card's only source for
  /// "next tier and gap" (M20).
  static (MedalTier, int)? nextTier(int year, int month, int score) {
    for (final tier in MedalTier.values) {
      final t = threshold(year, month, tier);
      if (score < t) return (tier, t - score);
    }
    return null;
  }

  /// [nextTier] when its gap is at most [nearMissPoints], else null (M15).
  static (MedalTier, int)? nearMiss(int year, int month, int score) {
    final next = nextTier(year, month, score);
    return next != null && next.$2 <= nearMissPoints ? next : null;
  }
}
