import '../models/error_entry.dart';

/// Premium Review's Suggested Focus (1.2.0 final screens, brief §2): the
/// saved weak spot to work on next, chosen from the whole set of saved weak
/// spots (not the ten the list shows, and not in the list's sort order).
///
/// A weak spot is one (topic, error type) group of saved mistakes
/// (`StorageService.getWeakSpots`): its count is [WeakSpot.frequency] (the
/// number of saved mistakes in the group), its last seen is
/// [WeakSpot.lastSeen] (the newest one), and its stable id is the pair
/// ([WeakSpot.topicId], [WeakSpot.errorType]), unique per group.
///
/// The rule, in order:
/// 1. the highest count;
/// 2. on a tie, the newest last seen; a last seen before [validSince] is
///    treated as unknown and ranks after every known date;
/// 3. on a tie, the smallest id (topic id, then error type), so the same
///    data always gives the same answer.
///
/// A weak spot with a count under 1 is not a valid record and is never
/// chosen (no count is invented for it). Returns null when no valid weak
/// spot is left. Nothing is summed, weighted or recomputed: the counts are
/// the ones the list shows.
WeakSpot? suggestedFocus(Iterable<WeakSpot> spots) {
  WeakSpot? best;
  for (final spot in spots) {
    if (spot.frequency < 1) continue;
    if (best == null || _ranksBefore(spot, best)) best = spot;
  }
  return best;
}

/// Dates before this are not real "last seen" dates (an epoch or zero
/// date from a bad row).
final DateTime validSince = DateTime.utc(2000);

bool _known(DateTime d) => !d.isBefore(validSince);

bool _ranksBefore(WeakSpot a, WeakSpot b) {
  if (a.frequency != b.frequency) return a.frequency > b.frequency;
  final aKnown = _known(a.lastSeen), bKnown = _known(b.lastSeen);
  if (aKnown != bKnown) return aKnown;
  if (aKnown && a.lastSeen != b.lastSeen) return a.lastSeen.isAfter(b.lastSeen);
  final byTopic = a.topicId.compareTo(b.topicId);
  if (byTopic != 0) return byTopic < 0;
  return a.errorType.compareTo(b.errorType) < 0;
}
