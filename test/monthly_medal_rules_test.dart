import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';

void main() {
  test('scores correct, wrong and skipped answers as approved', () {
    expect(MonthlyMedalRules.score(correct: 5, wrong: 0), 10);
    expect(MonthlyMedalRules.score(correct: 0, wrong: 5), 5);
    expect(MonthlyMedalRules.score(correct: 3, wrong: 1), 7);
  });

  test('thresholds are ceil 25/50/75 percent for 28-31 day months', () {
    expect(_thresholds(2026, 2), [70, 140, 210]);
    expect(_thresholds(2028, 2), [73, 145, 218]);
    expect(_thresholds(2026, 4), [75, 150, 225]);
    expect(_thresholds(2026, 1), [78, 155, 233]);
  });

  test('tier boundaries are inclusive and return only the highest tier', () {
    expect(_tier(2026, 4, 74), isNull);
    expect(_tier(2026, 4, 75), MedalTier.bronze);
    expect(_tier(2026, 4, 150), MedalTier.silver);
    expect(_tier(2026, 4, 225), MedalTier.gold);
  });
}

List<int> _thresholds(int year, int month) => [
      for (final tier in MedalTier.values)
        MonthlyMedalRules.threshold(year, month, tier),
    ];

MedalTier? _tier(int year, int month, int score) =>
    MonthlyMedalRules.tierFor(year: year, month: month, score: score);
