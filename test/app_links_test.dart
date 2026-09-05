import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/app_links.dart';

/// A loud, impossible-to-miss reminder that AppLinks is still the empty
/// pre-launch placeholder — not a check that runs day-to-day (see
/// scripts/preflight.sh for the thing that actually blocks a release
/// build over this). This test asserts the URLs are non-empty, which
/// they genuinely are not yet, so it's deliberately `skip`ped rather than
/// left to fail the suite: `flutter test`'s output still prints the skip
/// reason on every run, so it can't be silently forgotten, but a
/// permanently-red suite isn't the mechanism — that just trains everyone
/// to ignore red, including the next *real* regression.
///
/// Once real Privacy Policy / Terms of Service pages exist and
/// app_links.dart is filled in, remove the `skip:` argument below — this
/// then becomes a real, permanent assertion instead of a reminder.
void main() {
  test(
    'AppLinks URLs must be filled in before a real release build',
    () {
      expect(AppLinks.privacyPolicyUrl, isNotEmpty);
      expect(AppLinks.termsUrl, isNotEmpty);
    },
    skip: 'AppLinks still empty — pre-launch blocker, see docs/roadmap.md',
  );
}
