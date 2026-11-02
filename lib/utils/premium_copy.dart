import '../l10n/generated/app_localizations.dart';

/// Shown wherever a free user has used today's
/// `StorageService.freeDailyPracticeLimit`: the weak-spot detail screen's
/// locked row and the practice results screen's Premium offer card. One
/// constant so the two places cannot drift apart. Never says "unlimited": Premium is
/// bounded by `StorageService.dailySessionLimit`.
String freePracticeUsedMessage(AppLocalizations l10n) =>
    l10n.premiumFreePracticeUsed;
