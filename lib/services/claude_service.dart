import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/topics.dart';
import '../models/daily_test_question.dart';
import '../models/error_entry.dart';
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
        // Allows direct browser calls to the Anthropic API, bypassing CORS.
        // Needed only for local prototype testing on web; mobile builds
        // (iOS/Android) don't hit CORS and don't need this header.
        'anthropic-dangerous-direct-browser-access': 'true',
      };

  Future<PracticeSet> generatePracticeSet(Topic topic, {int count = 5}) async {
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
              'context': {'type': 'string'},
              'instruction': {'type': 'string'},
              'hint': {'type': 'string'},
            },
            'required': ['id', 'type', 'instruction'],
            'additionalProperties': false,
          },
        },
      },
      'required': ['items'],
      'additionalProperties': false,
    };

    final body = {
      'model': _model,
      // Scaled off the 2048 baseline tuned for the original 5-item set, so
      // Extended (10 items) still has enough room to complete.
      'max_tokens': ((2048 * count) / 5).ceil().clamp(1024, 8192),
      'system': _generationSystemPrompt,
      'output_config': {
        'format': {'type': 'json_schema', 'schema': schema},
      },
      'messages': [
        {
          'role': 'user',
          'content': 'Topic: "${topic.title}" — ${topic.description}\n'
              'Generate exactly $count fresh practice items: '
              '${_itemMix(count)}. Each "id" must be a short unique slug.',
        },
      ],
    };

    final json = await _post(body);
    final items = (json['items'] as List)
        .map((e) => PracticeItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PracticeSet(topicId: topic.id.name, items: items);
  }

  /// Keeps the original 5-item set's 2:2:1 sentence_writing : error_correction
  /// : fill_in_blank ratio (writing-heavy — see the system prompt's note on
  /// production over recognition) at any requested [count].
  String _itemMix(int count) {
    final sentenceWriting = (count * 0.4).round();
    final errorCorrection = (count * 0.4).round();
    final fillInBlank = count - sentenceWriting - errorCorrection;
    return '$sentenceWriting sentence_writing, $errorCorrection '
        'error_correction, and $fillInBlank fill_in_blank';
  }

  /// Generates a Daily Test set (PRD v2 §12.5, §12.8) — [count] questions,
  /// each with its answer key and 2-3 predicted common wrong answers (with
  /// canned comments) generated up front so grading afterward is local and
  /// deterministic, no second API call. [weakSpots] is the device's local
  /// error profile (`StorageService.getWeakSpots`); an empty list means no
  /// profile yet (new user), which asks for a general/varied mix instead
  /// of biasing toward anything.
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
    // Not `const`: the topicId enum below is built from `kTopics`, which a
    // const map literal can't express.
    final schema = {
      'type': 'object',
      'properties': {
        'questions': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              // Fixed-answer types only (PRD v2 §12.5) — sentence_writing
              // has no single correct answer to check deterministically
              // against, and multiple-choice is off the table entirely
              // (docs/prd.md §2.2 Theme 1).
              'type': {
                'type': 'string',
                'enum': ['fill_in_blank', 'error_correction'],
              },
              'context': {'type': 'string'},
              'instruction': {'type': 'string'},
              'hint': {'type': 'string'},
              'topicId': {
                'type': 'string',
                'enum': [for (final topic in kTopics) topic.id.name],
              },
              'correctAnswer': {'type': 'string'},
              'commonWrongAnswers': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'answer': {'type': 'string'},
                    'comment': {'type': 'string'},
                  },
                  'required': ['answer', 'comment'],
                  'additionalProperties': false,
                },
              },
            },
            'required': [
              'id',
              'type',
              'instruction',
              'topicId',
              'correctAnswer',
              'commonWrongAnswers',
            ],
            'additionalProperties': false,
          },
        },
      },
      'required': ['questions'],
      'additionalProperties': false,
    };

    final body = {
      'model': _model,
      'max_tokens': ((2048 * count) / 5).ceil().clamp(1024, 8192),
      'system': _dailyTestSystemPrompt,
      'output_config': {
        'format': {'type': 'json_schema', 'schema': schema},
      },
      'messages': [
        {
          'role': 'user',
          'content': _dailyTestUserPrompt(count, weakSpots),
        },
      ],
    };

    final json = await _post(body);
    return (json['questions'] as List)
        .map((e) => DailyTestQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ranks topics by how often each appears in [weakSpots] (summed across
  /// its error types) and asks for questions biased toward the most
  /// frequent first; an empty profile asks for general variety instead.
  String _dailyTestUserPrompt(int count, List<WeakSpot> weakSpots) {
    if (weakSpots.isEmpty) {
      return 'Generate exactly $count Daily Test questions. This user has '
          'no practice history yet, so cover a varied general mix across '
          'these topics: ${kTopics.map((t) => t.title).join(', ')}.';
    }

    final frequencyByTopic = <String, int>{};
    for (final weakSpot in weakSpots) {
      frequencyByTopic[weakSpot.topicId] =
          (frequencyByTopic[weakSpot.topicId] ?? 0) + weakSpot.frequency;
    }
    final rankedTopicTitles = (frequencyByTopic.keys.toList()
          ..sort(
            (a, b) => frequencyByTopic[b]!.compareTo(frequencyByTopic[a]!),
          ))
        .map((id) => topicById(TopicId.values.byName(id)).title);

    return 'Generate exactly $count Daily Test questions. Bias topic '
        "selection toward this user's most frequent error categories, most "
        'frequent first: ${rankedTopicTitles.join(', ')}. Still include some '
        'variety rather than every question targeting the same topic.';
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
              'prompt': item.fullText,
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
    final feedback = (json['feedback'] as List).map((e) {
      final map = e as Map<String, dynamic>;
      final userAnswer = answers[map['itemId'] as String] ?? '';
      return ItemFeedback.fromJson(map, isSkipped: userAnswer.trim().isEmpty);
    }).toList();
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
Keep each item self-contained and unambiguous.

Each item's text is split into two fields, shown to the learner as two
visually separate blocks: "context" sets the scene (a scenario, background,
or — for error_correction — the flawed sentence itself), and "instruction"
is the short, direct task the learner must actually perform. Keep
"instruction" as one concise sentence. Leave "context" empty only when the
item is simple enough to stand alone as a single instruction (e.g. a short
fill_in_blank sentence with nothing to set up).

Weight practice toward production, not recognition: most learners at this
level can already understand the target structure — their struggle is
producing it themselves. For sentence_writing items, put a realistic
situation in "context" (e.g. talking about weekend plans, describing a past
job) and the actual task in "instruction" — for example:
context: "You are writing an email to a colleague about a project deadline
that is approaching."
instruction: "Using 'should' or 'must', write one sentence explaining what
you or your team needs to do before the deadline."
Never ask the learner to just copy, translate, or complete a template.

For error_correction items, put a sentence containing exactly one grammar
mistake in "context", and in "instruction" tell the learner what format to
answer in, e.g. "Find the mistake and rewrite the full corrected sentence."
Always ask for the full rewritten sentence, not just the fixed word or
phrase.

Return only the structured output — no extra commentary.
''';

  static const _dailyTestSystemPrompt = '''
You are an IELTS grammar coach generating a free, no-login "Daily Test" for
a Turkish native speaker at B1-C1 English level — one fixed set of
fill_in_blank and error_correction items, checked entirely offline against
the answer key you provide now (no further model call happens). Getting
the answer key right matters more than usual: whatever you write in
"correctAnswer" is compared, after trimming/case/whitespace normalization,
directly against the learner's typed answer, with no human or model
judgment in between.

Follow the same "context" (scene-setting) / "instruction" (the direct task)
split, and the same production-over-recognition weighting, as regular
practice generation. For fill_in_blank, "correctAnswer" is the exact word
or short phrase that fills the blank. For error_correction, put the single
flawed sentence in "context" and require the full corrected sentence back
in "instruction" — "correctAnswer" must then be that full rewritten
sentence, in the same form a learner would actually type it (not a
fragment), since matching is exact after normalization, not semantic.

For each item, also predict 2-3 common wrong answers a learner at this
level plausibly gives — real mistakes (a tense slip, a preposition swap, a
half-corrected sentence), not random noise — each as a full answer string
in the same shape as "correctAnswer" would be typed, paired with a short
(1 sentence) "comment" in plain, friendly language explaining why it's
tempting and what's actually wrong, the same non-technical tone regular
scoring explanations use. These are shown verbatim if the learner's answer
matches that prediction, so write them as if speaking directly to the
learner ("you" / "your"), not about them.

Return only the structured output — no extra commentary.
''';

  static const _scoringSystemPrompt = '''
You are an IELTS grammar coach scoring a learner's practice answers. For each
item, judge correctness, give the corrected version, and a short (1-2
sentence) explanation a B1-C1 learner can act on.

Lead the explanation with plain language: describe what sounds wrong and
what sounds more natural, the way a fluent friend would, not a textbook.
Avoid grammar terminology in the explanation where possible — e.g. say "the
timing word doesn't match the rest of the sentence" rather than opening with
a term like "Past Perfect Continuous". Separately, still name the specific
grammar rule in the "rule" field and be precise and consistent about the
"errorType" slug (e.g. "gerund_vs_infinitive", "modal_past_form") so it can
be tracked over time — these are secondary/reference detail, not the
headline of the explanation.

For error_correction items specifically, grade the grammar, not the format.
If the learner correctly identifies and fixes the target mistake but writes
only the corrected word/phrase instead of the full rewritten sentence, still
mark isCorrect: true — they demonstrated the grammar knowledge being tested.
In that case, append a short, friendly note to the end of the explanation:
"Right fix — next time write out the full sentence for practice." Only mark
isCorrect: false on an error_correction item when the grammatical correction
itself is wrong, incomplete (e.g. it missed a second error in the sentence),
or introduces a new mistake.

Some items will have an empty userAnswer because the learner left them
blank. Still give your best correctedAnswer and a short explanation of what
was expected for these — that reference content is shown to the learner
regardless. But don't try to phrase isCorrect or errorType around "blank" in
any special way; the app detects blank answers itself from the raw input and
ignores your isCorrect/errorType values for those items, so just score them
as you would any wrong answer.
''';
}
