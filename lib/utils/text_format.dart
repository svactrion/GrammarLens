import '../l10n/generated/app_localizations.dart';

/// Turns a snake_case or camelCase identifier (topic/error-type slugs coming
/// out of the LLM or enum names) into a human-readable title, e.g.
/// `gerund_vs_infinitive` / `gerundVsInfinitive` -> "Gerund vs. Infinitive".
String humanizeSlug(String raw) {
  final withSpaces = raw
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  final words = withSpaces.trim().split(RegExp(r'\s+'));
  return words.map((w) {
    if (w.isEmpty) return w;
    final lower = w.toLowerCase();
    if (lower == 'vs') return 'vs.';
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}

/// Relative-day phrasing for a past timestamp, e.g. "today", "yesterday",
/// "3 days ago". [now] is injectable for tests; defaults to the real clock.
String formatRecency(DateTime timestamp, AppLocalizations l10n,
    {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return l10n.recencyToday;
  if (diff == 1) return l10n.recencyYesterday;
  if (diff < 7) return l10n.recencyDays(diff);
  if (diff < 30) return l10n.recencyWeeks(diff ~/ 7);
  final months = diff ~/ 30;
  return l10n.recencyMonths(months < 1 ? 1 : months);
}

/// Prominent "N times · last seen <recency>" label for weak-spot stats
/// (PRD §2.1, Theme 4 — the most-requested feature across interviews).
String formatFrequencyStat(
        int frequency, DateTime lastSeen, AppLocalizations l10n,
        {DateTime? now}) =>
    l10n.frequencyStat(l10n.frequencyTimes(frequency),
        formatRecency(lastSeen, l10n, now: now));

/// "N practiced · M weak spots" label for a home-screen topic card. Callers
/// should show "Not started yet" instead when [practiced] is 0.
String formatTopicStatsLine(
        int practiced, int weakSpotCount, AppLocalizations l10n) =>
    l10n.topicStatsLine(l10n.topicStatsPracticed(practiced),
        l10n.topicStatsWeakSpots(weakSpotCount));
