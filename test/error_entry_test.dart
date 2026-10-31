import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';

void main() {
  group('ErrorSource', () {
    test('round-trips through toJson/fromJson', () {
      for (final source in ErrorSource.values) {
        expect(ErrorSource.fromJson(source.toJson()), source);
      }
    });

    test(
        'an unrecognized or missing value defaults to topicPractice — '
        'every row written before this field existed really was one', () {
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

    test('round-trips the per-blank answers (1.4.0 B8)', () {
      final entry = ErrorEntry(
        topicId: 'articles',
        errorType: 'article_use',
        timestamp: DateTime(2026, 1, 1),
        userAnswer: 'We had lunch at a small café near ____ station.',
        source: ErrorSource.topicPractice,
        userBlanks: const [
          BlankAnswer.noArticle(),
          BlankAnswer('a'),
          BlankAnswer(''),
        ],
      );

      final map = entry.toMap();
      expect(
          map['user_blanks'], '[{"noArticle":true},{"text":"a"},{"text":""}]');
      final restored = ErrorEntry.fromMap(map);
      expect(
          restored.userBlanks!.map((b) => b.noArticle), [true, false, false]);
      expect(restored.userBlanks!.map((b) => b.text), ['', 'a', '']);
    });

    test(
        'a single-box answer stores null, and a row from before the column '
        'reads as null', () {
      final entry = ErrorEntry(
        topicId: 'articles',
        errorType: 'article_use',
        timestamp: DateTime(2026, 1, 1),
        source: ErrorSource.topicPractice,
      );
      expect(entry.toMap()['user_blanks'], isNull);
      expect(ErrorEntry.fromMap(entry.toMap()).userBlanks, isNull);

      final old = Map<String, Object?>.of(entry.toMap())..remove('user_blanks');
      expect(ErrorEntry.fromMap(old).userBlanks, isNull);
    });
  });
}
