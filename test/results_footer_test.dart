import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/results_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';

/// Topic Practice results (final screens A3): "Back to topics" sits in a
/// fixed bottom bar, as on Daily Test results, and a message never covers
/// it.
class _Subs extends SubscriptionService {
  final bool access;
  _Subs(this.access);
  @override
  Future<bool> get hasFullAccess async => access;
}

class _Storage extends StorageService {
  final int used;
  _Storage(this.used);
  @override
  Future<int> getFreePracticeCountForToday() async => used;
  @override
  Future<void> recordPracticeCompletion(String topicId, int answered) async {}
  @override
  Future<void> insertErrors(List<ErrorEntry> entries) async {}
  @override
  Future<UserProfile?> getUserProfile() async => null;
}

void main() {
  tearDown(AppMessenger.clear);
  final topic = kTopics.first;
  final items = [
    for (var i = 0; i < 10; i++)
      PracticeItem(
          id: 'i$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'Sentence number $i with a ___ in it.'),
  ];
  final result = ScoringResult(topicId: topic.id.name, feedback: [
    for (var i = 0; i < 10; i++)
      ItemFeedback(
          itemId: 'i$i',
          isCorrect: i.isEven,
          isSkipped: false,
          correctedAnswer: 'gap',
          explanation: i.isEven ? '' : 'An explanation of the mistake.'),
  ]);

  Future<void> pump(WidgetTester tester,
      {required bool access, required int used}) async {
    tester.view.physicalSize = const Size(375, 667) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 20 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      scaffoldMessengerKey: AppMessenger.key,
      home: ResultsScreen(
        topic: topic,
        result: result,
        practiceSet: PracticeSet(topicId: topic.id.name, items: items),
        answers: {for (final i in items) i.id: 'gap'},
        storageService: _Storage(used),
        analyticsService: AnalyticsService(),
        subscriptionService: _Subs(access),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final (access, used, type) in [
    (true, 0, FilledButton),
    (false, StorageService.freeDailyPracticeLimit, OutlinedButton),
  ]) {
    testWidgets(
        '"Back to topics" is in the fixed bar, in view without scrolling '
        '(${type == FilledButton ? 'filled' : 'outlined, under the offer'})',
        (tester) async {
      await pump(tester, access: access, used: used);
      final footer = find.byKey(ResultsScreen.footerKey);
      final button = find.descendant(
          of: footer, matching: find.widgetWithText(type, 'Back to topics'));
      expect(button, findsOneWidget);
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(667));
      // Scrolling the results does not move it.
      final before = tester.getRect(button);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(button), before);

      AppMessenger.show('Could not save this to your error profile: x');
      await tester.pumpAndSettle();
      final message = tester.getRect(find
          .descendant(
              of: find.byType(SnackBar), matching: find.byType(Material))
          .first);
      expect(message.bottom, lessThanOrEqualTo(tester.getRect(footer).top));
    });
  }
}
