import 'dart:ui' show Offset, Rect;

import '../data/topic_hints.dart';
import '../data/topics.dart';
import '../l10n/l10n.dart';
import '../models/daily_test_set.dart';
import '../models/topic.dart';
import 'app_link.dart';

/// The home-screen widgets' payload (TASK-widgets W3): a pure function from
/// the app's state to `payload.json` (schema 1, read by
/// `ios/Shared/WidgetPayload.swift`). Every string is final and in the
/// app's language; the extension formats nothing (fixed decision 3).

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
    this.weakTopicId,
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

  /// The topic of the most frequent weak spot (`TopicId.name`), if any.
  final String? weakTopicId;

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

/// The tip for local day [day]: one hint line of the weak spot's topic, or
/// of a Daily Test topic picked by the day when there is no weak spot.
WidgetTip widgetTipFor(String? weakTopicId, int day) {
  final weak = weakTopicId == null ? null : topicByName(weakTopicId);
  final hints = weak == null ? null : kTopicHints[weak.id];
  final topic = (hints != null && hints.isNotEmpty)
      ? weak!
      : kTopics[day % kTopics.length];
  final lines = kTopicHints[topic.id]!;
  final line = lines[day % lines.length];
  final split = line.indexOf(': ');
  return WidgetTip(
    topic: topic,
    personal: topic == weak,
    rule: split < 0 ? line : line.substring(0, split),
    example: split < 0 ? '' : line.substring(split + 2),
  );
}

class WidgetTip {
  const WidgetTip({
    required this.topic,
    required this.personal,
    required this.rule,
    required this.example,
  });

  final Topic topic;

  /// From the user's weak spot (else a general tip).
  final bool personal;

  /// The hint line's key part, before ": " (the whole line if none).
  final String rule;

  /// The rest of the line; empty when the line has no ": ".
  final String example;
}

Map<String, Object?> _tip(WidgetInput input, AppLocalizations l10n,
    {required int day, required bool done}) {
  final tip = widgetTipFor(input.weakTopicId, day);
  // Topic names stay English (SPEC §3.7), in capitals like the label.
  final topic = tip.topic.title(l10n).toUpperCase();
  return {
    'url': (done ? AppLink.home : AppLink.dailyTest).url,
    'label': tip.personal
        ? l10n.widgetTipLabel(topic)
        : l10n.widgetTipLabelGeneral(topic),
    'rule': tip.rule,
    'example': tip.example,
    'footer': tip.personal ? l10n.widgetTipFooter : l10n.widgetTipFooterGeneral,
    'boxLabel': l10n.homeDailyEyebrow,
    'button': done ? l10n.widgetDoneToday : l10n.widgetStart,
    'done': done,
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
