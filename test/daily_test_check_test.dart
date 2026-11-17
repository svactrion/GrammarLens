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
