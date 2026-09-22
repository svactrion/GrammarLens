/// The user's decision about sending their Topic Practice answers to a third
/// party AI provider (Anthropic's Claude), the permission App Review guideline
/// 5.1.2(i) requires before any personal data is shared that way.
///
/// One row is stored, the latest decision. [version] is the wording and scope
/// the user saw: raising [currentVersion] (a new provider, or more data sent)
/// makes every earlier grant stale, so the screen asks again.
class AiConsent {
  /// Version 1: the user's typed answers and the question text go to
  /// Anthropic (Claude) through GrammarLens's server, for feedback.
  static const int currentVersion = 1;

  final bool granted;
  final DateTime decidedAt;
  final int version;

  const AiConsent({
    required this.granted,
    required this.decidedAt,
    required this.version,
  });

  /// True only for a grant that covers what the app sends today. A decline, or
  /// a grant given for an older [version], never allows sending.
  bool get allowsSending => granted && version >= currentVersion;
}
