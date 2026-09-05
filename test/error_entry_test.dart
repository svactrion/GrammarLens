import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/error_entry.dart';

void main() {
  group('ErrorSource', () {
    test('round-trips through toJson/fromJson', () {
      for (final source in ErrorSource.values) {
        expect(ErrorSource.fromJson(source.toJson()), source);
      }
    });

    test('an unrecognized or missing value defaults to topicPractice — '
        'every row written before this field existed really was one',
        () {
      expect(ErrorSource.fromJson(null), ErrorSource.topicPractice);
      expect(ErrorSource.fromJson('something_unexpected'),
          ErrorSource.topicPractice);
    });
  });

  group('ErrorEntry.toMap/fromMap', () {
    test('round-trips the source field', () {
      final entry = ErrorEntry(
        topicId: 'articles',
        errorType: 'missing_article',
        timestamp: DateTime(2026, 1, 1),
        source: ErrorSource.dailyTest,
      );

      final restored = ErrorEntry.fromMap(entry.toMap());

      expect(restored.source, ErrorSource.dailyTest);
    });
  });
}
