/// Versioned the same way `MonthlyMedalRules.ruleVersion` is
/// (docs/prd-gamification.md §M6.5): stamping every awarded badge with the
/// rule version that granted it means a future change to what earns this
/// badge never silently reinterprets one already on record.
abstract final class WelcomeBadgeRules {
  static const ruleVersion = 1;
}
