import 'dart:async';

import '../models/monthly_medal.dart';
import 'analytics_service.dart';
import 'storage_service.dart';

/// Freezes every past month that has Daily Test history and reports each
/// month it *newly* froze as `medal_month_finalized`
/// (docs/analytics-plan.md E4).
///
/// Called at app launch, on resume from background, and from Profile.
/// Reporting is safe from all three because
/// [StorageService.finalizePastMedalMonths] returns only the months that call
/// finalized: a month already frozen by an earlier trigger comes back empty
/// the second time, so it is finalized once and reported once.
///
/// Storage errors propagate to the caller (Profile shows a retry state);
/// analytics errors never do.
Future<List<MonthlyMedalResult>> finalizePastMedalMonthsAndReport({
  required StorageService storageService,
  required AnalyticsService analyticsService,
}) async {
  final finalized = await storageService.finalizePastMedalMonths();
  for (final result in finalized) {
    unawaited(analyticsService.medalMonthFinalized(
      tier: result.tier,
      scorePct: result.maxScore == 0
          ? 0
          : (result.score * 100 / result.maxScore).round(),
      activeDays: result.activeDays,
      daysInMonth: DateTime(result.year, result.month + 1, 0).day,
      ruleVersion: result.ruleVersion,
      monthsAgo: (result.finalizedAt.year * 12 + result.finalizedAt.month) -
          (result.year * 12 + result.month),
    ));
  }
  return finalized;
}
