import '../models/medal_tier.dart';

abstract final class MonthlyMedalRules {
  static const ruleVersion = 1;

  static int score({required int correct, required int wrong}) =>
      correct * 2 + wrong;

  static int maxScore(int year, int month) =>
      DateTime(year, month + 1, 0).day * 10;

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
