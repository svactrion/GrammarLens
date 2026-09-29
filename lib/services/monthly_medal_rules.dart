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
}
