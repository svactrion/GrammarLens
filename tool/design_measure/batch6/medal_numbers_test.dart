// Batch 6 Batch 0, §3: the medal rule's numbers for 28–31-day months, read
// from the product's own MonthlyMedalRules, and the near-miss line's
// candidate thresholds: for each, which scores show the line, and what share
// of each tier band that is. Writes `medal_numbers.txt`.
//
//   DESIGN_MEASURE_OUT=docs/design/batch6 \
//     flutter test tool/design_measure/batch6/medal_numbers_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';

import '../layouts.dart' show outDir;

/// A month of [days] days: (year, month). 2026-02 has 28, 2028-02 has 29.
const _months = {28: (2026, 2), 29: (2028, 2), 30: (2026, 11), 31: (2026, 10)};

/// The next tier above [score] and the points still missing, or null at
/// Gold. What the card's near-miss line needs; not in the product today.
(MedalTier, int)? nextTier(int year, int month, int score) {
  for (final tier in MedalTier.values) {
    final t = MonthlyMedalRules.threshold(year, month, tier);
    if (score < t) return (tier, t - score);
  }
  return null;
}

void main() {
  test('medal_numbers.txt', () {
    const q = DailyTestSet.questionCount;
    const dayMin = q * MonthlyMedalRules.pointsPerWrong;
    const dayMax = q * MonthlyMedalRules.pointsPerCorrect;
    final lines = <String>[
      'Batch 6 Batch 0 §3: medal rule v${MonthlyMedalRules.ruleVersion} '
          '(MonthlyMedalRules), [Q] = $q',
      'A fully answered day is worth $dayMin (all wrong) to $dayMax (all '
          'correct) points; a skipped answer 0.',
      '',
      'days  max  Bronze  Silver  Gold  band (Bronze→Silver, Silver→Gold)',
    ];
    for (final days in _months.keys) {
      final (y, m) = _months[days]!;
      final t = {
        for (final tier in MedalTier.values)
          tier: MonthlyMedalRules.threshold(y, m, tier)
      };
      lines.add(
          '$days  ${MonthlyMedalRules.maxScore(y, m).toString().padLeft(4)}'
          '  ${t[MedalTier.bronze].toString().padLeft(6)}'
          '  ${t[MedalTier.silver].toString().padLeft(6)}'
          '  ${t[MedalTier.gold].toString().padLeft(4)}'
          '  ${t[MedalTier.silver]! - t[MedalTier.bronze]!}, '
          '${t[MedalTier.gold]! - t[MedalTier.silver]!}');
    }

    // The candidates: the line shows when 0 < gap ≤ limit.
    final candidates = <String, int Function(int y, int m)>{
      'A: gap ≤ $dayMin (one more fully answered day closes it, even all wrong)':
          (_, __) => dayMin,
      'B: gap ≤ $dayMax (one more day closes it if all correct)': (_, __) =>
          dayMax,
      'C: gap ≤ 5 % of the month\'s maximum': (y, m) =>
          (MonthlyMedalRules.maxScore(y, m) * 5) ~/ 100,
    };
    for (final name in candidates.keys) {
      lines.addAll(['', name]);
      for (final days in _months.keys) {
        final (y, m) = _months[days]!;
        final limit = candidates[name]!(y, m);
        final max = MonthlyMedalRules.maxScore(y, m);
        var shown = 0;
        int? prev;
        for (final tier in MedalTier.values) {
          final th = MonthlyMedalRules.threshold(y, m, tier);
          final from = th - limit;
          final bandStart = prev ?? 0;
          shown += th - from;
          lines.add('  $days days, below ${tier.label} ($th): line at '
              '$from–${th - 1} ($limit of ${th - bandStart} scores in the band, '
              '${(limit * 100 / (th - bandStart)).toStringAsFixed(0)} %)');
          prev = th;
        }
        lines.add('  $days days: limit $limit; '
            '${(shown * 100 / (max + 1)).toStringAsFixed(0)} % of all '
            'possible scores 0–$max show the line');
      }
    }
    lines.addAll([
      '',
      'Self-check of nextTier against MonthlyMedalRules.tierFor, every score '
          'of every month length:',
    ]);
    var checked = 0;
    for (final days in _months.keys) {
      final (y, m) = _months[days]!;
      for (var s = 0; s <= MonthlyMedalRules.maxScore(y, m); s++) {
        final tier = MonthlyMedalRules.tierFor(year: y, month: m, score: s);
        final next = nextTier(y, m, s);
        final expected = tier == null
            ? MedalTier.bronze
            : tier == MedalTier.gold
                ? null
                : MedalTier.values[tier.index + 1];
        expect(next?.$1, expected);
        checked++;
      }
    }
    lines.add('  $checked scores, all consistent.');
    File('${outDir()}/medal_numbers.txt')
        .writeAsStringSync('${lines.join('\n')}\n');
  });
}
