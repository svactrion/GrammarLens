import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/services/claude_service.dart';

void main() {
  test(
    'a missing proxy configuration tells the user practice is unavailable, '
    'with no developer setup steps (audit #7)',
    () async {
      // This test suite runs without --dart-define=PROXY_BASE_URL=...
      // /APP_TOKEN=..., so AppConfig.isConfigured is false and this should
      // fail before any network call. The setup steps go to the debug log.
      await expectLater(
        ClaudeService()
            .generatePracticeSet(kTopics.first, deviceId: 'test-device'),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.kind, 'kind', ClaudeApiErrorKind.notConfigured)
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('not available right now'),
                  isNot(contains('config/')),
                  isNot(contains('README')),
                  isNot(contains('scripts/')),
                ),
              ),
        ),
      );
    },
  );

  group('userFacingErrorMessage', () {
    test('a ClaudeApiException shows its own message, never the class name',
        () {
      const error = ClaudeApiException(
        "Couldn't reach the practice service. Check your connection and "
        'try again.',
        kind: ClaudeApiErrorKind.network,
      );
      expect(userFacingErrorMessage(error), error.message);
      expect(userFacingErrorMessage(error), isNot(contains('Exception')));
    });

    test('any other error shows a general line, not its toString()', () {
      final message = userFacingErrorMessage(StateError('db is closed'));
      expect(message, 'Something went wrong. Please try again.');
      expect(message, isNot(contains('StateError')));
      expect(message, isNot(contains('db is closed')));
    });
  });
}
