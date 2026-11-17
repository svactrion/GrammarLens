import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/topic.dart';
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

WidgetInput _input({
  DateTime? now,
  bool done = false,
  int steps = 1,
  int points = 18,
  String? weak = 'articles',
  WidgetMonth? month,
  WidgetMonth? nextMonth,
  bool rtl = false,
}) {
  final m = month ?? _month();
  return WidgetInput(
    now: now ?? DateTime(2026, 11, 18, 14, 30),
    userName: 'Ada',
    avatarImage: 'avatar_14.png',
    dailyTestDone: done,
    stepsDone: steps,
    monthPoints: points,
    month: m,
    nextMonth: nextMonth ?? m,
    weakTopicId: weak,
    rtl: rtl,
  );
}

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

  group('tip (W01 medium B)', () {
    test('from the weak spot\'s topic, one hint line a day', () {
      final day = localDayNumber(DateTime(2026, 11, 18));
      final tip = widgetTipFor('articles', day);
      expect(tip.personal, isTrue);
      expect(tip.topic.id, TopicId.articles);
      final line = kTopicHints[TopicId.articles]![
          day % kTopicHints[TopicId.articles]!.length];
      expect('${tip.rule}: ${tip.example}', line);
    });

    test('a different line the next day', () {
      final day = localDayNumber(DateTime(2026, 11, 18));
      expect(widgetTipFor('articles', day).rule,
          isNot(widgetTipFor('articles', day + 1).rule));
    });

    test('a line without ": " stays whole', () {
      final lines = kTopicHints[TopicId.modalVerbs]!;
      final index = lines.indexWhere((l) => !l.contains(': '));
      expect(index, isNonNegative);
      final tip = widgetTipFor('modalVerbs', index);
      expect(tip.rule, lines[index]);
      expect(tip.example, isEmpty);
    });

    test('no weak spot (or an unknown topic): a general Daily Test topic', () {
      for (final weak in [null, 'notATopic']) {
        final tip = widgetTipFor(weak, 7);
        expect(tip.personal, isFalse);
        expect(kTopics, contains(tip.topic));
      }
    });

    test('labels and copy, personal and general', () {
      final payload = buildWidgetPayload(_input(), _l10n());
      final tip = _tip(payload, 0);
      expect(tip['label'], 'TIP FOR YOU · ARTICLES');
      expect(tip['footer'], 'From your weak spots · new tip daily');
      expect(tip['boxLabel'], 'DAILY TEST');
      expect(tip['button'], 'Start');
      expect(tip['url'], 'grammarlens://daily-test');
      final general = _tip(buildWidgetPayload(_input(weak: null), _l10n()), 0);
      expect(general['label'], startsWith('TIP OF THE DAY · '));
      expect(general['footer'], 'A new tip every day');
    });

    test('done: the box says so and the tip opens Home', () {
      final tip = _tip(buildWidgetPayload(_input(done: true), _l10n()), 0);
      expect(tip['done'], isTrue);
      expect(tip['button'], 'Done today');
      expect(tip['url'], 'grammarlens://home');
    });
  });

  group('languages', () {
    test('Turkish: translated copy, topic names stay English', () {
      final payload = buildWidgetPayload(_input(), _l10n('tr'));
      expect(_climb(payload, 0)['title'], '2. adım seni bekliyor');
      expect(_tip(payload, 0)['label'], 'SANA ÖZEL İPUCU · ARTICLES');
      // The hint lines are English in every language (SPEC §3.7).
      final tip = _tip(payload, 0);
      expect(kTopicHints[TopicId.articles]!.join('\n'),
          contains(tip['rule'] as String));
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
      'tr_waiting': buildWidgetPayload(_input(weak: null), _l10n('tr')),
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
