/// Reads [field] from a decoded-JSON [json] map as a [T], failing with a
/// message that names the field and what actually came back instead of an
/// opaque "type 'Null' is not a subtype of type 'X'" cast error.
///
/// Model responses are the main case this matters for: a schema mismatch
/// between what we ask the API for and what our parser expects otherwise
/// surfaces as a stack trace pointing at a bare `as` cast with no clue
/// which field, or which API call, produced it (see docs/build-log.md for
/// the Daily Test bug this was written for).
T requireJsonField<T>(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is T) return value;
  throw FormatException(
    'Expected "$field" to be a $T, but got '
    '${value == null ? 'nothing (missing/null)' : '${value.runtimeType}: $value'}. '
    'Full payload: $json',
  );
}
