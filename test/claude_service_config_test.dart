import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/services/claude_service.dart';

void main() {
  test(
    'a missing ANTHROPIC_API_KEY throws a message that says what to do, '
    'not just that it failed',
    () async {
      // This test suite runs without --dart-define=ANTHROPIC_API_KEY=...,
      // so AppConfig.isConfigured is false and this should fail before any
      // network call.
      await expectLater(
        ClaudeService().generatePracticeSet(kTopics.first),
        throwsA(
          isA<ClaudeApiException>().having(
            (e) => e.message,
            'message',
            allOf(contains('config/dev.json'), contains('README')),
          ),
        ),
      );
    },
  );
}
