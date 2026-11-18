import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/services/app_link.dart';
import 'package:grammar_lens/services/widget_payload.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart';

/// The fixtures `ios/RunnerTests/WidgetSnapshotTests.testDartFixtures`
/// renders: regenerate with `UPDATE_WIDGET_FIXTURES=true flutter test
/// test/widget_payload_test.dart`.
const _fixtures = 'test/fixtures/widget_payloads';

WidgetMonth _month({
  int year = 2026,
  int month = 11,
  int days = 30,
  String name = 'Ember Peak',
  String monthName = 'November',
}) =>
    WidgetMonth(
      year: year,
      month: month,
      days: days,
      mountainName: name,
      monthName: monthName,
      lightImage: 'mountain_ember_peak_d${days}_s1_light.png',
      darkImage: 'mountain_ember_peak_d${days}_s1_dark.png',
      avatarPoint: const Offset(0.36, 0.72),
    );

/// W01 v12's sample: a practice mistake with the scorer's rule (the
/// board's "I'm interested to learn French").
const _gerund = WidgetMistake(
  topicId: 'gerundVsInfinitive',
  errorType: 'gerund_after_preposition',
  prompt: 'Fill in the blank.\nI’m interested ___ French.',
  userAnswer: 'to learn',
  correctedAnswer: 'in learning',
  rule: 'After a preposition, use -ing',
);

/// A Daily Test mistake: no rule stored.
const _article = WidgetMistake(
  topicId: 'articles',
  errorType: 'articles',
  prompt: 'She is ___ best teacher in our school.',
  userAnswer: 'a',
  correctedAnswer: 'the',
);

/// An error correction with a long sentence.
const _long = WidgetMistake(
  topicId: 'tenseSelection',
  errorType: 'present_perfect_vs_past_simple',
  prompt: 'Correct the sentence.',
  userAnswer: 'Last summer my sister and I have visited our grandparents in '
      'the small village by the lake.',
  correctedAnswer: 'Last summer my sister and I visited our grandparents in '
      'the small village by the lake.',
  rule: 'Past simple with a finished time',
);

WidgetInput _input({
  DateTime? now,
  bool done = false,
  int steps = 1,
  int points = 18,
  List<WidgetMistake> mistakes = const [_gerund],
  WidgetMonth? month,
  WidgetMonth? nextMonth,
  bool rtl = false,
}) {
  final m = month ?? _month();
  return WidgetInput(
    now: now ?? DateTime(2026, 11, 18, 14, 30),
    userName: 'Ada',
    avatarImage: 'avatar_14.png',
    sleepImage: 'fox_sleep.png',
    dailyTestDone: done,
    stepsDone: steps,
    monthPoints: points,
    month: m,
    nextMonth: nextMonth ?? m,
    mistakes: mistakes,
    rtl: rtl,
  );
}

String _runs(Object? runs) => [
      for (final r in runs as List)
        (r as Map)['m'] == true ? '[${r['t']}]' : r['t'] as String
    ].join();

Object? _withoutTimes(Object? json) => switch (json) {
      Map() => {
          for (final e in json.entries)
            if (e.key != 'writtenAt' && e.key != 'validFrom')
              e.key: _withoutTimes(e.value),
        },
      List() => [for (final v in json) _withoutTimes(v)],
      _ => json,
    };

AppLocalizations _l10n([String code = 'en']) =>
    lookupAppLocalizations(Locale(code));

Map<String, dynamic> _climb(Map<String, Object?> payload, int entry) =>
    ((payload['entries'] as List)[entry] as Map)['climb']
        as Map<String, dynamic>;

Map<String, dynamic> _tip(Map<String, Object?> payload, int entry) =>
    ((payload['entries'] as List)[entry] as Map)['tip'] as Map<String, dynamic>;

void main() {
  group('climb, waiting (W01 small and medium A)', () {
    final payload = buildWidgetPayload(_input(), _l10n());
    final climb = _climb(payload, 0);

    test('the board\'s copy', () {
      expect(climb['state'], 'waiting');
      expect(climb['url'], 'grammarlens://daily-test');
      expect(climb['label'], 'DAILY TEST');
      expect(climb['title'], 'Step 2 is waiting');
      expect(climb['subtitle'], '5 questions · 2 min');
      expect(climb['stepBadge'], '1/30');
      expect(climb['mediumTitle'], 'Step 2 is one test away');
      expect(climb['mediumSubtitle'], 'Ember Peak · November · 1/30');
      expect(climb['chip'], 'Test waiting');
      expect(climb['button'], 'Start');
      expect(climb['countdown'], isEmpty);
    });

    test('images and the avatar point', () {
      expect(climb['images'], {
        'avatar': 'avatar_14.png',
        'mountainLight': 'mountain_ember_peak_d30_s1_light.png',
        'mountainDark': 'mountain_ember_peak_d30_s1_dark.png',
      });
      expect(climb['avatarPoint'], [0.36, 0.72]);
    });
  });

  group('climb, done', () {
    final payload =
        buildWidgetPayload(_input(done: true, steps: 2, points: 18), _l10n());
    final climb = _climb(payload, 0);

    test('the board\'s copy', () {
      expect(climb['state'], 'done');
      expect(climb['url'], 'grammarlens://home');
      expect(climb['label'], 'Done today');
      expect(climb['title'], 'Step 2 of 30');
      expect(climb['points'], '18');
      expect(climb['mediumTitle'], 'See you tomorrow, Ada');
      expect(climb['chip'], 'Done today');
    });

    test('a countdown line for every whole hour, 1 to 24', () {
      final countdown = climb['countdown'] as Map;
      expect(countdown.keys, [for (var h = 1; h <= 24; h++) '$h']);
      expect(countdown['10'], 'Next test in 10 h');
      expect(
          (climb['countdownMedium'] as Map)['10'], 'Next test in 10 h · 2/30');
    });
  });

  group('the midnight entry', () {
    test('starts at the next local midnight, always waiting, next step', () {
      final payload = buildWidgetPayload(
          _input(done: true, steps: 2, now: DateTime(2026, 11, 18, 23, 59)),
          _l10n());
      final entries = payload['entries'] as List;
      expect(entries, hasLength(2));
      expect((entries[1] as Map)['validFrom'],
          DateTime(2026, 11, 19).millisecondsSinceEpoch ~/ 1000);
      final climb = _climb(payload, 1);
      expect(climb['state'], 'waiting');
      expect(climb['title'], 'Step 3 is waiting');
      expect(climb['stepBadge'], '2/30');
      expect(_tip(payload, 1)['done'], isFalse);
    });

    test('not done today: the same step still waits after midnight', () {
      final payload = buildWidgetPayload(_input(steps: 4), _l10n());
      expect(_climb(payload, 0)['title'], 'Step 5 is waiting');
      expect(_climb(payload, 1)['title'], 'Step 5 is waiting');
    });

    test('a new month at midnight: its mountain, step 1, no points', () {
      final december = _month(
          month: 12, days: 31, name: 'Glacier Peak', monthName: 'December');
      final payload = buildWidgetPayload(
          _input(
              now: DateTime(2026, 11, 30, 21),
              done: true,
              steps: 30,
              nextMonth: december),
          _l10n());
      final climb = _climb(payload, 1);
      expect(climb['title'], 'Step 1 is waiting');
      expect(climb['stepBadge'], '0/31');
      expect(climb['mediumSubtitle'], 'Glacier Peak · December · 0/31');
      expect(climb['points'], '0');
      expect((climb['images'] as Map)['mountainLight'],
          'mountain_ember_peak_d31_s1_light.png');
    });

    test('the summit: the step never passes the month\'s days', () {
      final payload = buildWidgetPayload(_input(steps: 30), _l10n());
      expect(_climb(payload, 0)['title'], 'Step 30 is waiting');
    });
  });

  group('tip (W01 medium B, v12): the user\'s own mistake', () {
    test(
        'the latest mistake: the sentence with the wrong words struck and '
        'its correction, the rule with the corrected words in the pill', () {
      final tip = _tip(buildWidgetPayload(_input(), _l10n()), 0);
      final mistake = tip['mistake'] as Map;
      expect(_runs(mistake['wrong']), 'I’m interested [to learn] French.');
      expect(_runs(mistake['right']), 'I’m interested [in learning] French.');
      expect(tip['lead'], 'After a preposition, use -ing');
      expect(tip['rule'], 'in learning');
      expect(tip['example'], '');
      expect(tip['label'], 'GERUND VS. INFINITIVE');
      expect(tip['footer'], 'Your weak spot · a new one daily');
      expect(tip.containsKey('examples'), isFalse);
    });

    test('a new weak spot each day, in turn', () {
      final input = _input(mistakes: const [_gerund, _article, _long]);
      final day = localDayNumber(input.now);
      final labels = [
        for (var d = 0; d < 4; d++)
          _tip(
              buildWidgetPayload(
                  _input(
                      now: input.now.add(Duration(days: d)),
                      mistakes: const [_gerund, _article, _long]),
                  _l10n()),
              0)['label'],
      ];
      expect(labels.toSet(), hasLength(3));
      expect(labels[3], labels[0]);
      // The midnight entry is tomorrow's weak spot.
      final payload = buildWidgetPayload(input, _l10n());
      expect(_tip(payload, 1)['label'], isNot(_tip(payload, 0)['label']));
      expect(day, isPositive);
    });

    test(
        'the Daily Test stores no rule: the matching hint line, its key in '
        'the pill', () {
      final tip = _tip(
          buildWidgetPayload(_input(mistakes: const [_article]), _l10n()), 0);
      expect(tip['lead'], '');
      expect(tip['rule'], 'the');
      expect(tip['example'], 'specific, known, or the only one');
      expect(_runs((tip['mistake'] as Map)['wrong']),
          'She is [a] best teacher in our school.');
      expect(
          matchingHint(
              kTopics.firstWhere((t) => t.id == TopicId.gerundVsInfinitive),
              'in learning'),
          startsWith('+ -ing'));
    });

    test('a long sentence starts with "…" so its mistake stays in view', () {
      final tip =
          _tip(buildWidgetPayload(_input(mistakes: const [_long]), _l10n()), 0);
      final wrong = _runs((tip['mistake'] as Map)['wrong']);
      expect(wrong, startsWith('…'));
      expect(wrong, contains('I [have] visited'));
      expect(wrong.indexOf('['), lessThan(30));
      // Nothing changed in the correction but the word left out: no pill,
      // the scorer's rule alone.
      expect(_runs((tip['mistake'] as Map)['right']), isNot(contains('[')));
      expect(tip['rule'], '');
      expect(tip['lead'], 'Past simple with a finished time');
    });

    test('no weak spot yet: a topic hint\'s rule and two more lines', () {
      final tip =
          _tip(buildWidgetPayload(_input(mistakes: const []), _l10n()), 0);
      expect(tip['label'], startsWith('TIP OF THE DAY · '));
      expect(tip['footer'], 'A new tip every day');
      expect(tip['examples'], hasLength(2));
      expect(tip.containsKey('mistake'), isFalse);
      expect(tip['url'], 'grammarlens://daily-test');
      final all = kTopicHints.values.expand((l) => l).toSet();
      for (final line in tip['examples'] as List) {
        expect(all, contains(line));
      }
    });

    test(
        'taps: the weak spot (R03) and the box (Daily Test, or Home once '
        'done)', () {
      final waiting = _tip(buildWidgetPayload(_input(), _l10n()), 0);
      expect(
          waiting['url'],
          AppLink.weakSpotUrl(
              'gerundVsInfinitive', 'gerund_after_preposition'));
      expect(AppLink.weakSpotOf(waiting['url'] as String),
          const WeakSpotLink('gerundVsInfinitive', 'gerund_after_preposition'));
      expect(waiting['boxUrl'], 'grammarlens://daily-test');
      final done = _tip(buildWidgetPayload(_input(done: true), _l10n()), 0);
      expect(done['boxUrl'], 'grammarlens://home');
    });

    test('done: "Done", the hours to the next test and the companion asleep',
        () {
      final tip = _tip(buildWidgetPayload(_input(done: true), _l10n()), 0);
      expect(tip['done'], isTrue);
      expect(tip['doneLabel'], 'Done');
      expect((tip['next'] as Map)['10'], 'next in 10 h');
      expect((tip['next'] as Map), hasLength(24));
      expect(tip['boxImage'], 'fox_sleep.png');
      final waiting = _tip(buildWidgetPayload(_input(), _l10n()), 0);
      expect(waiting['boxImage'], 'avatar_14.png');
      expect(waiting['button'], 'Start');
    });

    test('general tips: one hint line a day, a line without ": " whole', () {
      final day = localDayNumber(DateTime(2026, 11, 18));
      final tip = widgetTipFor('articles', day);
      expect(tip.personal, isTrue);
      final lines = kTopicHints[TopicId.articles]!;
      expect('${tip.rule}: ${tip.example}', lines[day % lines.length]);
      expect(widgetTipFor('articles', day + 1).rule, isNot(tip.rule));
      final modal = kTopicHints[TopicId.modalVerbs]!;
      final index = modal.indexWhere((l) => !l.contains(': '));
      expect(widgetTipFor('modalVerbs', index).example, isEmpty);
      for (final weak in [null, 'notATopic']) {
        expect(widgetTipFor(weak, 7).personal, isFalse);
      }
    });
  });

  group('languages', () {
    test('Turkish: translated copy, topic names stay English', () {
      final payload = buildWidgetPayload(_input(), _l10n('tr'));
      expect(_climb(payload, 0)['title'], '2. adım seni bekliyor');
      // The topic stays English in capitals: "I", not "İ" (SPEC §3.7).
      expect(_tip(payload, 0)['label'], 'GERUND VS. INFINITIVE');
      expect(_tip(payload, 0)['footer'], 'Zayıf noktan · her gün bir yenisi');
      // The hint lines are English in every language (SPEC §3.7).
      final general =
          _tip(buildWidgetPayload(_input(mistakes: const []), _l10n('tr')), 0);
      expect(kTopicHints.values.expand((l) => l).join('\n'),
          contains(general['rule'] as String));
    });

    test('Arabic: right to left, Western digits', () {
      final payload =
          buildWidgetPayload(_input(rtl: true, done: true), _l10n('ar'));
      expect(payload['rtl'], isTrue);
      expect((_climb(payload, 0)['countdown'] as Map)['3'], contains('3'));
    });

    test('every language has every widget string', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final payload = buildWidgetPayload(
            _input(done: true), lookupAppLocalizations(locale));
        final climb = _climb(payload, 0);
        for (final key in ['label', 'title', 'mediumTitle', 'chip']) {
          expect(climb[key], isNotEmpty, reason: '$locale $key');
        }
      }
    });
  });

  group('widgetCrop', () {
    test('the avatar stays inside the crop and the crop inside the image', () {
      for (final days in [28, 29, 30, 31]) {
        final route = ClimbRoute(days);
        for (var day = 0; day <= days; day++) {
          final crop =
              widgetCrop(route.stepAt(day), imageAspect: climbImageAspect);
          final r = crop.rect;
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.top, greaterThanOrEqualTo(-1e-9));
          expect(r.right, lessThanOrEqualTo(1 + 1e-9));
          expect(r.bottom, lessThanOrEqualTo(1 + 1e-9));
          expect(crop.avatar.dx, inInclusiveRange(0, 1), reason: '$days/$day');
          expect(crop.avatar.dy, inInclusiveRange(0, 1), reason: '$days/$day');
        }
      }
    });

    test('the crop has the medium widget\'s shape', () {
      final crop =
          widgetCrop(const Offset(0.5, 0.6), imageAspect: climbImageAspect);
      final pixels = Size(crop.rect.width * 2172, crop.rect.height * 2896);
      expect(pixels.width / pixels.height, closeTo(widgetMediumAspect, 0.01));
    });

    test('in the middle of the image the avatar sits left of centre, low', () {
      final crop =
          widgetCrop(const Offset(0.5, 0.6), imageAspect: climbImageAspect);
      expect(crop.avatar.dx, closeTo(0.45, 1e-9));
      expect(crop.avatar.dy, closeTo(0.62, 1e-9));
    });
  });

  group('fixtures for the Swift snapshot test', () {
    final cases = <String, Map<String, Object?>>{
      'en_waiting': buildWidgetPayload(_input(), _l10n()),
      'en_done': buildWidgetPayload(_input(done: true, steps: 2), _l10n()),
      'tr_waiting': buildWidgetPayload(_input(mistakes: const []), _l10n('tr')),
      'en_daily_test':
          buildWidgetPayload(_input(mistakes: const [_article]), _l10n()),
      'en_long': buildWidgetPayload(
          _input(done: true, steps: 2, mistakes: const [_long]), _l10n()),
      'ar_done': buildWidgetPayload(
          _input(done: true, steps: 2, rtl: true), _l10n('ar')),
      'ar_done_late': buildWidgetPayload(
          _input(done: true, steps: 15, rtl: true), _l10n('ar')),
      'de_done': buildWidgetPayload(_input(done: true, steps: 15), _l10n('de')),
    };
    final update = Platform.environment['UPDATE_WIDGET_FIXTURES'] == 'true';
    for (final entry in cases.entries) {
      test(entry.key, () {
        final file = File('$_fixtures/${entry.key}.json');
        final text =
            '${const JsonEncoder.withIndent('  ').convert(entry.value)}\n';
        if (update) {
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(text);
        }
        // Timestamps depend on the machine's time zone; the rest must match.
        expect(_withoutTimes(jsonDecode(file.readAsStringSync())),
            _withoutTimes(jsonDecode(text)),
            reason: 'run with UPDATE_WIDGET_FIXTURES=true to refresh');
      });
    }
  });
}
