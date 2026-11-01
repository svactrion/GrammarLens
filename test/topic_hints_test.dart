import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/data/fallback_pool.dart';
import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/topic.dart';

/// B2 (1.4.0; owner, 2026-11-02): the hint card leaves out an example verb
/// the question itself uses (the Gerund vs. Infinitive verb lists only).
void main() {
  String textOf(DailyTestQuestion q) =>
      [q.item.fullText, q.item.hint ?? ''].join('\n');

  const gerund = TopicId.gerundVsInfinitive;
  final full = kTopicHints[gerund]!;

  group('the recorded case (2026-10-16)', () {
    test('"You should avoid ___ too much sugar." drops "avoid"', () {
      final day0 = kDayZeroQuestions.first;
      expect(day0.item.context, 'You should avoid ___ too much sugar.');
      expect(hintPointsFor(gerund, textOf(day0)), [
        '+ -ing: enjoy, finish, keep',
        full[1],
        full[2],
        full[3],
      ]);
    });
  });

  group('the bundled questions', () {
    final pool =
        FallbackPool.parse(File(FallbackPool.assetPath).readAsStringSync())
            .expand((set) => set)
            .toList();
    final bundled = [...kDayZeroQuestions, ...pool];

    // Six, not the Batch 0 report's five: its count matched exact words
    // only, and missed "wants" (fb02_5) and "decided" (fb05_5).
    test('six Gerund vs. Infinitive cards change, nothing else', () {
      final changed = <String>[];
      for (final q in bundled) {
        final topic = TopicId.values.byName(q.topicId);
        final points = hintPointsFor(topic, textOf(q));
        if (topic != gerund) {
          expect(points, kTopicHints[topic], reason: q.item.id);
        } else if (!_listEquals(points!, full)) {
          changed.add(q.item.id);
        }
      }
      expect(changed,
          ['day0_1', 'fb02_5', 'fb03_3', 'fb04_5', 'fb05_5', 'fb07_2']);
    });

    test('the five pool cards read as expected', () {
      final expected = {
        // "wants" and "decided" are in the scene: harmless, one rule.
        'decided to avoid': ['+ -ing: enjoy, finish, keep', '+ to: hope, plan'],
        'really enjoys': ['+ -ing: avoid, finish, keep', full[1]],
        'I avoid to drive': ['+ -ing: enjoy, finish, keep', full[1]],
        'really enjoy ___ to true crime': [
          '+ -ing: avoid, finish, keep',
          full[1],
        ],
        // "I decided ___ (ask)": the card named the deciding verb under
        // "+ to"; "stopped" in the scene drops "stop" too.
        'I decided ___ (ask)': [full[0], '+ to: want, hope, plan'],
      };
      for (final MapEntry(key: phrase, value: lines) in expected.entries) {
        final q = pool.singleWhere((q) => textOf(q).contains(phrase));
        final points = hintPointsFor(gerund, textOf(q))!;
        expect(points.take(2), lines, reason: phrase);
        expect(points.last, full.last, reason: phrase);
      }
    });

    test('every other day-0 card is unchanged', () {
      for (final q in kDayZeroQuestions.skip(1)) {
        final topic = TopicId.values.byName(q.topicId);
        expect(hintPointsFor(topic, textOf(q)), kTopicHints[topic],
            reason: q.item.id);
      }
    });
  });

  group('the rule', () {
    test('matches inflected forms', () {
      String first(String text) => hintPointsFor(gerund, text)![0];
      expect(first('She avoids ___ the topic.'), '+ -ing: enjoy, finish, keep');
      expect(
          first('He finished ___ the report.'), '+ -ing: enjoy, avoid, keep');
      expect(first('They kept ___ all night.'), '+ -ing: enjoy, avoid, finish');
      expect(
          first('We are keeping ___ quiet.'), '+ -ing: enjoy, avoid, finish');
      expect(hintPointsFor(gerund, 'He stopped ___ to answer.')![2],
          'Meaning changes: remember, try');
      expect(hintPointsFor(gerund, 'She tried ___ the lid.')![2],
          'Meaning changes: stop, remember');
      expect(hintPointsFor(gerund, 'I am deciding ___ now.')![1],
          '+ to: want, hope, plan');
      expect(hintPointsFor(gerund, 'We planned ___ early.')![1],
          '+ to: want, decide, hope');
    });

    test('whole words only, case-insensitive', () {
      expect(hintPointsFor(gerund, 'The KEEPER ___ the ball.'), full);
      expect(hintPointsFor(gerund, 'ENJOY ___ it.')![0],
          '+ -ing: avoid, finish, keep');
    });

    test('a line that loses every example keeps its label', () {
      expect(hintPointsFor(gerund, 'enjoy avoid finish keep')![0], '+ -ing');
    });

    test('the preposition line never changes', () {
      expect(hintPointsFor(gerund, 'After a preposition, always')![3], full[3]);
    });

    test('other topics are returned as they are', () {
      for (final topic in TopicId.values.where((t) => t != gerund)) {
        final all = kTopicHints[topic]!.join(' ');
        expect(hintPointsFor(topic, all), kTopicHints[topic]);
      }
    });
  });
}

bool _listEquals(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
