import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:grammar_lens/data/topics.dart';
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

      expect(captured!.url.toString(),
          'https://proxy.test/v1/generate-practice-set');
      expect(captured!.headers['x-grammarlens-token'], 'test-token');
      final sentBody =
          jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
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

  group('fetchSharedDailyTest', () {
    Map<String, dynamic> question(String id) => {
          'id': id,
          'type': 'fill_in_blank',
          'context': 'She ___ to work.',
          'instruction': 'Fill it.',
          'topicId': 'articles',
          'correctAnswer': 'the',
          'explanation': 'Why.',
          'commonWrongAnswers': [
            {'answer': 'a', 'comment': 'c'},
          ],
        };
    String body(String date, [List<Object?>? questions]) => jsonEncode({
          'date': date,
          'promptVersion': 2,
          'questions': questions ?? [question('q1'), question('q2')],
        });

    test(
        'is a GET of the date\'s route with only the app token: no body, '
        'no device id, nothing about the user', () async {
      final requests = <http.BaseRequest>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(body('2026-10-01'), 200);
      });

      final result =
          await serviceWith(client).fetchSharedDailyTest('2026-10-01');

      final request = requests.single as http.Request;
      expect(request.method, 'GET');
      expect(request.url.toString(),
          'https://proxy.test/v1/shared-daily-test/2026-10-01');
      expect(request.body, isEmpty);
      expect(request.headers['x-grammarlens-token'], 'test-token');
      expect(request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('content-type')));
      expect(result!.map((q) => q.item.id), ['q1', 'q2']);
      expect(result.first.explanation, 'Why.');
    });

    test('a 404 (not published yet, or outside the window) is null', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'error': 'not_found',
            'message': 'No shared Daily Test for this date.'
          }),
          404));
      expect(
          await serviceWith(client).fetchSharedDailyTest('2026-10-01'), isNull);
    });

    test('a 404 without the envelope is null too', () async {
      final client = MockClient((_) async => http.Response('', 404));
      expect(
          await serviceWith(client).fetchSharedDailyTest('2026-10-01'), isNull);
    });

    test('acceptedAnswers in a question are kept', () async {
      final client = MockClient((_) async => http.Response(
          body('2026-10-01', [
            {
              ...question('q1'),
              'acceptedAnswers': ['that']
            }
          ]),
          200));
      final result =
          await serviceWith(client).fetchSharedDailyTest('2026-10-01');
      expect(result!.single.acceptedAnswers, ['that']);
    });

    final unusable = <String, http.Response>{
      'a 5xx': http.Response(
          jsonEncode({'error': 'upstream_error', 'message': 'x'}), 500),
      'a body that is not JSON': http.Response('<html>oops', 200),
      'JSON that is not an object': http.Response('[]', 200),
      'a set for another date': http.Response(body('2026-10-02'), 200),
      'a set without questions': http.Response(body('2026-10-01', []), 200),
      'questions that are not a list': http.Response(
          jsonEncode({'date': '2026-10-01', 'questions': 'x'}), 200),
      'a question missing a required field': http.Response(
          body('2026-10-01', [
            {...question('q1')}..remove('correctAnswer')
          ]),
          200),
      'a question that is not an object':
          http.Response(body('2026-10-01', ['q1']), 200),
      'a question of an unsupported type': http.Response(
          body('2026-10-01', [
            {...question('q1'), 'type': 'sentence_writing'}
          ]),
          200),
    };
    unusable.forEach((name, response) {
      test('$name throws a ClaudeApiException', () async {
        final client = MockClient((_) async => response);
        await expectLater(
          serviceWith(client).fetchSharedDailyTest('2026-10-01'),
          throwsA(isA<ClaudeApiException>()),
        );
      });
    });

    test('no connection throws a network ClaudeApiException', () async {
      final client = MockClient((_) async => throw Exception('socket'));
      await expectLater(
        serviceWith(client).fetchSharedDailyTest('2026-10-01'),
        throwsA(isA<ClaudeApiException>()
            .having((e) => e.kind, 'kind', ClaudeApiErrorKind.network)),
      );
    });

    test('a missing configuration throws before any request', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(body('2026-10-01'), 200);
      });
      await expectLater(
        ClaudeService(client: client, proxyBaseUrl: '', appToken: '')
            .fetchSharedDailyTest('2026-10-01'),
        throwsA(isA<ClaudeApiException>()
            .having((e) => e.kind, 'kind', ClaudeApiErrorKind.notConfigured)),
      );
      expect(calls, 0);
    });

    test('the read times out after 10 seconds by default', () {
      expect(ClaudeService.sharedSetTimeout, const Duration(seconds: 10));
    });

    test('a read that never answers fails as a network error, not a hang',
        () async {
      final neverAnswers = Completer<http.Response>();
      final service = ClaudeService(
        client: MockClient((_) => neverAnswers.future),
        proxyBaseUrl: 'https://proxy.test',
        appToken: 'test-token',
        // Only the shared read's own limit: the generation limit stays long.
        sharedSetTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        service.fetchSharedDailyTest('2026-10-01'),
        throwsA(isA<ClaudeApiException>()
            .having((e) => e.kind, 'kind', ClaudeApiErrorKind.network)),
      );
    });
  });

  test(
      'the client has no way to ask for a per-device Daily Test: the legacy '
      'route appears nowhere in lib/ (docs/1.1.0-shared-daily-test.md §13)',
      () {
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('generate-daily-test'))
          f.path,
    ];
    expect(offenders, isEmpty);
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

      final sentBody =
          jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
      expect(sentBody['items'], [
        {
          'id': 'q1',
          'type': 'fill_in_blank',
          'prompt': 'I saw ___ cat.',
          'userAnswer': 'the'
        },
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
      final client = MockClient(
          (request) async => http.Response(jsonEncode(body), status));
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

    test(
        '429 quota_exceeded maps to ClaudeApiErrorKind.quotaExceeded, using '
        "the proxy's own message text", () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': 'quota_exceeded',
            'scope': 'device',
            'message':
                "You've reached today's practice limit on this device. Please try again tomorrow.",
          }),
          429,
        ),
      );

      await expectLater(
        serviceWith(client).generatePracticeSet(kTopics.first, deviceId: 'd1'),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.kind, 'kind', ClaudeApiErrorKind.quotaExceeded)
              .having(
                  (e) => e.message, 'message', contains('try again tomorrow')),
        ),
      );
    });

    test(
        '502 upstream_error maps to ClaudeApiErrorKind.upstream, never '
        "leaking Anthropic's own detail (the proxy already stripped it)", () {
      return expectMapped(
        status: 502,
        body: {
          'error': 'upstream_error',
          'message': 'The upstream service returned an error.'
        },
        kind: ClaudeApiErrorKind.upstream,
      );
    });

    test('a malformed (non-JSON) error body still produces a usable exception',
        () async {
      final client =
          MockClient((request) async => http.Response('not json', 500));
      await expectLater(
        serviceWith(client).generatePracticeSet(kTopics.first, deviceId: 'd1'),
        throwsA(isA<ClaudeApiException>()
            .having((e) => e.kind, 'kind', ClaudeApiErrorKind.upstream)),
      );
    });

    test(
        'a transport failure (e.g. no connectivity) maps to '
        'ClaudeApiErrorKind.network, not upstream', () async {
      final client =
          MockClient((request) async => throw Exception('socket error'));
      await expectLater(
        serviceWith(client).generatePracticeSet(kTopics.first, deviceId: 'd1'),
        throwsA(isA<ClaudeApiException>()
            .having((e) => e.kind, 'kind', ClaudeApiErrorKind.network)),
      );
    });
  });

  group('request timeout', () {
    ClaudeService withTimeout(http.Client client, Duration timeout) =>
        ClaudeService(
          client: client,
          proxyBaseUrl: 'https://proxy.test',
          appToken: 'test-token',
          requestTimeout: timeout,
        );

    test('the default is 40 seconds', () {
      expect(ClaudeService.defaultRequestTimeout, const Duration(seconds: 40));
    });

    test('a request that never answers fails as a network error, not a hang',
        () async {
      final neverAnswers = Completer<http.Response>();
      final client = MockClient((_) => neverAnswers.future);

      await expectLater(
        withTimeout(client, const Duration(milliseconds: 50))
            .generatePracticeSet(kTopics.first, deviceId: 'device-1'),
        throwsA(isA<ClaudeApiException>()
            .having((e) => e.kind, 'kind', ClaudeApiErrorKind.network)
            .having((e) => e.message, 'message', contains('too long'))),
      );
    });

    test('a request that answers in time is unaffected', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response(jsonEncode({'items': []}), 200);
      });

      final result = await withTimeout(client, const Duration(seconds: 5))
          .generatePracticeSet(kTopics.first, deviceId: 'device-1');

      expect(result.items, isEmpty);
    });
  });
}
