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
String formatRecency(DateTime timestamp, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'today';
  if (diff == 1) return 'yesterday';
  if (diff < 7) return '$diff days ago';
  if (diff < 30) {
    final weeks = diff ~/ 7;
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  final months = diff ~/ 30;
  return months <= 1 ? '1 month ago' : '$months months ago';
}

/// Prominent "N times · last seen <recency>" label for weak-spot stats
/// (PRD §2.1, Theme 4 — the most-requested feature across interviews).
String formatFrequencyStat(int frequency, DateTime lastSeen, {DateTime? now}) {
  final times = frequency == 1 ? '1 time' : '$frequency times';
  return '$times · last seen ${formatRecency(lastSeen, now: now)}';
}
