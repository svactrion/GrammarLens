import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/services/claude_service.dart';

void main() {
  test(
    'a missing proxy configuration throws a message that says what to do, '
    'not just that it failed',
    () async {
      // This test suite runs without --dart-define=PROXY_BASE_URL=...
      // /APP_TOKEN=..., so AppConfig.isConfigured is false and this should
      // fail before any network call.
      await expectLater(
        ClaudeService().generatePracticeSet(kTopics.first, deviceId: 'test-device'),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.kind, 'kind', ClaudeApiErrorKind.notConfigured)
              .having(
                (e) => e.message,
                'message',
                allOf(contains('config/dev.json'), contains('README')),
              ),
        ),
      );
    },
  );
}
