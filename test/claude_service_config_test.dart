import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/services/claude_service.dart';

import 'support/l10n_support.dart';

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
      expect(userFacingErrorMessage(error, en), error.message);
      expect(userFacingErrorMessage(error, en), isNot(contains('Exception')));
    });

    test(
        'a reason the app knows shows the app\'s sentence; the proxy\'s message '
        'is the fallback (1.4.0 B4.7)', () {
      String shown(ClaudeApiErrorReason reason, {int? status}) =>
          userFacingErrorMessage(
              ClaudeApiException('server text',
                  reason: reason, statusCode: status),
              en);
      expect(shown(ClaudeApiErrorReason.timeout),
          'The practice service took too long to respond. Please try again.');
      expect(
          shown(ClaudeApiErrorReason.unreachable),
          "Couldn't reach the practice service. Check your connection and "
          'try again.');
      expect(shown(ClaudeApiErrorReason.notConfigured),
          'Practice is not available right now. Please try again later.');
      expect(
          shown(ClaudeApiErrorReason.quotaDevice),
          "You've reached today's practice limit on this device. Please try "
          'again tomorrow.');
      expect(
          shown(ClaudeApiErrorReason.quotaGlobal),
          'GrammarLens has reached its overall limit for today. Please try '
          'again tomorrow.');
      expect(shown(ClaudeApiErrorReason.serverStatus, status: 503),
          'Something went wrong (503). Please try again.');
      expect(shown(ClaudeApiErrorReason.server), 'server text');
    });

    test('any other error shows a general line, not its toString()', () {
      final message = userFacingErrorMessage(StateError('db is closed'), en);
      expect(message, 'Something went wrong. Please try again.');
      expect(message, isNot(contains('StateError')));
      expect(message, isNot(contains('db is closed')));
    });
  });
}
