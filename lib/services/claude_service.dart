import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/daily_test_question.dart';
import '../models/error_entry.dart';
import '../models/item_feedback.dart';
import '../models/practice_item.dart';
import '../models/practice_set.dart';
import '../models/scoring_result.dart';
import '../models/topic.dart';

/// What kind of failure a [ClaudeApiException] represents — lets a screen
/// special-case the ones that need it (quota-exceeded shouldn't say "check
/// your connection") without every call site needing to know the proxy's
/// error-code strings.
enum ClaudeApiErrorKind {
  /// AppConfig.isConfigured is false — a local dev-setup problem, not a
  /// runtime one.
  notConfigured,
  /// The HTTP request to the proxy itself failed (no connectivity, DNS,
  /// timeout, ...) — never reached the proxy's own error handling.
  network,
  unauthorized,
  invalidRequest,
  quotaExceeded,
  /// Anthropic (or the proxy itself) failed for any other reason. The
  /// proxy's own raw error detail never reaches here by design — see
  /// proxy/src/anthropic.ts.
  upstream,
}

class ClaudeApiException implements Exception {
  final String message;
  final ClaudeApiErrorKind kind;
  const ClaudeApiException(this.message, {this.kind = ClaudeApiErrorKind.upstream});

  @override
  String toString() => 'ClaudeApiException: $message';
}

/// Talks to the GrammarLens Cloudflare Workers proxy (`proxy/`) to
/// generate practice sets/Daily Test questions and score answers — never
/// to Anthropic directly. The model, system prompts, schemas, and the
/// Anthropic API key itself all live server-side now (docs/build-log.md);
/// this class only ever sends an operation name and the small structured
/// payload each one actually needs, and reads back the same
/// already-parsed JSON shape Anthropic used to return directly.
class ClaudeService {
  final http.Client _client;
  // Overridable only so tests can exercise the "configured, talking to a
  // (mocked) proxy" path deterministically — AppConfig's fields are
  // compile-time consts read via --dart-define, which a normal `flutter
  // test` run can't set per-file. Every real call site keeps using the
  // AppConfig defaults; only tests pass these explicitly.
  final String _proxyBaseUrl;
  final String _appToken;

  ClaudeService({http.Client? client, String? proxyBaseUrl, String? appToken})
      : _client = client ?? http.Client(),
        _proxyBaseUrl = proxyBaseUrl ?? AppConfig.proxyBaseUrl,
        _appToken = appToken ?? AppConfig.appToken;

  bool get _isConfigured => _proxyBaseUrl.isNotEmpty && _appToken.isNotEmpty;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'x-grammarlens-token': _appToken,
      };

  Uri _uri(String path) => Uri.parse('$_proxyBaseUrl$path');

  /// [deviceId] is an anonymous, app-generated identifier (see
  /// `StorageService.getOrCreateDeviceId`) — the proxy uses it only to
  /// enforce a per-device daily quota, never to identify a person or a
  /// real device attribute.
  Future<PracticeSet> generatePracticeSet(
    Topic topic, {
    required String deviceId,
    int count = 5,
  }) async {
    final json = await _post('/v1/generate-practice-set', {
      'deviceId': deviceId,
      'topicId': topic.id.name,
      'count': count,
    });
    final items = (json['items'] as List)
        .map((e) => PracticeItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PracticeSet(topicId: topic.id.name, items: items);
  }

  /// [weakSpots] is the device's local error profile
  /// (`StorageService.getWeakSpots`); only `topicId`/`frequency` travel to
  /// the proxy — the ranking-to-prompt-text logic (previously
  /// `_dailyTestUserPrompt` here) now lives server-side, same as every
  /// other piece of prompt text.
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
    final json = await _post('/v1/generate-daily-test', {
      'deviceId': deviceId,
      'count': count,
      'weakSpots': [
        for (final spot in weakSpots)
          {'topicId': spot.topicId, 'frequency': spot.frequency},
      ],
    });
    return (json['questions'] as List)
        .map((e) => DailyTestQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ScoringResult> scoreAnswers({
    required String deviceId,
    required PracticeSet practiceSet,
    required Map<String, String> answers,
  }) async {
    final itemsPayload = practiceSet.items
        .map((item) => {
              'id': item.id,
              'type': item.type.toJson(),
              'prompt': item.fullText,
              'userAnswer': answers[item.id] ?? '',
            })
        .toList();

    final json = await _post('/v1/score-answers', {
      'deviceId': deviceId,
      'items': itemsPayload,
    });

    final feedback = (json['feedback'] as List).map((e) {
      final map = e as Map<String, dynamic>;
      final userAnswer = answers[map['itemId'] as String] ?? '';
      return ItemFeedback.fromJson(map, isSkipped: userAnswer.trim().isEmpty);
    }).toList();
    return ScoringResult(topicId: practiceSet.topicId, feedback: feedback);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    if (!_isConfigured) {
      throw const ClaudeApiException(
        'The practice service is not configured. Copy '
        'config/dev.example.json to config/dev.json, fill in the proxy '
        'URL and app token, and run via scripts/dev.sh. See the "Local '
        'setup" section in README.md.',
        kind: ClaudeApiErrorKind.notConfigured,
      );
    }

    http.Response response;
    try {
      response = await _client.post(_uri(path), headers: _headers, body: jsonEncode(body));
    } catch (_) {
      throw const ClaudeApiException(
        "Couldn't reach the practice service. Check your connection and "
        'try again.',
        kind: ClaudeApiErrorKind.network,
      );
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    // The proxy's own clean error envelope (`{error, message}`) — never
    // Anthropic's raw body, which never reaches this far by design (see
    // proxy/src/anthropic.ts). Reusing its `message` here rather than
    // re-writing equivalent copy on the client keeps that text in one
    // place.
    Map<String, dynamic>? errorJson;
    try {
      errorJson = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      errorJson = null;
    }

    final code = errorJson?['error'] as String?;
    final kind = switch (code) {
      'unauthorized' => ClaudeApiErrorKind.unauthorized,
      'invalid_request' => ClaudeApiErrorKind.invalidRequest,
      'quota_exceeded' => ClaudeApiErrorKind.quotaExceeded,
      _ => ClaudeApiErrorKind.upstream,
    };
    final message = errorJson?['message'] as String? ??
        'Something went wrong (${response.statusCode}). Please try again.';

    throw ClaudeApiException(message, kind: kind);
  }
}
