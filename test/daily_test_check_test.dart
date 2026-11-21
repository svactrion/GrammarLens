import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/question_view.dart';

class _Service extends DailyTestService {
  final DailyTestSet set;
  _Service(this.set)
      : super(claudeService: ClaudeService(), storageService: StorageService());

  @override
  Future<DailyTestSet> getTodaysSet() async => set;
}

/// UI polish §1.5 / V07–V09: "Check" grades each answer on the device and
/// shows the sheet; the chip's points equal what the completion awards.
void main() {
  final set = DailyTestSet(day: '2026-11-17', questions: kDayZeroQuestions);
  setUp(() => HapticMap.log = []);

  Future<Map<String, String>?> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Map<String, String>? finished;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: DailyTestScreen(
        dailyTestService: _Service(set),
        analyticsService: AnalyticsService(),
        userName: 'Ada',
        onFinished: (_, answers) => finished = answers,
        onExit: () {},
      ),
    ));
    await tester.pumpAndSettle();
    return finished;
  }

  int chipPoints(WidgetTester tester) =>
      tester.widget<PointsChip>(find.byKey(DailyTestScreen.pointsKey)).points;

  Future<void> answer(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(QuestionView.answerFieldKey), text);
    await tester.pump();
    await tester.tap(find.byKey(DailyTestScreen.checkKey));
    await tester.pumpAndSettle();
  }

  // Fix round 4, item 6 (SPEC §3.4 v12): Check's right / wrong feedback is
  // its one haptic (the button added a light one before); the sheet's
  // forward button gives light.
  testWidgets('v12: one haptic per Check, then light for Continue',
      (tester) async {
    await pump(tester);
    await answer(tester, set.questions.first.correctAnswer);
    expect(HapticMap.log, ['success']);
    HapticMap.log = [];
    await tester.tap(find.byKey(DailyTestScreen.continueKey));
    await tester.pumpAndSettle();
    expect(HapticMap.log, ['light']);
    HapticMap.log = [];
    await answer(tester, 'something wrong');
    expect(HapticMap.log, ['warning']);
  });

  testWidgets('a right answer: "Nice, Ada!", +2, success; the chip counts 2',
      (tester) async {
    await pump(tester);
    await answer(tester, set.questions.first.correctAnswer);
    expect(find.text('Nice, Ada!'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(chipPoints(tester), 2);
    expect(HapticMap.log, contains('success'));
  });

  testWidgets(
      'a wrong answer: "Almost!", the correct answer, +1, a warning; the box '
      'is read-only', (tester) async {
    await pump(tester);
    await answer(tester, 'something wrong');
    expect(find.text('Almost!'), findsOneWidget);
    expect(find.text(set.questions.first.correctAnswer), findsWidgets);
    expect(find.text('+1'), findsOneWidget);
    expect(chipPoints(tester), 1);
    expect(HapticMap.log, contains('warning'));
    final field =
        tester.widget<TextField>(find.byKey(QuestionView.answerFieldKey));
    expect(field.readOnly, isTrue);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
        'V09: after a wrong answer the book flies from the weak spots line to '
        'the Review tab\'s place (the bottom middle) and is gone; none for '
        'a right answer${reduceMotion ? ' (Reduce Motion: no flight)' : ''}',
        (tester) async {
      if (reduceMotion) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      await pump(tester);
      final book = find.byKey(DailyTestScreen.bookFlightKey);
      await tester.enterText(
          find.byKey(QuestionView.answerFieldKey), 'something wrong');
      await tester.pump();
      await tester.tap(find.byKey(DailyTestScreen.checkKey));
      await tester.pump();
      // Waits for the line to pop in first.
      await tester.pump(const Duration(milliseconds: 500));
      expect(book, findsNothing);
      if (reduceMotion) {
        await tester.pumpAndSettle();
        expect(book, findsNothing);
        return;
      }
      await tester.pump(const Duration(milliseconds: 150));
      expect(book, findsOneWidget);
      final line = tester.getCenter(find.text('This goes to your weak spots'));
      final early = tester.getCenter(book);
      await tester.pump(const Duration(milliseconds: 400));
      final late = tester.getCenter(book);
      const size = Size(402, 874);
      expect(late.dy, greaterThan(line.dy), reason: 'down to the bar');
      expect((late.dx - size.width / 2).abs(),
          lessThan((early.dx - size.width / 2).abs() + .5),
          reason: 'towards the middle tab');
      await tester.pumpAndSettle();
      expect(book, findsNothing);

      // A right answer: no book.
      await tester.tap(find.byKey(DailyTestScreen.continueKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(QuestionView.answerFieldKey),
          set.questions[1].correctAnswer);
      await tester.pump();
      await tester.tap(find.byKey(DailyTestScreen.checkKey));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(book, findsNothing);
      }
    });
  }

  testWidgets(
      'through the whole test: the answers handed over are the ones checked',
      (tester) async {
    Map<String, String>? finished;
    tester.view.physicalSize = const Size(402, 874) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: DailyTestScreen(
        dailyTestService: _Service(set),
        analyticsService: AnalyticsService(),
        onFinished: (_, answers) => finished = answers,
        onExit: () {},
      ),
    ));
    await tester.pumpAndSettle();
    var expected = 0;
    for (final (i, q) in set.questions.indexed) {
      final right = i.isEven;
      await answer(tester, right ? q.correctAnswer : 'nope');
      expected += right ? 2 : 1;
      expect(chipPoints(tester), expected);
      await tester.tap(find.byKey(DailyTestScreen.continueKey));
      await tester.pumpAndSettle();
    }
    expect(finished, isNotNull);
    expect(finished!.length, set.questions.length);
  });
}
