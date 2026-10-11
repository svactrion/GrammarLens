/// A blank in a `fill_in_blank` question: a run of two or more underscores
/// (the proxy's `blankCount` rule, `proxy/src/shared_daily_test.ts`).
final RegExp blankPattern = RegExp(r'_{2,}');

/// Blanks a question shows: in its [context] and then its [instruction]
/// (not the hint), in reading order.
int blankCount(String? context, String instruction) =>
    blankPattern.allMatches('${context ?? ''}\n$instruction').length;
