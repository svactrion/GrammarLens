import 'package:flutter/material.dart' show DateUtils;

import '../models/medal_tier.dart';
import '../models/reminder_settings.dart';
import 'monthly_medal_rules.dart';

/// The reminder plan (TASK-widgets fixed decision 4, W4): a pure function
/// from the settings and the app's state to at most one reminder a day for
/// the next [reminderPlanDays] days, at the user's time.

const reminderPlanDays = 7;

/// What the plan needs to know, read when it is (re)built: at launch, when
/// a test or practice finishes, when a setting changes.
class ReminderState {
  const ReminderState({
    required this.now,
    required this.dailyTestDoneToday,
    required this.freeTicketUsedToday,
    required this.premium,
    required this.monthPoints,
    required this.stepsDone,
  });

  final DateTime now;
  final bool dailyTestDoneToday;

  /// The free user's daily practice ticket is used today.
  final bool freeTicketUsedToday;
  final bool premium;

  /// This month's medal points.
  final int monthPoints;

  /// Steps climbed this month, today's included.
  final int stepsDone;
}

/// One day's reminder.
class PlannedReminder {
  const PlannedReminder({
    required this.at,
    required this.kind,
    required this.step,
    required this.stepsDone,
    this.tier,
    this.pointsToGo = 0,
  });

  /// Local date and time it fires.
  final DateTime at;
  final ReminderKind kind;

  /// The step that day's test reaches.
  final int step;

  /// Steps already climbed that month when it fires (as far as known now).
  final int stepsDone;

  /// Close to a medal: the tier and the points still missing.
  final MedalTier? tier;
  final int pointsToGo;

  /// `gl.reminder.YYYY-MM-DD`: one id per day, so a day can never hold two.
  String get id => 'gl.reminder.${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  @override
  String toString() => '$id ${kind.name}';
}

/// The plan: for each of the next [days] local days whose reminder time is
/// still ahead, the first kind that fits among those switched on —
/// (a) new mountain: the month's first day and the test not done;
/// (b) close to a medal: the test not done and the next tier 5 points or
///     fewer away ([MonthlyMedalRules.nearMiss]);
/// (c) Daily Test: the test not done;
/// (d) free ticket: the test done but a free user's ticket not used.
/// Days ahead are planned as if no more tests are taken (the plan is
/// rebuilt as soon as one is), so (d) can only be today's. Nothing at all
/// unless the user accepted reminders.
List<PlannedReminder> planReminders(
  ReminderSettings settings,
  ReminderState state, {
  int days = reminderPlanDays,
}) {
  if (settings.ask != ReminderAsk.accepted || !settings.anyOn) return const [];
  final now = state.now;
  final plan = <PlannedReminder>[];
  for (var i = 0; i < days; i++) {
    final at = DateTime(
        now.year, now.month, now.day + i, settings.hour, settings.minute);
    if (!at.isAfter(now)) continue;
    final today = i == 0;
    final sameMonth = at.year == now.year && at.month == now.month;
    final testDone = today && state.dailyTestDoneToday;
    final steps = sameMonth ? state.stepsDone : 0;
    final points = sameMonth ? state.monthPoints : 0;
    final monthDays = DateUtils.getDaysInMonth(at.year, at.month);
    final step = (steps + 1).clamp(1, monthDays);
    final near = MonthlyMedalRules.nearMiss(at.year, at.month, points);

    PlannedReminder make(ReminderKind kind) => PlannedReminder(
          at: at,
          kind: kind,
          step: step,
          stepsDone: steps,
          tier: kind == ReminderKind.closeToMedal ? near!.$1 : null,
          pointsToGo: kind == ReminderKind.closeToMedal ? near!.$2 : 0,
        );

    if (settings.newMountain && at.day == 1 && !testDone) {
      plan.add(make(ReminderKind.newMountain));
    } else if (settings.closeToMedal && !testDone && near != null) {
      plan.add(make(ReminderKind.closeToMedal));
    } else if (settings.dailyTest && !testDone) {
      plan.add(make(ReminderKind.dailyTest));
    } else if (settings.freeTicket &&
        testDone &&
        !state.premium &&
        !state.freeTicketUsedToday) {
      plan.add(make(ReminderKind.freeTicket));
    }
  }
  return plan;
}
