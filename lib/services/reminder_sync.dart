import 'dart:ui' show Locale;

import 'package:flutter/material.dart' show DateUtils;

import '../data/topics.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../models/daily_test_set.dart';
import '../models/reminder_settings.dart';
import '../models/review_sort_order.dart';
import '../widgets/monthly_climb/climb_save_points.dart';
import 'app_link.dart';
import 'native_bridge.dart';
import 'reminder_plan.dart';
import 'storage_service.dart';

/// What a reminder says (N02), from the plan and a few names.
class ReminderMessage {
  const ReminderMessage(this.title, this.body, this.link);

  final String title;
  final String body;
  final AppLink link;
}

/// The names a reminder's text uses, in the interface language.
class ReminderNames {
  const ReminderNames({
    required this.buddy,
    required this.mountainFor,
    this.weakSpot,
  });

  /// The companion ("Fox").
  final String buddy;

  /// The mountain of a month ("Ember Peak").
  final String Function(int year, int month) mountainFor;

  /// The most frequent weak spot as Review shows it, if any.
  final String? weakSpot;
}

/// The last save point reached after [stepsDone] of [days] steps, as its
/// name ("First Camp"), or null before the first one.
String? reachedSavePoint(int stepsDone, int days) {
  String? name;
  var best = -1;
  for (final point in [...ClimbSavePoints.all, ClimbSavePoints.flag]) {
    final step = point.reachedOn(days);
    if (step <= stepsDone && step > best) {
      best = step;
      name = point.name;
    }
  }
  return name;
}

/// The title, text and link of [reminder] (pure).
ReminderMessage reminderMessage(
    PlannedReminder reminder, ReminderNames names, AppLocalizations l10n) {
  final year = reminder.at.year, month = reminder.at.month;
  switch (reminder.kind) {
    case ReminderKind.newMountain:
      return ReminderMessage(
        l10n.reminderMountainTitle(names.mountainFor(year, month)),
        l10n.reminderMountainBody(names.buddy),
        AppLink.dailyTest,
      );
    case ReminderKind.closeToMedal:
      return ReminderMessage(
        l10n.reminderMedalTitle(reminder.tier!.label(l10n)),
        l10n.reminderMedalBody(reminder.pointsToGo),
        AppLink.dailyTest,
      );
    case ReminderKind.dailyTest:
      final place = reachedSavePoint(
          reminder.stepsDone, DateUtils.getDaysInMonth(year, month));
      return ReminderMessage(
        place == null
            ? l10n.reminderDailyTitleOn(
                names.buddy, names.mountainFor(year, month))
            : l10n.reminderDailyTitleAt(
                names.buddy, savePointLabel(place, l10n)),
        l10n.reminderDailyBody(DailyTestSet.questionCount, 2, reminder.step),
        AppLink.dailyTest,
      );
    case ReminderKind.freeTicket:
      final spot = names.weakSpot;
      return ReminderMessage(
        l10n.reminderTicketTitle,
        spot == null
            ? l10n.reminderTicketBodyGeneral
            : l10n.reminderTicketBody(spot),
        AppLink.review,
      );
  }
}

/// Rebuilds the next seven days of reminders (TASK-widgets fixed decision
/// 4, W4): run by `DeviceSync` at launch, on resume and after every write
/// that changes the plan (a test, practice, a reminder setting). Without
/// accepted reminders or iOS permission every pending one is removed.
class ReminderSync {
  ReminderSync({
    required this.storage,
    required this.bridge,
    required this.locale,
    required this.hasFullAccess,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final StorageService storage;
  final NativeBridge bridge;
  final Locale Function() locale;
  final Future<bool> Function() hasFullAccess;
  final DateTime Function() clock;

  /// Returns how many reminders are scheduled now.
  Future<int> run() async {
    final settings = await storage.getReminderSettings();
    final profile = await storage.getUserProfile();
    if (profile == null ||
        settings.ask != ReminderAsk.accepted ||
        !settings.anyOn) {
      await bridge.cancelReminders();
      return 0;
    }
    final permission = await bridge.notificationPermission();
    if (!permission.allowsReminders) {
      await bridge.cancelReminders();
      return 0;
    }
    final now = clock();
    final today = await storage.getDailyTestSetForToday();
    final progress = await storage.getClimbProgress(now.year, now.month);
    final medal = await storage.getMonthlyMedalProgress(now.year, now.month);
    final premium = await hasFullAccess();
    final freeUsed = premium ? 0 : await storage.getFreePracticeCountForToday();
    final plan = planReminders(
      settings,
      ReminderState(
        now: now,
        dailyTestDoneToday: today?.isCompleted == true,
        freeTicketUsedToday: freeUsed >= StorageService.freeDailyPracticeLimit,
        premium: premium,
        monthPoints: medal.score,
        stepsDone: progress.steps,
      ),
    );
    if (plan.isEmpty) {
      await bridge.cancelReminders();
      return 0;
    }

    final l10n = lookupAppLocalizations(locale());
    final avatar = profile.avatar ?? Avatar.fox;
    final stored = await storage.getClimbMonthThemes();
    final thisMonth = await storage.resolveClimbMonthTheme(now.year, now.month);
    String mountainFor(int year, int month) {
      final id = (year == now.year && month == now.month)
          ? thisMonth
          : stored[(year, month)];
      final theme = id != null
          ? ClimbThemes.byId(id)
          : ClimbThemeRotation.shownFor(year, month);
      return theme.title(l10n);
    }

    final weak = await storage.getWeakSpots(
        limit: 1, sortOrder: ReviewSortOrder.frequent);
    String? weakSpot;
    if (weak.isNotEmpty) {
      final topic = topicByName(weak.first.topicId);
      if (topic != null) {
        weakSpot = weakSpotTitle(weak.first.errorType, topic, l10n);
      }
    }
    final names = ReminderNames(
      buddy: avatar.name(l10n),
      mountainFor: mountainFor,
      weakSpot: weakSpot,
    );
    // The companion's picture (N02): the widgets' avatar file, written by
    // WidgetSync just before this job.
    final image = avatar.assetPath
        .split('/')
        .last
        .replaceFirst(RegExp(r'\.webp$'), '.png');
    return bridge.scheduleReminders([
      for (final reminder in plan)
        () {
          final message = reminderMessage(reminder, names, l10n);
          return ReminderRequest(
            id: reminder.id,
            at: reminder.at,
            title: message.title,
            body: message.body,
            link: message.link.url,
            image: image,
          );
        }(),
    ]);
  }
}
