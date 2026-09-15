/// The three-way time-of-day greeting word for [time]'s local hour — no
/// fourth "night" slice and never "Good night": that phrase is an
/// English-language farewell, not a greeting, and this app teaches
/// English, so using it as one would be a real, visible mistake, not a
/// style choice.
///
/// Boundaries are whole-hour (05:00, 12:00, 18:00), so comparing on
/// [DateTime.hour] alone is exact — no minute-level rounding needed:
/// - 05:00–11:59 → "Good morning"
/// - 12:00–17:59 → "Good afternoon"
/// - 18:00–04:59 → "Good evening" (wraps past midnight)
///
/// Takes a concrete [time] rather than reading the clock itself, so it's
/// a pure function callers can test directly with any boundary value —
/// the caller (e.g. `HomeScreen`) owns its own injectable clock seam.
String timeOfDayGreeting(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 18) return 'Good afternoon';
  return 'Good evening';
}
