import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/data/fallback_pool.dart';
import 'package:grammar_lens/models/daily_test_completion.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/utils/answer_matching.dart';

/// A question in the asset's shape, valid unless a test changes it.
Map<String, dynamic> _question(String id, String topicId,
        {String type = 'fill_in_blank'}) =>
    type == 'fill_in_blank'
        ? {
            'id': id,
            'type': 'fill_in_blank',
            'context': 'She ___ to work every day.',
            'instruction': 'Fill in the blank with the verb in brackets.',
            'hint': '(go)',
            'topicId': topicId,
            'correctAnswer': 'goes',
            'explanation': 'A routine with "she" takes the present simple -s.',
            'commonWrongAnswers': [
              {'answer': 'go', 'comment': 'With "she" the verb needs -s.'},
              {'answer': 'is going', 'comment': 'That is for right now.'},
            ],
          }
        : {
            'id': id,
            'type': 'error_correction',
            'context': 'She go to work every day.',
            'instruction': 'Correct the sentence.',
            'topicId': topicId,
            'correctAnswer': 'She goes to work every day.',
            'explanation': 'A routine with "she" takes the present simple -s.',
            'commonWrongAnswers': [
              {
                'answer': 'She go to work every day.',
                'comment': 'That is the sentence unchanged.'
              },
              {
                'answer': 'She going to work every day.',
                'comment': 'That needs "is".'
              },
            ],
          };

const _topics = [
  'gerundVsInfinitive',
  'modalVerbs',
  'modalPastForms',
  'tenseSelection',
  'articles',
];

Map<String, dynamic> _set(String prefix) => {
      'questions': [
        for (var i = 0; i < 5; i++)
          _question('${prefix}_${i + 1}', _topics[i],
              type: i < 3 ? 'fill_in_blank' : 'error_correction'),
      ],
    };

String _pool(List<Map<String, dynamic>> sets, {int version = 1}) =>
    jsonEncode({'formatVersion': version, 'sets': sets});

/// Serves one string for the pool asset, or throws like a missing asset.
class _Bundle extends CachingAssetBundle {
  final String? content;
  int loads = 0;
  _Bundle(this.content);

  @override
  Future<ByteData> load(String key) async {
    loads++;
    expect(key, FallbackPool.assetPath);
    if (content == null) throw Exception('Unable to load asset: $key');
    return ByteData.sublistView(utf8.encode(content!));
  }
}

void main() {
  group('rotation by date', () {
    test('the same day always gets the same set', () {
      final first = FallbackPool.indexFor('2026-10-02', 7);
      for (var i = 0; i < 5; i++) {
        expect(FallbackPool.indexFor('2026-10-02', 7), first);
      }
    });

    test('seven consecutive days get seven different sets, then it repeats',
        () {
      final days = [
        for (var d = 1; d <= 8; d++) '2026-10-${d.toString().padLeft(2, '0')}',
      ];
      final picks = days.map((d) => FallbackPool.indexFor(d, 7)!).toList();
      expect(picks.take(7).toSet(), hasLength(7));
      expect(picks[7], picks[0]);
    });

    test('the rotation runs on across month, year and leap-day ends', () {
      int step(String a, String b) =>
          (FallbackPool.indexFor(b, 7)! - FallbackPool.indexFor(a, 7)!) % 7;
      expect(step('2026-10-31', '2026-11-01'), 1);
      expect(step('2026-12-31', '2027-01-01'), 1);
      expect(step('2028-02-28', '2028-02-29'), 1);
      expect(step('2028-02-29', '2028-03-01'), 1);
    });

    test('pinned values, so the rotation cannot drift between builds', () {
      // 2026-10-01 is day 20727 since 1970-01-01.
      expect(FallbackPool.indexFor('2026-10-01', 7), 20727 % 7);
      expect(FallbackPool.indexFor('2026-10-01', 3), 20727 % 3);
      expect(FallbackPool.indexFor('1970-01-01', 7), 0);
    });

    test('an empty pool or a malformed day picks nothing', () {
      expect(FallbackPool.indexFor('2026-10-01', 0), isNull);
      expect(FallbackPool.indexFor('2026-13-01', 7), isNull);
      expect(FallbackPool.indexFor('2026-02-30', 7), isNull);
      expect(FallbackPool.indexFor('20261001', 7), isNull);
    });
  });

  group('questionsFor', () {
    final sets = [
      for (var n = 1; n <= 7; n++)
        FallbackPool.parse(_pool([_set('fb0$n')])).single,
    ];

    test('picks the rotated set for the day, ignoring any origin date', () {
      final pool = FallbackPool.withSets(sets);
      for (final day in ['2026-10-01', '2026-10-02', '2027-03-15']) {
        final index = FallbackPool.indexFor(day, 7)!;
        expect(pool.questionsFor(day), completion(same(sets[index])));
      }
    });

    test('an empty pool gives the day-0 questions', () {
      expect(FallbackPool.withSets(const []).questionsFor('2026-10-01'),
          completion(same(kDayZeroQuestions)));
    });

    for (final (name, content) in [
      ('a missing asset', null),
      ('an asset that is not JSON', '{"formatVersion": 1, "sets": ['),
      ('an asset of another format version', _pool([_set('fb01')], version: 2)),
      ('an asset without a list of sets', '{"formatVersion": 1, "sets": {}}'),
      (
        'an asset whose only set is broken',
        _pool([_set('fb01')..['questions'] = []])
      ),
      ('an asset with no sets', _pool([])),
    ]) {
      test('$name gives the day-0 questions, never an error', () async {
        final bundle = _Bundle(content);
        final pool = FallbackPool(bundle: bundle);
        expect(await pool.questionsFor('2026-10-01'), same(kDayZeroQuestions));
        // Read once, then remembered.
        await pool.questionsFor('2026-10-02');
        expect(bundle.loads, 1);
      });
    }

    test('a readable asset is used', () async {
      final pool = FallbackPool(bundle: _Bundle(_pool([_set('fb01')])));
      final questions = await pool.questionsFor('2026-10-01');
      expect(questions.map((q) => q.item.id).first, 'fb01_1');
    });
  });

  group('parse and the set check', () {
    test('a valid set is kept, in order', () {
      final sets = FallbackPool.parse(_pool([_set('fb01'), _set('fb02')]));
      expect(sets, hasLength(2));
      expect(sets[1].map((q) => q.item.id),
          ['fb02_1', 'fb02_2', 'fb02_3', 'fb02_4', 'fb02_5']);
    });

    test('the day-0 questions pass the same check', () {
      expect(FallbackPool.problemWithSet(kDayZeroQuestions), isNull);
    });

    final broken = <String, (String, void Function(Map<String, dynamic>))>{
      'four questions': (
        'wrong_question_count',
        (s) => (s['questions'] as List).removeLast()
      ),
      'a repeated id': (
        'duplicate_id',
        (s) => (s['questions'] as List)[1]['id'] = 'fb01_1'
      ),
      'a repeated topic': (
        'topic_mismatch',
        (s) => (s['questions'] as List)[1]['topicId'] = 'gerundVsInfinitive'
      ),
      'an unknown topic': (
        'topic_mismatch',
        (s) => (s['questions'] as List)[0]['topicId'] = 'phrasalVerbs'
      ),
      'fill_in_blank without a blank': (
        'fill_in_blank_missing_blank',
        (s) => (s['questions'] as List)[0]['context'] = 'She goes to work.'
      ),
      'fill_in_blank with a blank only in the hint': (
        'fill_in_blank_missing_blank',
        (s) => (s['questions'] as List)[0]
          ..['context'] = 'Complete it.'
          ..['hint'] = '___'
      ),
      'fill_in_blank with two blanks': (
        'fill_in_blank_multiple_blanks',
        (s) => (s['questions'] as List)[0]['instruction'] = 'Fill ___ in.'
      ),
      'fill_in_blank with a single underscore only': (
        'fill_in_blank_missing_blank',
        (s) => (s['questions'] as List)[0]['context'] = 'She _ to work.'
      ),
      'error_correction without its sentence': (
        'error_correction_missing_sentence',
        (s) => (s['questions'] as List)[3]['context'] = 'Fix it'
      ),
      'error_correction whose key is the sentence': (
        'unchanged_error_correction',
        (s) => (s['questions'] as List)[3]['correctAnswer'] =
            'She go to work every day.'
      ),
      'a sentence_writing question': (
        'plan_mismatch',
        (s) => (s['questions'] as List)[0]['type'] = 'sentence_writing'
      ),
      'no explanation': (
        'missing_field',
        (s) => (s['questions'] as List)[0].remove('explanation')
      ),
      'one predicted wrong answer': (
        'wrong_answer_count',
        (s) => ((s['questions'] as List)[0]['commonWrongAnswers'] as List)
            .removeLast()
      ),
      'a predicted wrong answer that grades as the key': (
        'wrong_answer_matches_correct',
        (s) => ((s['questions'] as List)[0]['commonWrongAnswers'] as List)[0]
            ['answer'] = 'Goes.'
      ),
      'a predicted wrong answer that is a keyboard variant of the key': (
        'wrong_answer_matches_correct',
        (s) => ((s['questions'] as List)[1]['commonWrongAnswers'] as List)[0]
            ['answer'] = 'göes'
      ),
      'the same wrong answer twice': (
        'duplicate_wrong_answer',
        (s) => ((s['questions'] as List)[0]['commonWrongAnswers'] as List)[1]
            ['answer'] = 'go'
      ),
      'a blank key': (
        'blank_correct_answer',
        (s) => (s['questions'] as List)[0]['correctAnswer'] = ' . '
      ),
      'an accepted answer that is also a predicted wrong answer': (
        'wrong_answer_matches_correct',
        (s) => (s['questions'] as List)[0]['acceptedAnswers'] = ['is going']
      ),
    };
    broken.forEach((name, rule) {
      final (code, breakIt) = rule;
      test('$name is rejected ($code) and only that set is left out', () {
        final bad = _set('fb01');
        breakIt(bad);
        final questions = (bad['questions'] as List)
            .map((q) => q as Map<String, dynamic>)
            .toList();
        List<DailyTestQuestion>? parsed;
        try {
          parsed = questions.map(DailyTestQuestion.fromJson).toList();
        } catch (_) {
          parsed = null;
        }
        if (parsed != null) {
          expect(FallbackPool.problemWithSet(parsed), code);
        }
        final sets = FallbackPool.parse(_pool([bad, _set('fb02')]));
        expect(sets.single.first.item.id, 'fb02_1');
      });
    });

    group('acceptedAnswers (owner corrections, roadmap P13)', () {
      List<DailyTestQuestion> withAccepted() {
        final set = _set('fb01');
        (set['questions'] as List)[0]['acceptedAnswers'] = [
          "'s going",
          'does go',
        ];
        return FallbackPool.parse(_pool([set])).single;
      }

      test('are read from the pool asset', () {
        final questions = withAccepted();
        expect(questions[0].acceptedAnswers, ["'s going", 'does go']);
        expect(
            questions.skip(1).every((q) => q.acceptedAnswers.isEmpty), isTrue);
      });

      test('a matching answer grades as accepted and counts as correct', () {
        final question = withAccepted()[0];
        for (final answer in ["'s going", 'Does go.', '  DOES   GO ']) {
          final match = checkDailyTestAnswer(question, answer);
          expect(match.kind, AnswerMatchKind.accepted, reason: answer);
          final result = DailyTestAnswerResult.from(question, answer);
          expect(result.isCorrect, isTrue, reason: answer);
        }
        expect(checkDailyTestAnswer(question, 'goes').kind,
            AnswerMatchKind.correct);
        expect(checkDailyTestAnswer(question, 'go').kind,
            AnswerMatchKind.commonWrong);
        expect(checkDailyTestAnswer(question, 'went').kind,
            AnswerMatchKind.fallback);
      });

      test('an accepted answer counts in the score and never in the errors',
          () {
        final questions = withAccepted();
        final answers = {
          for (final q in questions) q.item.id: q.correctAnswer,
          questions[0].item.id: 'does go',
        };
        expect(computeDailyTestScore(questions, answers).correct, 5);
        final results = [
          for (final q in questions)
            DailyTestAnswerResult.from(q, answers[q.item.id]),
        ];
        expect(results.where((r) => !r.isCorrect), isEmpty);
      });
    });

    test('a file that is not a pool throws', () {
      expect(() => FallbackPool.parse('[]'), throwsFormatException);
      expect(() => FallbackPool.parse('{"sets": []}'), throwsFormatException);
    });
  });

  group('the shipped asset (${FallbackPool.assetPath})', () {
    final raw = jsonDecode(File(FallbackPool.assetPath).readAsStringSync())
        as Map<String, dynamic>;
    final rawSets = (raw['sets'] as List).cast<Map<String, dynamic>>();

    test('is a pool of the current format', () {
      expect(raw.keys.toSet(), {'formatVersion', 'sets'});
      expect(raw['formatVersion'], FallbackPool.formatVersion);
    });

    test('holds no sets yet, or the owner\'s 7', () {
      expect(rawSets.length, anyOf(0, 7));
    });

    test('every set passes the check: none would be silently left out', () {
      final parsed =
          FallbackPool.parse(File(FallbackPool.assetPath).readAsStringSync());
      expect(parsed, hasLength(rawSets.length));
    });

    test('ids are fbNN_i, unique across the pool', () {
      final ids = [
        for (final set in rawSets)
          for (final q in set['questions'] as List) q['id'] as String,
      ];
      expect(ids.toSet(), hasLength(ids.length));
      for (final (n, set) in rawSets.indexed) {
        final prefix = 'fb${(n + 1).toString().padLeft(2, '0')}_';
        for (final q in set['questions'] as List) {
          expect(q['id'], startsWith(prefix));
        }
      }
    });

    test('sets carry no origin fields (date, generatedAt, attempt, ...)', () {
      for (final set in rawSets) {
        expect(set.keys.toSet(), {'questions'});
      }
    });

    test(
        'every accepted answer grades as accepted, and no predicted wrong '
        'answer does', () {
      final parsed =
          FallbackPool.parse(File(FallbackPool.assetPath).readAsStringSync());
      for (final q in parsed.expand((set) => set)) {
        for (final answer in q.acceptedAnswers) {
          expect(checkDailyTestAnswer(q, answer).kind, AnswerMatchKind.accepted,
              reason: '${q.item.id}: $answer');
        }
        for (final wrong in q.commonWrongAnswers) {
          expect(checkDailyTestAnswer(q, wrong.answer).kind,
              AnswerMatchKind.commonWrong,
              reason: '${q.item.id}: ${wrong.answer}');
        }
      }
    });

    test('the loader reads it from the app bundle', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final sets = await FallbackPool().sets();
      expect(sets, hasLength(rawSets.length));
    });
  });

  test(
      'the export script only ever reads KV: no put, delete, bulk or list '
      'command, and its one wrangler call is a key get', () {
    final script = File('scripts/fallback_pool.sh').readAsStringSync();
    final code = script
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('#'))
        .join('\n');
    final wrangler = RegExp(r'wrangler[^\n]*').allMatches(code).toList();
    expect(wrangler, hasLength(1));
    expect(wrangler.single[0], contains('kv key get'));
    expect(code, isNot(matches(RegExp(r'\b(put|delete|bulk|list)\b'))));
  });
}
