import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/services/reminder_plan.dart';

/// November 2026: 30 days, Bronze at 75 points (25 % of 300).
const _bronze = 75;

ReminderSettings _on({int minutes = ReminderSettings.evening}) =>
    const ReminderSettings().turnedOn(minutes: minutes);

ReminderState _state({
  DateTime? now,
  bool done = false,
  bool ticketUsed = false,
  bool premium = false,
  int points = 10,
  int steps = 3,
}) =>
    ReminderState(
      now: now ?? DateTime(2026, 11, 18, 9),
      dailyTestDoneToday: done,
      freeTicketUsedToday: ticketUsed,
      premium: premium,
      monthPoints: points,
      stepsDone: steps,
    );

List<ReminderKind> _kinds(List<PlannedReminder> plan) =>
    plan.map((r) => r.kind).toList();

void main() {
  group('when nothing is planned', () {
    test('reminders never accepted, or declined', () {
      for (final ask in [ReminderAsk.notAsked, ReminderAsk.declined]) {
        final settings = _on().copyWith(ask: ask);
        expect(planReminders(settings, _state()), isEmpty);
      }
    });

    test('every kind switched off', () {
      final settings = _on()
          .withKind(ReminderKind.dailyTest, false)
          .withKind(ReminderKind.freeTicket, false)
          .withKind(ReminderKind.closeToMedal, false)
          .withKind(ReminderKind.newMountain, false);
      expect(planReminders(settings, _state()), isEmpty);
    });
  });

  group('the seven days', () {
    test('today and six more, at the chosen time, one a day', () {
      final plan = planReminders(_on(), _state());
      expect(plan, hasLength(7));
      expect(plan.map((r) => r.at), [
        for (var i = 0; i < 7; i++) DateTime(2026, 11, 18 + i, 20),
      ]);
      expect(plan.map((r) => r.id).toSet(), hasLength(7),
          reason: 'at most one a day: one id per day');
      expect(plan.first.id, 'gl.reminder.2026-11-18');
    });

    test('today\'s time has passed: tomorrow is the first', () {
      final plan =
          planReminders(_on(minutes: ReminderSettings.morning), _state());
      expect(plan.first.at, DateTime(2026, 11, 19, 8, 30));
      expect(plan, hasLength(6));
    });

    test('exactly now counts as passed', () {
      final plan =
          planReminders(_on(), _state(now: DateTime(2026, 11, 18, 20)));
      expect(plan.first.at.day, 19);
    });
  });

  group('priority (a) → (b) → (c) → (d)', () {
    test('(c) the Daily Test reminder when nothing else fits', () {
      final plan = planReminders(_on(), _state());
      expect(_kinds(plan), everyElement(ReminderKind.dailyTest));
      expect(plan.first.step, 4);
    });

    test('(a) beats (b) and (c) on the month\'s first day', () {
      final plan = planReminders(
          _on(), _state(now: DateTime(2026, 11, 28, 9), points: _bronze - 3));
      // 28, 29, 30 November: close to Bronze; 1 December: new mountain.
      expect(_kinds(plan).take(4), [
        ReminderKind.closeToMedal,
        ReminderKind.closeToMedal,
        ReminderKind.closeToMedal,
        ReminderKind.newMountain,
      ]);
      final first = plan[3];
      expect(first.at, DateTime(2026, 12, 1, 20));
      expect(first.step, 1, reason: 'a new month starts at step 1');
      // December starts from 0 points: no medal is close.
      expect(_kinds(plan).skip(4), everyElement(ReminderKind.dailyTest));
    });

    test('(a) today, when today is the first and the test is not done', () {
      final plan = planReminders(
          _on(), _state(now: DateTime(2026, 12, 1, 9), steps: 0, points: 0));
      expect(plan.first.kind, ReminderKind.newMountain);
    });

    test('(b) beats (c)', () {
      final plan = planReminders(_on(), _state(points: _bronze - 2));
      expect(plan.first.kind, ReminderKind.closeToMedal);
      expect(plan.first.tier, MedalTier.bronze);
      expect(plan.first.pointsToGo, 2);
    });

    test(
        '(d) only today, only after the test, only for free users with '
        'the ticket unused', () {
      expect(planReminders(_on(), _state(done: true)).first.kind,
          ReminderKind.freeTicket);
      expect(
          planReminders(_on(), _state(done: true)).skip(1).map((r) => r.kind),
          everyElement(ReminderKind.dailyTest));
      expect(
          planReminders(_on(), _state(done: true, ticketUsed: true))
              .first
              .at
              .day,
          19);
      expect(
          planReminders(_on(), _state(done: true, premium: true)).first.at.day,
          19);
    });

    test('a switched-off kind falls through to the next', () {
      final settings = _on().withKind(ReminderKind.closeToMedal, false);
      expect(planReminders(settings, _state(points: _bronze - 2)).first.kind,
          ReminderKind.dailyTest);
      final noDaily = _on().withKind(ReminderKind.dailyTest, false);
      expect(planReminders(noDaily, _state()), isEmpty,
          reason: 'nothing else fits on an ordinary day');
    });
  });

  group('the 5-point limit', () {
    test('5 points away is close, 6 is not, 0 is reached', () {
      expect(planReminders(_on(), _state(points: _bronze - 5)).first.kind,
          ReminderKind.closeToMedal);
      expect(planReminders(_on(), _state(points: _bronze - 6)).first.kind,
          ReminderKind.dailyTest);
      // At Bronze the next tier, Silver (150), is far away.
      expect(planReminders(_on(), _state(points: _bronze)).first.kind,
          ReminderKind.dailyTest);
    });

    test('close to Silver names Silver; at Gold nothing is close', () {
      final silver = planReminders(_on(), _state(points: 147)).first;
      expect(silver.tier, MedalTier.silver);
      expect(silver.pointsToGo, 3);
      expect(planReminders(_on(), _state(points: 300)).first.kind,
          ReminderKind.dailyTest);
    });
  });

  group('when the test is finished, today\'s reminder', () {
    test('turns into "Free ticket is back" for a free user', () {
      final before = planReminders(_on(), _state());
      final after = planReminders(_on(), _state(done: true, steps: 4));
      expect(before.first.id, after.first.id);
      expect(before.first.kind, ReminderKind.dailyTest);
      expect(after.first.kind, ReminderKind.freeTicket);
    });

    test('is cancelled when nothing else fits', () {
      final before = planReminders(_on(), _state(premium: true));
      final after =
          planReminders(_on(), _state(done: true, premium: true, steps: 4));
      expect(before.first.at.day, 18);
      expect(after.first.at.day, 19);
      expect(after, hasLength(6));
    });

    test('a close medal no longer counts today once the test is done', () {
      final after =
          planReminders(_on(), _state(done: true, points: _bronze - 2));
      expect(after.first.kind, ReminderKind.freeTicket);
      expect(after[1].kind, ReminderKind.closeToMedal);
    });

    test('tomorrow\'s step follows today\'s', () {
      final after = planReminders(_on(), _state(done: true, steps: 4));
      expect(after[1].step, 5);
    });
  });

  test('the step never passes the month\'s days', () {
    final plan =
        planReminders(_on(), _state(now: DateTime(2026, 11, 29, 9), steps: 30));
    expect(plan.first.step, 30);
  });
}
