import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/daily_test_question.dart';
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
  const ClaudeApiException(this.message,
      {this.kind = ClaudeApiErrorKind.upstream});

  @override
  String toString() => 'ClaudeApiException: $message';
}

/// Talks to the GrammarLens Cloudflare Workers proxy (`proxy/`) to
/// generate practice sets, read the shared Daily Test set and score
/// answers — never
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
  final Duration _requestTimeout;
  final Duration _sharedSetTimeout;

  /// How long one request to the proxy may take before it is given up as
  /// failed. Without a limit a request that never answers would leave a
  /// screen loading forever (the Daily Test's first load included). Generation
  /// is the slow call; the proxy's `duration_ms` log is what shows whether this
  /// leaves enough room for a 10-question session.
  static const Duration defaultRequestTimeout = Duration(seconds: 40);

  /// How long the shared Daily Test read may take. It is a KV read at the
  /// edge, not a generation, so it is far shorter than
  /// [defaultRequestTimeout]: past it the Daily Test opens on its fallback
  /// instead of keeping the learner waiting
  /// (docs/1.1.0-shared-daily-test.md §5).
  static const Duration sharedSetTimeout = Duration(seconds: 10);

  ClaudeService({
    http.Client? client,
    String? proxyBaseUrl,
    String? appToken,
    Duration? requestTimeout,
    Duration? sharedSetTimeout,
  })  : _client = client ?? http.Client(),
        _proxyBaseUrl = proxyBaseUrl ?? AppConfig.proxyBaseUrl,
        _appToken = appToken ?? AppConfig.appToken,
        _requestTimeout = requestTimeout ?? defaultRequestTimeout,
        _sharedSetTimeout = sharedSetTimeout ?? ClaudeService.sharedSetTimeout;

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

  /// The shared Daily Test set for [date] (`YYYY-MM-DD`, the app's local day
  /// key), or null when the proxy has none for that date (a 404: not yet
  /// published, outside the serving window, or the feature switched off).
  ///
  /// A read, not a generation: `GET /v1/shared-daily-test/{date}` never
  /// reaches Anthropic and never touches quota, and the request carries
  /// nothing but the date and the app token — no device id, nothing about
  /// the user (docs/1.1.0-shared-daily-test.md §6, §7). Every other failure
  /// (no connection, [sharedSetTimeout], a 5xx, a body that is not a usable
  /// set for this date) throws a [ClaudeApiException]; the caller decides
  /// what to show instead.
  ///
  /// 1.1.0 has no per-device generation: the legacy per-device Daily Test
  /// route is kept on the proxy for 1.0.0 only, and this client has no
  /// method that calls it (§13, decision 2; a test checks that its path
  /// appears nowhere in `lib/`).
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async {
    final response = await _send(
      () => _client.get(
        _uri('/v1/shared-daily-test/${Uri.encodeComponent(date)}'),
        headers: {'x-grammarlens-token': _appToken},
      ),
      _sharedSetTimeout,
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) _throwProxyError(response);
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['date'] != date) {
        throw const FormatException('the set is for another date');
      }
      final questions = (json['questions'] as List)
          .map((e) => DailyTestQuestion.fromJson(e as Map<String, dynamic>))
          .toList();
      if (questions.isEmpty) throw const FormatException('no questions');
      return questions;
    } catch (_) {
      throw const ClaudeApiException(
        "The shared Daily Test couldn't be read.",
        kind: ClaudeApiErrorKind.upstream,
      );
    }
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

  Future<Map<String, dynamic>> _post(
          String path, Map<String, dynamic> body) async =>
      _decodeOk(await _send(
        () =>
            _client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
        _requestTimeout,
      ));

  /// Sends one request with [timeout], mapping a missing configuration, a
  /// timeout or a transport failure to a [ClaudeApiException]. Any HTTP
  /// response, whatever its status, is returned as is.
  Future<http.Response> _send(
      Future<http.Response> Function() request, Duration timeout) async {
    if (!_isConfigured) {
      throw const ClaudeApiException(
        'The practice service is not configured. Copy '
        'config/dev.example.json to config/dev.json, fill in the proxy '
        'URL and app token, and run via scripts/dev.sh. See the "Local '
        'setup" section in README.md.',
        kind: ClaudeApiErrorKind.notConfigured,
      );
    }

    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw const ClaudeApiException(
        'The practice service took too long to respond. Please try again.',
        kind: ClaudeApiErrorKind.network,
      );
    } catch (_) {
      throw const ClaudeApiException(
        "Couldn't reach the practice service. Check your connection and "
        'try again.',
        kind: ClaudeApiErrorKind.network,
      );
    }
  }

  /// The body of a 200 response, or the proxy's error mapped to a
  /// [ClaudeApiException].
  Map<String, dynamic> _decodeOk(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    _throwProxyError(response);
  }

  /// Maps a non-200 response to a [ClaudeApiException].
  Never _throwProxyError(http.Response response) {
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
