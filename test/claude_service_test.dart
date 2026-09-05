import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/services/claude_service.dart';

/// Exercises ClaudeService's actual transport/parsing logic against a
/// mocked proxy (MockClient), rather than only the "not configured" path
/// claude_service_config_test.dart covers — proxyBaseUrl/appToken are
/// injected directly since AppConfig's fields are compile-time consts a
/// plain `flutter test` run can't set per-file (see ClaudeService's own
/// constructor doc comment).
void main() {
  ClaudeService serviceWith(http.Client client) => ClaudeService(
        client: client,
        proxyBaseUrl: 'https://proxy.test',
        appToken: 'test-token',
      );

  group('generatePracticeSet', () {
    test('posts the small structured payload, not a raw Anthropic request',
        () async {
      http.BaseRequest? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'q1', 'type': 'fill_in_blank', 'instruction': 'Fill it.'},
            ],
          }),
          200,
        );
      });

      final result = await serviceWith(client)
          .generatePracticeSet(kTopics.first, deviceId: 'device-1', count: 5);

      expect(captured!.url.toString(), 'https://proxy.test/v1/generate-practice-set');
      expect(captured!.headers['x-grammarlens-token'], 'test-token');
      final sentBody = jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
      expect(sentBody, {
        'deviceId': 'device-1',
        'topicId': kTopics.first.id.name,
        'count': 5,
      });

      expect(result.items, hasLength(1));
      expect(result.items.single.id, 'q1');
      expect(result.topicId, kTopics.first.id.name);
    });
  });

  group('generateDailyTestQuestions', () {
    test('sends only topicId/frequency for each weak spot', () async {
      http.BaseRequest? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'questions': [
              {
                'id': 'q1',
                'type': 'fill_in_blank',
                'instruction': 'Fill it.',
                'topicId': 'articles',
                'correctAnswer': 'the',
                'commonWrongAnswers': [],
              },
            ],
          }),
          200,
        );
      });

      final result = await serviceWith(client).generateDailyTestQuestions(
        deviceId: 'device-1',
        count: 5,
        weakSpots: [
          WeakSpot(
            topicId: 'articles',
            errorType: 'missing_article',
            frequency: 3,
            lastSeen: DateTime(2026, 1, 1),
          ),
        ],
      );

      final sentBody = jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
      expect(sentBody['weakSpots'], [
        {'topicId': 'articles', 'frequency': 3},
      ]);
      expect(result, hasLength(1));
    });
  });

  group('scoreAnswers', () {
    test('sends id/type/prompt/userAnswer per item and parses feedback',
        () async {
      const practiceSet = PracticeSet(
        topicId: 'articles',
        items: [
          PracticeItem(
            id: 'q1',
            type: PracticeItemType.fillInBlank,
            instruction: 'I saw ___ cat.',
          ),
        ],
      );

      http.BaseRequest? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'feedback': [
              {
                'itemId': 'q1',
                'isCorrect': true,
                'correctedAnswer': 'the cat',
                'explanation': 'Looks right.',
              },
            ],
          }),
          200,
        );
      });

      final result = await serviceWith(client).scoreAnswers(
        deviceId: 'device-1',
        practiceSet: practiceSet,
        answers: {'q1': 'the'},
      );

      final sentBody = jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
      expect(sentBody['items'], [
        {'id': 'q1', 'type': 'fill_in_blank', 'prompt': 'I saw ___ cat.', 'userAnswer': 'the'},
      ]);
      expect(result.feedback.single.isCorrect, isTrue);
      expect(result.topicId, 'articles');
    });
  });

  group('error mapping', () {
    Future<void> expectMapped({
      required int status,
      required Map<String, dynamic> body,
      required ClaudeApiErrorKind kind,
    }) async {
      final client = MockClient((request) async => http.Response(jsonEncode(body), status));
      await expectLater(
        serviceWith(client).generatePracticeSet(kTopics.first, deviceId: 'd1'),
        throwsA(isA<ClaudeApiException>().having((e) => e.kind, 'kind', kind)),
      );
    }

    test('401 unauthorized maps to ClaudeApiErrorKind.unauthorized', () {
      return expectMapped(
        status: 401,
        body: {'error': 'unauthorized', 'message': 'nope'},
        kind: ClaudeApiErrorKind.unauthorized,
      );
    });

    test('400 invalid_request maps to ClaudeApiErrorKind.invalidRequest', () {
      return expectMapped(
        status: 400,
        body: {'error': 'invalid_request', 'message': 'bad shape'},
        kind: ClaudeApiErrorKind.invalidRequest,
      );
    });

    test('429 quota_exceeded maps to ClaudeApiErrorKind.quotaExceeded, using '
        "the proxy's own message text", () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': 'quota_exceeded',
            'scope': 'device',
            'message': "You've reached today's practice limit on this device. Please try again tomorrow.",
          }),
          429,
        ),
      );

      await expectLater(
        serviceWith(client).generatePracticeSet(kTopics.first, deviceId: 'd1'),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.kind, 'kind', ClaudeApiErrorKind.quotaExceeded)
              .having((e) => e.message, 'message', contains('try again tomorrow')),
        ),
      );
    });

    test('502 upstream_error maps to ClaudeApiErrorKind.upstream, never '
        "leaking Anthropic's own detail (the proxy already stripped it)",
        () {
      return expectMapped(
        status: 502,
        body: {'error': 'upstream_error', 'message': 'The upstream service returned an error.'},
        kind: ClaudeApiErrorKind.upstream,
      );
    });

    test('a malformed (non-JSON) error body still produces a usable exception',
        () async {
      final client = MockClient((request) async => http.Response('not json', 500));
      await expectLater(
        serviceWith(client).generatePracticeSet(kTopics.first, deviceId: 'd1'),
        throwsA(isA<ClaudeApiException>().having((e) => e.kind, 'kind', ClaudeApiErrorKind.upstream)),
      );
    });

    test('a transport failure (e.g. no connectivity) maps to '
        'ClaudeApiErrorKind.network, not upstream', () async {
      final client = MockClient((request) async => throw Exception('socket error'));
      await expectLater(
        serviceWith(client).generatePracticeSet(kTopics.first, deviceId: 'd1'),
        throwsA(isA<ClaudeApiException>().having((e) => e.kind, 'kind', ClaudeApiErrorKind.network)),
      );
    });
  });
}
