import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/app_links.dart';

/// Real, permanent regression test now that `AppLinks` is filled in (see
/// app_links.dart) — was a deliberately `skip`ped placeholder reminder
/// before real Privacy Policy / Terms of Service pages existed. See
/// scripts/preflight.sh for the release-build gate that checks the same
/// thing outside the test suite.
void main() {
  test('AppLinks URLs must be filled in before a real release build', () {
    expect(AppLinks.privacyPolicyUrl, isNotEmpty);
    expect(AppLinks.termsUrl, isNotEmpty);
  });
}
