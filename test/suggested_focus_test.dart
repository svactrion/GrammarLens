import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/utils/suggested_focus.dart';

WeakSpot _spot(String topic, int count,
        {String type = 'e', DateTime? lastSeen}) =>
    WeakSpot(
      topicId: topic,
      errorType: type,
      frequency: count,
      lastSeen: lastSeen ?? DateTime(2026, 10, 1),
    );

/// The Suggested Focus rule (1.2.0 final screens, brief §2).
void main() {
  test('1 / 2 / 1 → the second', () {
    final spots = [
      _spot('gerundVsInfinitive', 1),
      _spot('modalVerbs', 2),
      _spot('articles', 1),
    ];
    expect(suggestedFocus(spots)!.topicId, 'modalVerbs');
  });

  test('1 / 2 / 3 → the third', () {
    final spots = [
      _spot('gerundVsInfinitive', 1),
      _spot('modalVerbs', 2),
      _spot('articles', 3),
    ];
    expect(suggestedFocus(spots)!.topicId, 'articles');
  });

  test('equal counts → the newest last seen', () {
    final spots = [
      _spot('a', 2, lastSeen: DateTime(2026, 10, 1)),
      _spot('b', 2, lastSeen: DateTime(2026, 10, 3)),
      _spot('c', 2, lastSeen: DateTime(2026, 10, 2)),
    ];
    expect(suggestedFocus(spots)!.topicId, 'b');
  });

  test(
      'all equal → the smallest stable id (topic, then error type), in any '
      'input order', () {
    final day = DateTime(2026, 10, 1);
    final spots = [
      _spot('b', 2, type: 'x', lastSeen: day),
      _spot('a', 2, type: 'y', lastSeen: day),
      _spot('a', 2, type: 'x', lastSeen: day),
    ];
    for (final order in [spots, spots.reversed.toList()]) {
      final chosen = suggestedFocus(order)!;
      expect((chosen.topicId, chosen.errorType), ('a', 'x'));
    }
  });

  test('the list\'s sort order does not change the choice', () {
    final spots = [
      _spot('a', 1, lastSeen: DateTime(2026, 10, 5)),
      _spot('b', 3, lastSeen: DateTime(2026, 9, 1)),
      _spot('c', 2, lastSeen: DateTime(2026, 10, 4)),
    ];
    final byRecent = [...spots]
      ..sort((x, y) => y.lastSeen.compareTo(x.lastSeen));
    final byCount = [...spots]
      ..sort((x, y) => y.frequency.compareTo(x.frequency));
    expect(suggestedFocus(byRecent)!.topicId, 'b');
    expect(suggestedFocus(byCount)!.topicId, 'b');
    expect(byRecent.first.topicId, isNot('b'),
        reason: 'the first visible record is not simply taken');
  });

  test('a count under 1 is never chosen; none valid → null', () {
    expect(
        suggestedFocus([_spot('a', 0), _spot('b', -2), _spot('c', 1)])!.topicId,
        'c');
    expect(suggestedFocus([_spot('a', 0), _spot('b', -1)]), isNull);
    expect(suggestedFocus(const []), isNull);
  });

  test('an unknown last seen ranks after every known date on a count tie', () {
    final spots = [
      _spot('a', 2, lastSeen: DateTime.fromMillisecondsSinceEpoch(0)),
      _spot('b', 2, lastSeen: DateTime(2026, 1, 1)),
    ];
    expect(suggestedFocus(spots)!.topicId, 'b');
    // Two unknown dates fall through to the stable id.
    expect(
        suggestedFocus([
          _spot('d', 2, lastSeen: DateTime.fromMillisecondsSinceEpoch(0)),
          _spot('c', 2, lastSeen: DateTime(1970, 6)),
        ])!
            .topicId,
        'c');
  });

  test(
      'after a deletion or a count change the answer is recomputed, not '
      'kept', () {
    final before = [_spot('a', 3), _spot('b', 2)];
    expect(suggestedFocus(before)!.topicId, 'a');
    expect(suggestedFocus([_spot('b', 2)])!.topicId, 'b'); // a deleted
    expect(suggestedFocus([_spot('a', 3), _spot('b', 4)])!.topicId, 'b');
  });

  test('more than ten records: one the list does not show can be chosen', () {
    final recentTen = [
      for (var i = 0; i < 10; i++)
        _spot('t$i', 1, lastSeen: DateTime(2026, 10, 20 - i)),
    ];
    final older = _spot('older', 5, lastSeen: DateTime(2026, 1, 1));
    expect(suggestedFocus([...recentTen, older])!.topicId, 'older');
  });
}
