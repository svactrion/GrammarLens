/// Per-topic practice summary for the home screen's topic cards: how many
/// questions the user has answered for this topic across all sessions, and
/// how many distinct error types are still open weak spots.
class TopicStats {
  final int practiced;
  final int weakSpotCount;

  const TopicStats({required this.practiced, required this.weakSpotCount});

  static const empty = TopicStats(practiced: 0, weakSpotCount: 0);

  bool get isStarted => practiced > 0;
}
