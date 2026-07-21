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
