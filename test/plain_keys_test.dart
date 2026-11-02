import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/data/fallback_pool.dart';
import 'package:grammar_lens/utils/answer_matching.dart';

/// The client-side twin of the proxy gate's `correct_answer_not_plain` rule
/// (1.4.0 D3; B3): every bundled key and accepted answer is plain under the
/// keyboard fold, so the keyboard-variant branch only ever moves a
/// learner's answer towards a key.
void main() {
  test('day-0 and fallback-pool keys and accepted answers fold to themselves',
      () {
    final pool =
        FallbackPool.parse(File(FallbackPool.assetPath).readAsStringSync())
            .expand((set) => set);
    final notPlain = <String>[];
    for (final q in [...kDayZeroQuestions, ...pool]) {
      for (final answer in [q.correctAnswer, ...q.acceptedAnswers]) {
        final normalized = normalizeAnswer(answer);
        if (foldKeyboardVariants(normalized) != normalized) {
          notPlain.add('${q.item.id}: $answer');
        }
      }
    }
    expect(notPlain, isEmpty);
  });
}
