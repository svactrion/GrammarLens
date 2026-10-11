import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/fallback_pool.dart';
import 'package:grammar_lens/utils/blanks.dart';

/// The one blank rule (question screen plan, B3): two or more underscores,
/// counted in the context and then the instruction, shared by the Daily
/// Test's gate and Practice's answer boxes.
void main() {
  test('a run of two or more underscores is one blank', () {
    expect(blankCount(null, 'I enjoy __ and ____ and _______.'), 3);
    expect(blankCount(null, 'snake_case is not a blank'), 0);
    expect(blankCount(null, 'No blank here.'), 0);
  });

  test('counts the context and the instruction, not across them', () {
    expect(blankCount('She is ____ engineer.', 'Fill in ____ blanks.'), 2);
    // A run ending the context and one starting the instruction stay two.
    expect(blankCount('Ends with __', '__ starts here'), 2);
  });

  test('FallbackPool.blankCount is the same rule', () {
    for (final (context, instruction) in [
      (null, 'I enjoy ____.'),
      ('A __ and a ___.', 'Fill them in.'),
      ('No blank.', 'None here either.'),
    ]) {
      expect(FallbackPool.blankCount(context, instruction),
          blankCount(context, instruction));
    }
  });
}
