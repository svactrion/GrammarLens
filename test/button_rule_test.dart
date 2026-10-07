import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/practice_length_picker.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';

/// The owner's button rule (2026-10-06, final screens Part A1): orange for
/// a screen's one main forward action on a neutral surface; navy for
/// actions on an orange surface and for secondary, helper and exit
/// actions; red for destructive ones.
class _Subs extends SubscriptionService {
  final bool access;
  _Subs(this.access);
  @override
  Future<bool> get hasFullAccess async => access;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

class _Storage extends StorageService {
  final int freeUsed;
  final bool welcome;
  _Storage({this.freeUsed = 0, this.welcome = false});

  @override
  Future<int> getFreePracticeCountForToday() async => freeUsed;
  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      const [];
  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      const [];
  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};
  @override
  Future<ReviewSortOrder> getReviewSortOrder() async => ReviewSortOrder.recent;
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: 1, correct: 1, wrong: 0, skipped: 0);
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];
  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;
  @override
  Future<bool> completeDailyTest(
          Map<String, String> answers, List<ErrorEntry> errorEntries,
          {String? day, DateTime? completedAt}) async =>
      welcome;
}

/// The fill a filled button is drawn with.
Color _fill(WidgetTester tester, String label) {
  final button = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  final material = tester.widget<Material>(
      find.descendant(of: button.first, matching: find.byType(Material)).first);
  return material.color!;
}

/// The edge a filled button is drawn with (none for orange and red).
BorderSide? _edge(WidgetTester tester, String label) {
  final button = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  final material = tester.widget<Material>(
      find.descendant(of: button.first, matching: find.byType(Material)).first);
  final shape = material.shape;
  return shape is OutlinedBorder ? shape.side : null;
}

void main() {
  tearDown(AppMessenger.clear);

  for (final brightness in Brightness.values) {
    final theme = buildAppTheme(brightness);
    final orange = theme.colorScheme.primary;
    final navy =
        (brightness == Brightness.dark ? AppPalette.dark : AppPalette.light)
            .button;

    void expectOrange(WidgetTester tester, String label) {
      expect(_fill(tester, label), orange, reason: label);
      expect(_edge(tester, label)?.style ?? BorderStyle.none, BorderStyle.none,
          reason: '$label has no navy edge');
    }

    void expectNavy(WidgetTester tester, String label) =>
        expect(_fill(tester, label), navy, reason: label);

    testWidgets('${brightness.name}: the length picker starts in orange',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPracticeLengthPicker(
                  context: context, initial: PracticeLength.standard),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expectOrange(tester, 'Start 5 questions');
    });

    testWidgets(
        '${brightness.name}: Review\'s empty state goes to the Daily '
        'Test in orange', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: ReviewScreen(
          claudeService: ClaudeService(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Subs(false),
          active: true,
          onGoToPractice: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expectOrange(tester, 'Go to Daily Test');
    });

    for (final (access, used, label) in [
      (true, 0, 'Practice this'),
      (false, 0, 'Start free practice'),
      (false, StorageService.freeDailyPracticeLimit, 'Practice with Premium'),
    ]) {
      testWidgets('${brightness.name}: the weak spot\'s "$label" is orange',
          (tester) async {
        tester.view.physicalSize = const Size(390, 1400) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: WeakSpotDetailScreen(
            topic: kTopics.first,
            spot: WeakSpot(
                topicId: kTopics.first.id.name,
                errorType: 'missing_article',
                frequency: 2,
                lastSeen: DateTime(2026, 10, 1)),
            claudeService: ClaudeService(),
            storageService: _Storage(freeUsed: used),
            analyticsService: AnalyticsService(),
            subscriptionService: _Subs(access),
          ),
        ));
        await tester.pumpAndSettle();
        expectOrange(tester, label);
      });
    }

    final question = DailyTestQuestion(
      item: const PracticeItem(
          id: 'q1',
          type: PracticeItemType.fillInBlank,
          instruction: 'I bought ___ umbrella.'),
      topicId: 'articles',
      correctAnswer: 'an',
      commonWrongAnswers: const [],
    );

    Future<void> pumpResult(WidgetTester tester,
        {required Map<String, String> answers,
        bool welcome = false,
        bool isDay0 = false}) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = _Storage(welcome: welcome);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        scaffoldMessengerKey: AppMessenger.key,
        home: DailyTestResultScreen(
          key: UniqueKey(),
          dailyTestSet: DailyTestSet(day: '2026-01-01', questions: [question]),
          answers: answers,
          dailyTestService: DailyTestService(
              claudeService: ClaudeService(), storageService: storage),
          analyticsService: AnalyticsService(),
          isDay0: isDay0,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
        '${brightness.name}: Daily Test results: "See your climb" '
        'orange, "Back to Home" and "Continue" navy', (tester) async {
      await pumpResult(tester, answers: const {'q1': 'an'});
      expectOrange(tester, 'See your climb');
      await pumpResult(tester, answers: const {});
      expectNavy(tester, 'Back to Home');
      await pumpResult(tester, answers: const {'q1': 'an'}, isDay0: true);
      expectNavy(tester, 'Continue');
    });

    testWidgets(
        '${brightness.name}: Daily Test results: "Start my climb" '
        'orange', (tester) async {
      await pumpResult(tester, answers: const {'q1': 'an'}, welcome: true);
      expectOrange(tester, 'Start my climb');
    });

    testWidgets(
        '${brightness.name}: AI consent\'s "Agree and continue" '
        'stays navy (consent is not nudged)', (tester) async {
      await tester
          .pumpWidget(MaterialApp(theme: theme, home: const AiConsentScreen()));
      await tester.pumpAndSettle();
      expectNavy(tester, 'Agree and continue');
    });
  }
}
