import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/item_feedback.dart';
import '../models/practice_item.dart';
import '../models/practice_set.dart';
import '../models/scoring_result.dart';
import '../models/topic.dart';

class ClaudeApiException implements Exception {
  final String message;
  const ClaudeApiException(this.message);

  @override
  String toString() => 'ClaudeApiException: $message';
}

/// Talks to the Anthropic Messages API to generate practice sets and score
/// answers, using structured JSON output (PRD §7).
///
/// The API key is read at build/run time via `--dart-define=ANTHROPIC_API_KEY=...`
/// so it never lands in source control. Calling the API directly from the
/// client embeds the key in the app binary — acceptable for this local
/// prototype with a handful of known testers, but move this behind a small
/// backend before distributing more widely.
class ClaudeService {
  static const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';
  static const _apiVersion = '2023-06-01';

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'x-api-key': _apiKey,
        'anthropic-version': _apiVersion,
      };

  Future<PracticeSet> generatePracticeSet(Topic topic) async {
    const schema = {
      'type': 'object',
      'properties': {
        'items': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'type': {
                'type': 'string',
                'enum': ['fill_in_blank', 'error_correction', 'sentence_writing'],
              },
              'prompt': {'type': 'string'},
              'hint': {'type': 'string'},
            },
            'required': ['id', 'type', 'prompt'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['items'],
      'additionalProperties': false,
    };

    final body = {
      'model': _model,
      'max_tokens': 2048,
      'system': _generationSystemPrompt,
      'output_config': {
        'format': {'type': 'json_schema', 'schema': schema},
      },
      'messages': [
        {
          'role': 'user',
          'content': 'Topic: "${topic.title}" — ${topic.description}\n'
              'Generate 5 fresh practice items mixing fill_in_blank, '
              'error_correction, and sentence_writing types. Each "id" must '
              'be a short unique slug.',
        },
      ],
    };

    final json = await _post(body);
    final items = (json['items'] as List)
        .map((e) => PracticeItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PracticeSet(topicId: topic.id.name, items: items);
  }

  Future<ScoringResult> scoreAnswers({
    required PracticeSet practiceSet,
    required Map<String, String> answers,
  }) async {
    const schema = {
      'type': 'object',
      'properties': {
        'feedback': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'itemId': {'type': 'string'},
              'isCorrect': {'type': 'boolean'},
              'errorType': {'type': 'string'},
              'rule': {'type': 'string'},
              'correctedAnswer': {'type': 'string'},
              'explanation': {'type': 'string'},
            },
            'required': ['itemId', 'isCorrect', 'correctedAnswer', 'explanation'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['feedback'],
      'additionalProperties': false,
    };

    final itemsPayload = practiceSet.items
        .map((item) => {
              'id': item.id,
              'type': item.type.toJson(),
              'prompt': item.prompt,
              'userAnswer': answers[item.id] ?? '',
            })
        .toList();

    final body = {
      'model': _model,
      'max_tokens': 2048,
      'system': _scoringSystemPrompt,
      'output_config': {
        'format': {'type': 'json_schema', 'schema': schema},
      },
      'messages': [
        {
          'role': 'user',
          'content': jsonEncode({'items': itemsPayload}),
        },
      ],
    };

    final json = await _post(body);
    final feedback = (json['feedback'] as List)
        .map((e) => ItemFeedback.fromJson(e as Map<String, dynamic>))
        .toList();
    return ScoringResult(topicId: practiceSet.topicId, feedback: feedback);
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    if (_apiKey.isEmpty) {
      throw const ClaudeApiException(
        'ANTHROPIC_API_KEY is not set. Run with '
        '--dart-define=ANTHROPIC_API_KEY=your_key',
      );
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw ClaudeApiException(
        'Claude API error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['content'] as List;
    final text = content.firstWhere(
      (block) => block['type'] == 'text',
    )['text'] as String;
    return jsonDecode(text) as Map<String, dynamic>;
  }

  static const _generationSystemPrompt = '''
You are an IELTS grammar coach generating practice exercises for a Turkish
native speaker at B1-C1 English level. Write natural, exam-relevant sentences.
Keep each item self-contained and unambiguous. Return only the structured
output — no extra commentary.
''';

  static const _scoringSystemPrompt = '''
You are an IELTS grammar coach scoring a learner's practice answers. For each
item, judge correctness, name the specific grammar rule involved, give the
corrected version, and a short (1-2 sentence) explanation a B1-C1 learner can
act on. Be precise and consistent about the error type (e.g.
"gerund_vs_infinitive", "modal_past_form") so it can be tracked over time.
''';
}
