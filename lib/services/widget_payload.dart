import 'dart:ui' show Offset, Rect;

import '../data/topic_hints.dart';
import '../data/topics.dart';
import '../l10n/l10n.dart';
import '../models/daily_test_set.dart';
import '../models/topic.dart';
import '../utils/answer_diff.dart';
import '../utils/blanks.dart';
import '../utils/upper_case.dart';
import 'app_link.dart';

/// The home-screen widgets' payload (TASK-widgets W3): a pure function from
/// the app's state to `payload.json` (schema 1, read by
/// `ios/Shared/WidgetPayload.swift`). Every string is final and in the
/// app's language; the extension formats nothing (fixed decision 3).

/// W01 v12: how many weak spots the tip widget takes turns with.
const widgetMistakeLimit = 10;

/// The Daily Test's length on the widget ("5 questions · 2 min"). The
/// board's figure; Home says "about 2 minutes" for the same set.
const widgetTestMinutes = 2;

/// One month of the climb as the widget shows it.
class WidgetMonth {
  const WidgetMonth({
    required this.year,
    required this.month,
    required this.days,
    required this.mountainName,
    required this.monthName,
    required this.lightImage,
    required this.darkImage,
    required this.avatarPoint,
  });

  final int year;
  final int month;

  /// Steps in the month (its days).
  final int days;

  /// "Ember Peak", in the interface language.
  final String mountainName;

  /// "November", in the interface language.
  final String monthName;

  /// The App Group file names of the mountain crops.
  final String lightImage;
  final String darkImage;

  /// The avatar's point inside the crops, 0–1 (`widgetCrop`).
  final Offset avatarPoint;
}

/// The state the payload is built from.
class WidgetInput {
  const WidgetInput({
    required this.now,
    required this.userName,
    required this.avatarImage,
    required this.dailyTestDone,
    required this.stepsDone,
    required this.monthPoints,
    required this.month,
    required this.nextMonth,
    this.mistakes = const [],
    this.sleepImage = '',
    this.rtl = false,
  });

  final DateTime now;
  final String userName;

  /// The App Group file name of the avatar image.
  final String avatarImage;

  /// Today's Daily Test is completed.
  final bool dailyTestDone;

  /// Steps climbed this month, today's included.
  final int stepsDone;

  /// This month's medal points.
  final int monthPoints;
  final WidgetMonth month;

  /// The month the next local midnight falls in: [month] itself, unless
  /// midnight starts a new month.
  final WidgetMonth nextMonth;

  /// W01 v12: the user's weak spots, newest first, each with its latest
  /// mistake; the tip widget shows one a day, in turn.
  final List<WidgetMistake> mistakes;

  /// The App Group file name of the companion asleep (the tip widget's
  /// box once today's test is done).
  final String sleepImage;

  /// Arabic: the widgets lay out right to left.
  final bool rtl;
}

/// The next local midnight after [now].
DateTime nextLocalMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1);

/// Days since 1970-01-01 of [date]'s local calendar day: the tip's day
/// number (a new tip every day).
int localDayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(1970))
        .inDays;

int _seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

/// Builds payload schema 1 for [input] in [l10n]'s language.
Map<String, Object?> buildWidgetPayload(
    WidgetInput input, AppLocalizations l10n) {
  final midnight = nextLocalMidnight(input.now);
  final sameMonth = input.nextMonth.year == input.month.year &&
      input.nextMonth.month == input.month.month;
  final midnightSteps = sameMonth ? input.stepsDone : 0;
  return {
    'schema': 1,
    'writtenAt': _seconds(input.now),
    'rtl': input.rtl,
    'entries': [
      {
        'validFrom': _seconds(input.now),
        'climb': _climb(input, l10n,
            month: input.month,
            stepsDone: input.stepsDone,
            done: input.dailyTestDone,
            points: input.monthPoints),
        'tip': _tip(input, l10n,
            day: localDayNumber(input.now), done: input.dailyTestDone),
      },
      {
        'validFrom': _seconds(midnight),
        'climb': _climb(input, l10n,
            month: input.nextMonth,
            stepsDone: midnightSteps,
            done: false,
            points: sameMonth ? input.monthPoints : 0),
        'tip': _tip(input, l10n, day: localDayNumber(midnight), done: false),
      },
    ],
  };
}

Map<String, Object?> _climb(
  WidgetInput input,
  AppLocalizations l10n, {
  required WidgetMonth month,
  required int stepsDone,
  required bool done,
  required int points,
}) {
  final days = month.days;
  final climbed = stepsDone.clamp(0, days);
  // Waiting: the step today's test reaches. Done: the step it reached.
  final step = done ? climbed.clamp(1, days) : (climbed + 1).clamp(1, days);
  final progress = '$climbed/$days';
  final countdown = <String, String>{};
  final countdownMedium = <String, String>{};
  if (done) {
    for (var hours = 1; hours <= 24; hours++) {
      final line = l10n.widgetNextTestIn(hours);
      countdown['$hours'] = line;
      countdownMedium['$hours'] = '$line · $progress';
    }
  }
  return {
    'state': done ? 'done' : 'waiting',
    'url': (done ? AppLink.home : AppLink.dailyTest).url,
    'step': step,
    'steps': days,
    'label': done ? l10n.widgetDoneToday : l10n.homeDailyEyebrow,
    'title':
        done ? l10n.firstClimbStep(step, days) : l10n.widgetStepWaiting(step),
    'subtitle':
        l10n.widgetTestLength(DailyTestSet.questionCount, widgetTestMinutes),
    'stepBadge': progress,
    'points': '$points',
    'mediumTitle': done
        ? l10n.restSeeYou(input.userName)
        : l10n.widgetStepOneTestAway(step),
    'mediumSubtitle': '${month.mountainName} · ${month.monthName} · $progress',
    'chip': done ? l10n.widgetDoneToday : l10n.widgetTestWaiting,
    'button': l10n.widgetStart,
    'countdown': countdown,
    'countdownMedium': countdownMedium,
    'images': {
      'avatar': input.avatarImage,
      'mountainLight': month.lightImage,
      'mountainDark': month.darkImage,
    },
    'avatarPoint': [
      _round(month.avatarPoint.dx),
      _round(month.avatarPoint.dy),
    ],
  };
}

double _round(double value) => (value * 10000).roundToDouble() / 10000;

/// One weak spot's latest mistake (W01 v12): what the user wrote and its
/// correction, as stored in Review (nothing new is collected).
class WidgetMistake {
  const WidgetMistake({
    required this.topicId,
    required this.errorType,
    required this.userAnswer,
    required this.correctedAnswer,
    this.prompt,
    this.rule,
  });

  final String topicId;
  final String errorType;
  final String userAnswer;
  final String correctedAnswer;

  /// The question's text (the blank a one-word answer fills).
  final String? prompt;

  /// The scorer's rule (practice), or null (the Daily Test).
  final String? rule;
}

/// The general tip for local day [day] when there is no weak spot (or for
/// [weakTopicId]'s topic): one hint line, picked by the day.
WidgetTip widgetTipFor(String? weakTopicId, int day) {
  final weak = weakTopicId == null ? null : topicByName(weakTopicId);
  final hints = weak == null ? null : kTopicHints[weak.id];
  final topic = (hints != null && hints.isNotEmpty)
      ? weak!
      : kTopics[day % kTopics.length];
  final lines = kTopicHints[topic.id]!;
  final line = lines[day % lines.length];
  final (rule, example) = _splitHint(line);
  return WidgetTip(
    topic: topic,
    personal: topic == weak,
    rule: rule,
    example: example,
    examples: [
      for (var i = 1; i <= 2 && i < lines.length; i++)
        lines[(day + i) % lines.length],
    ],
  );
}

(String, String) _splitHint(String line) {
  final split = line.indexOf(': ');
  return split < 0
      ? (line, '')
      : (line.substring(0, split), line.substring(split + 2));
}

class WidgetTip {
  const WidgetTip({
    required this.topic,
    required this.personal,
    required this.rule,
    required this.example,
    this.examples = const [],
  });

  final Topic topic;

  /// From the user's weak spot (else a general tip).
  final bool personal;

  /// The hint line's key part, before ": " (the whole line if none).
  final String rule;

  /// The rest of the line; empty when the line has no ": ".
  final String example;

  /// Two more hint lines of the topic (W01 v12, no weak spot yet).
  final List<String> examples;
}

/// One run of a sentence on the tip widget: [marked] runs are the wrong
/// words (struck through) or the corrected ones (bold).
typedef WidgetRun = ({String text, bool marked});

/// Words kept before the first marked word: a long sentence starts with
/// "…" so its mistake stays on the widget's one line.
const widgetLeadWords = 3;

/// The user's sentence and its correction as runs (W01 v12). A short answer
/// that fills the question's one blank is put back into its sentence;
/// otherwise the two texts are compared word by word (1.4.0 B10's diff).
({List<WidgetRun> wrong, List<WidgetRun> right}) widgetMistakeRuns(
    WidgetMistake mistake) {
  final line = _blankLine(mistake.prompt);
  final user = mistake.userAnswer.trim();
  final corrected = mistake.correctedAnswer.trim();
  if (line != null &&
      blankPattern.allMatches(line).length == 1 &&
      !_containsMostOf(user, line) &&
      !_containsMostOf(corrected, line)) {
    final match = blankPattern.firstMatch(line)!;
    final before = line.substring(0, match.start);
    final after = line.substring(match.end);
    List<WidgetRun> fill(String answer) => _trimmed([
          if (before.isNotEmpty) (text: before, marked: false),
          (text: answer, marked: true),
          if (after.isNotEmpty) (text: after, marked: false),
        ]);
    return (wrong: fill(user), right: fill(corrected));
  }
  final diff = diffAnswer(
      userAnswer: user, correctedAnswer: corrected, prompt: mistake.prompt);
  List<WidgetRun> runs(List<DiffToken> tokens) {
    final out = <WidgetRun>[];
    for (final token in tokens) {
      final marked = diff.highlighted && token.painted;
      final text = token.text;
      if (out.isNotEmpty && out.last.marked == marked) {
        out[out.length - 1] = (text: '${out.last.text} $text', marked: marked);
      } else {
        // The space between two runs stays in the unmarked one, so a
        // struck or bold run holds its words only.
        if (out.isNotEmpty) {
          final last = out.last;
          out[out.length - 1] =
              last.marked ? last : (text: '${last.text} ', marked: false);
        }
        final space = out.isNotEmpty && out.last.marked ? ' ' : '';
        out.add((text: '$space$text', marked: marked));
      }
    }
    return out;
  }

  final (wrong, dropped) = _trim(runs(diff.user));
  return (wrong: wrong, right: _trim(runs(diff.corrected), align: dropped).$1);
}

/// The prompt's line that holds a blank, or null.
String? _blankLine(String? prompt) {
  if (prompt == null) return null;
  for (final line in prompt.split('\n')) {
    if (blankPattern.hasMatch(line)) return line.trim();
  }
  return null;
}

/// Whether [answer] already holds most of [line]'s words (a whole sentence,
/// not the blank's words).
bool _containsMostOf(String answer, String line) {
  Set<String> words(String text) => text
      .replaceAll(blankPattern, ' ')
      .toLowerCase()
      .split(RegExp("[^a-z0-9\u2019']+"))
      .where((w) => w.isNotEmpty)
      .toSet();
  final lineWords = words(line);
  if (lineWords.isEmpty) return false;
  final answerWords = words(answer);
  return lineWords.where(answerWords.contains).length >= lineWords.length * .6;
}

/// Drops the words long before the first marked run (W01 v12: one line,
/// the mistake in view), leaving [widgetLeadWords] and "…". A sentence with
/// no marked run drops [align] words instead (the other row's count), so
/// the two rows still start at the same word; it returns how many it
/// dropped.
(List<WidgetRun>, int) _trim(List<WidgetRun> runs, {int align = 0}) {
  if (runs.isEmpty || runs.first.marked) return (runs, 0);
  final words = runs.first.text.trimRight().split(' ');
  final hasMark = runs.any((r) => r.marked);
  final drop = hasMark ? words.length - widgetLeadWords : align;
  if (drop <= 1 || drop >= words.length) return (runs, 0);
  final kept = words.sublist(drop).join(' ');
  final tail = runs.first.text.endsWith(' ') ? ' ' : '';
  return ([(text: '…$kept$tail', marked: false), ...runs.skip(1)], drop);
}

List<WidgetRun> _trimmed(List<WidgetRun> runs) => _trim(runs).$1;

/// The words the corrected sentence changes, for the rule's pill.
String _markedWords(List<WidgetRun> runs) =>
    runs.where((r) => r.marked).map((r) => r.text.trim()).join(' … ');

/// The hint line of [topic] whose key shares the most words with
/// [corrected] (the Daily Test stores no rule): "the" for "the", "+ -ing"
/// for "learning"; null when none does.
String? matchingHint(Topic topic, String corrected) {
  final words = corrected
      .toLowerCase()
      .split(RegExp(r"[^a-z'-]+"))
      .where((w) => w.isNotEmpty)
      .toSet();
  String? best;
  var bestScore = 0;
  for (final line in kTopicHints[topic.id] ?? const <String>[]) {
    final (key, _) = _splitHint(line);
    var score = 0;
    for (final k in key
        .toLowerCase()
        .split(RegExp(r"[^a-z'-]+"))
        .where((w) => w.isNotEmpty)) {
      if (k == '-ing') {
        if (words.any((w) => w.endsWith('ing'))) score++;
      } else if (words.contains(k)) {
        score++;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = line;
    }
  }
  return best;
}

Map<String, Object?> _tip(WidgetInput input, AppLocalizations l10n,
    {required int day, required bool done}) {
  final boxUrl = (done ? AppLink.home : AppLink.dailyTest).url;
  final next = <String, String>{};
  if (done) {
    for (var hours = 1; hours <= 24; hours++) {
      next['$hours'] = l10n.widgetNextInShort(hours);
    }
  }
  final box = {
    'boxUrl': boxUrl,
    'boxLabel': l10n.homeDailyEyebrow,
    'button': done ? l10n.widgetDoneToday : l10n.widgetStart,
    'doneLabel': l10n.widgetDoneShort,
    'next': next,
    'boxImage': done && input.sleepImage.isNotEmpty
        ? input.sleepImage
        : input.avatarImage,
    'done': done,
  };
  final mistakes = input.mistakes;
  final mistake = mistakes.isEmpty ? null : mistakes[day % mistakes.length];
  final weakTopic = mistake == null ? null : topicByName(mistake.topicId);
  if (mistake == null || weakTopic == null) {
    // No weak spot yet: a topic's hint, its rule and two more lines.
    final tip = widgetTipFor(null, day);
    final topic = upperCaseIn('en', tip.topic.title(l10n));
    return {
      'url': boxUrl,
      'label': l10n.widgetTipLabelGeneral(topic),
      'lead': '',
      'rule': tip.rule,
      'example': tip.example,
      'examples': tip.examples,
      'footer': l10n.widgetTipFooterGeneral,
      ...box,
    };
  }
  final runs = widgetMistakeRuns(mistake);
  final rule = mistake.rule?.trim() ?? '';
  // The rule: the scorer's (practice) with the corrected words in the pill;
  // the Daily Test stores none, so its topic's matching hint line, the
  // key in the pill.
  final hint = rule.isEmpty
      ? matchingHint(weakTopic, mistake.correctedAnswer) ??
          kTopicHints[weakTopic.id]![day % kTopicHints[weakTopic.id]!.length]
      : null;
  final (hintKey, hintRest) = hint == null ? ('', '') : _splitHint(hint);
  List<Map<String, Object>> encode(List<WidgetRun> runs) => [
        for (final r in runs) {'t': r.text, 'm': r.marked}
      ];
  return {
    'url': AppLink.weakSpotUrl(mistake.topicId, mistake.errorType),
    // Topic names stay English (SPEC §3.7).
    'label': upperCaseIn('en', weakTopic.title(l10n)),
    'lead': rule,
    'rule': hint == null ? _markedWords(runs.right) : hintKey,
    'example': hint == null ? '' : hintRest,
    'mistake': {'wrong': encode(runs.wrong), 'right': encode(runs.right)},
    'footer': l10n.widgetWeakSpotFooter,
    ...box,
  };
}

/// The medium widget's aspect (W01: 364 × 170).
const widgetMediumAspect = 364 / 170;

/// How much of the mountain image's width the medium widget shows (W01's
/// crop: the trail around the avatar, not the whole mountain).
const widgetCropWidth = 0.62;

/// The mountain crop for an avatar standing at [point] (in image widths,
/// `ClimbRoute`'s units) on an image of [imageAspect] (width ÷ height):
/// [rect] in the image's own fractions (0–1 on both axes) and the avatar's
/// point inside the crop (0–1). The avatar sits a little left of centre
/// and below the middle, like the board; the crop never leaves the image.
({Rect rect, Offset avatar}) widgetCrop(
  Offset point, {
  required double imageAspect,
  double widgetAspect = widgetMediumAspect,
  double width = widgetCropWidth,
}) {
  final imageHeight = 1 / imageAspect; // in image widths
  final cropHeight = width / widgetAspect; // in image widths
  final left = (point.dx - width * 0.45).clamp(0.0, 1 - width);
  final top =
      (point.dy - cropHeight * 0.62).clamp(0.0, imageHeight - cropHeight);
  return (
    rect: Rect.fromLTWH(
      left,
      top / imageHeight,
      width,
      cropHeight / imageHeight,
    ),
    avatar: Offset(
      (point.dx - left) / width,
      (point.dy - top) / cropHeight,
    ),
  );
}
