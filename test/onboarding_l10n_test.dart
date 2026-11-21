import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_set.dart';

import 'support/l10n_support.dart';

/// Welcome's "Five questions a day." (UI polish V02; 1.4.0 B4.2 for the
/// onboarding line it replaces) spells out the Daily Test's question count.
/// The ARB holds the word, so this test is what keeps the line from
/// drifting from the real test.
void main() {
  test('the Welcome subtitle matches DailyTestSet.questionCount', () {
    expect(DailyTestSet.questionCount, 5,
        reason: 'Update welcomeSubtitle in every ARB file.');
    expect(en.welcomeSubtitle, startsWith('Five questions a day.'));
  });
}
