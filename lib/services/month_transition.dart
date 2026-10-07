import 'package:flutter/foundation.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import 'analytics_service.dart';
import 'medal_finalization.dart';
import 'monthly_medal_rules.dart';
import 'storage_service.dart';

/// The month transition card's two variants (Batch 6, M3).
enum MonthCardVariant {
  /// The previous calendar month has at least one step.
  summary,

  /// It has none: avatar, theme, no numbers.
  fresh;

  /// The analytics value (M19).
  String get wireName => name;
}

/// What the month transition card shows (M3, M5, M13, M15).
@immutable
class MonthCardData {
  /// The month the user is in now, and its theme.
  final int year, month;
  final ClimbTheme theme;

  final MonthCardVariant variant;

  /// The previous month's theme, the one its medal belongs to (Batch 5,
  /// N16): read from its stored theme record; Green Slope when the card
  /// has no medal to show.
  final ClimbTheme previousTheme;

  /// The previous calendar month: the summary card's subject.
  final int previousYear, previousMonth;

  /// Summary card only: last month's frozen medal (null: none earned), its
  /// steps out of its days, its score, and the near-miss line's next tier
  /// and gap (null: no line).
  final MedalTier? tier;
  final int steps, days, score;
  final (MedalTier, int)? nearMiss;

  const MonthCardData({
    required this.year,
    required this.month,
    required this.theme,
    required this.variant,
    this.previousTheme = ClimbThemes.greenSlope,
    required this.previousYear,
    required this.previousMonth,
    this.tier,
    this.steps = 0,
    this.days = 0,
    this.score = 0,
    this.nearMiss,
  });
}

/// Batch 6's month change: which card, if any, the user sees on this
/// month's first Home open (M1–M3, M20). Storage and the clock are passed
/// in; nothing here holds state.
abstract final class MonthTransition {
  /// The calendar month before [year]/[month].
  static (int, int) previousMonth(int year, int month) =>
      month == 1 ? (year - 1, 12) : (year, month - 1);

  /// The decision, pure: no card once this month's card was dismissed
  /// ([cardSeen]) or in the month a user starts in (no [usedBefore], M2);
  /// otherwise one card, however many months were skipped, its variant
  /// from the previous calendar month's steps (M3).
  static MonthCardVariant? decide({
    required bool cardSeen,
    required bool usedBefore,
    required int previousSteps,
  }) {
    if (cardSeen || !usedBefore) return null;
    return previousSteps > 0
        ? MonthCardVariant.summary
        : MonthCardVariant.fresh;
  }

  /// The card for the month of [now], or null for none. Any storage error
  /// is null too: a wrong card is worse than a late one, and the next open
  /// tries again.
  ///
  /// The summary card reads last month's medal as frozen by
  /// [finalizePastMedalMonthsAndReport], which this calls itself (it is
  /// idempotent and reports each month once, whoever calls it first;
  /// Batch 0 decision 9, M20). A month with steps but no frozen row yet
  /// gives no card this time.
  static Future<MonthCardData?> load({
    required StorageService storage,
    required AnalyticsService analytics,
    required DateTime now,
  }) async {
    try {
      final (year, month) = (now.year, now.month);
      final cardSeen = await storage
          .hasOneTimeFlag(StorageService.monthCardSeenFlag(year, month));
      if (cardSeen) return null;
      final usedBefore = await storage.hasClimbHistoryBefore(year, month);
      if (!usedBefore) return null;
      final (py, pm) = previousMonth(year, month);
      final previous = await storage.getClimbProgress(py, pm);
      final variant = decide(
          cardSeen: cardSeen,
          usedBefore: usedBefore,
          previousSteps: previous.steps);
      if (variant == null) return null;
      final theme =
          ClimbThemes.byId(await storage.resolveClimbMonthTheme(year, month));
      if (variant == MonthCardVariant.fresh) {
        return MonthCardData(
            year: year,
            month: month,
            theme: theme,
            variant: variant,
            previousYear: py,
            previousMonth: pm);
      }
      await finalizePastMedalMonthsAndReport(
          storageService: storage, analyticsService: analytics);
      final results = await storage.getMonthlyMedalResults();
      final frozen =
          results.where((r) => r.year == py && r.month == pm).firstOrNull;
      if (frozen == null) return null;
      // A past month: its stored theme, or Green Slope before themes were
      // stored (nothing is written for it).
      final previousTheme =
          ClimbThemes.byId(await storage.resolveClimbMonthTheme(py, pm));
      return MonthCardData(
        year: year,
        month: month,
        theme: theme,
        variant: variant,
        previousTheme: previousTheme,
        previousYear: py,
        previousMonth: pm,
        tier: frozen.tier,
        steps: frozen.activeDays,
        days: DateTime(py, pm + 1, 0).day,
        score: frozen.score,
        nearMiss: MonthlyMedalRules.nearMiss(py, pm, frozen.score),
      );
    } catch (_) {
      return null;
    }
  }

  /// Records this month's card as seen: called when it is dismissed, by
  /// any of its three ways (M6).
  static Future<void> markSeen(StorageService storage, int year, int month) =>
      storage.claimOneTimeFlag(StorageService.monthCardSeenFlag(year, month));
}
