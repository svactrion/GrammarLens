/// A one-time achievement — the user's very first row ever written to
/// `climb_daily_entries` (docs/prd-gamification.md §M6.5). Independent of,
/// and never a replacement for, the recurring monthly medals in
/// `MonthlyMedalResult`; a user can hold both at once.
class WelcomeBadge {
  final DateTime earnedAt;
  final int ruleVersion;

  /// True when this badge was granted retroactively by the v18 migration
  /// (an existing user who already had ledger history before the badge
  /// existed), rather than earned live through
  /// `StorageService.completeDailyTest`. Not shown differently in the UI
  /// today — a backfilled award never gets a celebration, but that's
  /// decided by the caller not re-reading this badge at all in that case,
  /// not by branching on this field. Kept so a backfilled award stays
  /// distinguishable from a live one if that's ever needed later.
  final bool backfilled;

  const WelcomeBadge({
    required this.earnedAt,
    required this.ruleVersion,
    required this.backfilled,
  });
}
