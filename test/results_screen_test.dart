import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
import 'package:grammar_lens/screens/results_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/result_score_band.dart';

/// Topic Practice's own results screen had no test file at all before this
/// (docs/design-audit.md, Batch 0/4) — added narrowly for the one thing
/// that batch asks for: confirming this screen gets its score from the
/// same shared ResultScoreBand widget DailyTestResultScreen uses, rather
/// than the two screens each independently formatting their own score line.
void main() {
  testWidgets('shows its score via the shared ResultScoreBand widget',
      (tester) async {
    final topic = kTopics.first;
    final practiceSet = PracticeSet(
      topicId: topic.id.name,
      items: const [
        PracticeItem(
          id: 'i1',
          type: PracticeItemType.fillInBlank,
          instruction: 'She ___ to the store yesterday.',
        ),
        PracticeItem(
          id: 'i2',
          type: PracticeItemType.fillInBlank,
          instruction: 'They ___ home early.',
        ),
      ],
    );
    // One correct, one skipped, no actual mistakes — keeps this test clear
    // of StorageService.insertErrors, which a real (non-fake) StorageService
    // can't service under test.
    final result = ScoringResult(
      topicId: topic.id.name,
      feedback: const [
        ItemFeedback(
          itemId: 'i1',
          isCorrect: true,
          isSkipped: false,
          correctedAnswer: 'went',
          explanation: '',
        ),
        ItemFeedback(
          itemId: 'i2',
          isCorrect: false,
          isSkipped: true,
          correctedAnswer: 'went',
          explanation: '',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: ResultsScreen(
          topic: topic,
          result: result,
          practiceSet: practiceSet,
          answers: const {'i1': 'went', 'i2': ''},
          storageService: StorageService(),
          analyticsService: AnalyticsService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResultScoreBand), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResultScoreBand),
        matching: find.text('1/2 correct · 1 skipped'),
      ),
      findsOneWidget,
    );
  });
}
