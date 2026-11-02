import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_set.dart';

import 'support/l10n_support.dart';

/// 1.4.0 B4.2: onboarding's "Five questions a day." spells out the Daily
/// Test's question count. The ARB holds the word, so this test is what
/// keeps the line from drifting from the real test (the old number-word
/// table did it in code).
void main() {
  test('the subtitle matches DailyTestSet.questionCount', () {
    expect(DailyTestSet.questionCount, 5,
        reason: 'Update onboardingCompanionSubtitle in every ARB file.');
    expect(en.onboardingCompanionSubtitle,
        'Five questions a day. A small step forward, together.');
  });
}
