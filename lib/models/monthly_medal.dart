import 'medal_tier.dart';

class MonthlyMedalProgress {
  final int year;
  final int month;
  final int score;
  final int maxScore;
  final int activeDays;
  final int correct;
  final int wrong;
  final int skipped;

  const MonthlyMedalProgress({
    required this.year,
    required this.month,
    required this.score,
    required this.maxScore,
    required this.activeDays,
    required this.correct,
    required this.wrong,
    required this.skipped,
  });
}

class MonthlyMedalResult extends MonthlyMedalProgress {
  final MedalTier? tier;
  final int ruleVersion;
  final DateTime finalizedAt;

  const MonthlyMedalResult({
    required super.year,
    required super.month,
    required super.score,
    required super.maxScore,
    required super.activeDays,
    required super.correct,
    required super.wrong,
    required super.skipped,
    required this.tier,
    required this.ruleVersion,
    required this.finalizedAt,
  });
}
