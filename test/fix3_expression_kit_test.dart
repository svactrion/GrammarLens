import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/companion_dialog.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/error_state.dart';
import 'package:grammar_lens/widgets/question_view.dart';

import 'support/fix3_render.dart';

/// Fix round 3, B8 (SPEC §3.5, v11): every companion shows its board's mood
/// and that mood's prop. Wrong answers (V09, Q04 / Q05 wrong) use `oops`:
/// the head shake and the falling sweat drop. The sad dialogs (V13b, R10,
/// R08 reset) show the cloud. With `FIX3_CAPTURE=1` the renders go to
/// `build/fix3-captures/`.
class _Service extends DailyTestService {
  final DailyTestSet set;
  _Service(this.set)
      : super(claudeService: ClaudeService(), storageService: StorageService());

  @override
  Future<DailyTestSet> getTodaysSet() async => set;
}

const _multi = PracticeItem(
  id: 'multi',
  type: PracticeItemType.fillInBlank,
  instruction: 'I saw ____ owl and ____ eagle.',
);

/// The question's companion props on screen.
List<String> _props(WidgetTester tester, Finder companion) => [
      for (final e in find
          .descendant(
              of: companion, matching: find.byKey(CompanionView.propKey))
          .evaluate()) ...[
        for (final i in find
            .descendant(
                of: find.byWidget(e.widget), matching: find.byType(Image))
            .evaluate())
          ((i.widget as Image).image as AssetImage).assetName
      ],
    ];

/// The body's turn, in radians, read from its transform.
double _turn(WidgetTester tester, Finder companion) {
  final body = tester.widget<Transform>(find
      .descendant(of: companion, matching: find.byKey(CompanionView.bodyKey))
      .first);
  final m = body.transform;
  return m.entry(1, 0).abs();
}

void main() {
  final cases =
      <(String, DailyTestQuestion, Future<void> Function(WidgetTester))>[
    (
      'V09 (fill in the blank)',
      kDayZeroQuestions
          .firstWhere((q) => q.item.type == PracticeItemType.fillInBlank),
      (tester) async {
        await tester.enterText(
            find.byKey(QuestionView.answerFieldKey), 'something wrong');
      },
    ),
    (
      'Q05 (error correction)',
      kDayZeroQuestions
          .firstWhere((q) => q.item.type == PracticeItemType.errorCorrection),
      (tester) async {
        await tester.enterText(
            find.byKey(QuestionView.answerFieldKey), 'Something wrong here');
      },
    ),
    (
      'Q04 (two blanks)',
      DailyTestQuestion(
        item: _multi,
        topicId: 'articles',
        correctAnswer: 'an / an',
        commonWrongAnswers: const [],
      ),
      (tester) async {
        await tester.enterText(find.byKey(QuestionView.blankBoxKey(0)), 'xx');
        await tester.enterText(find.byKey(QuestionView.blankBoxKey(1)), 'yy');
      },
    ),
  ];

  for (final (name, question, answerWrong) in cases) {
    testWidgets(
        '$name wrong: the companion shows oops, shakes its head and drops '
        'its sweat', (tester) async {
      await pumpFix3(
        tester,
        DailyTestScreen(
          dailyTestService:
              _Service(DailyTestSet(day: '2026-11-18', questions: [question])),
          analyticsService: AnalyticsService(),
          userName: 'Ada',
          hero: Avatar.fox,
          onFinished: (set, answers) {},
          onExit: () {},
        ),
        size: const Size(402, 874),
        top: 62,
      );
      await answerWrong(tester);
      await tester.pump();
      await tester.tap(find.byKey(DailyTestScreen.checkKey));
      // The feedback panel springs in; the shake runs in its first 360 ms.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final oops = find.byWidgetPredicate(
          (w) => w is CompanionView && w.mood == CompanionMood.oops);
      expect(oops, findsOneWidget);
      expect(find.text('Oops! So close.'), findsOneWidget);
      expect(_props(tester, oops),
          contains('assets/companions/props/prop_sweat.webp'));
      var turned = 0.0;
      for (var i = 0; i < 6; i++) {
        turned = turned > _turn(tester, oops) ? turned : _turn(tester, oops);
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(turned, greaterThan(.05), reason: 'the head shakes');
      await tester.pumpAndSettle();
      // No cheer anywhere on a wrong answer.
      expect(
          find.byWidgetPredicate(
              (w) => w is CompanionView && w.mood == CompanionMood.cheer),
          findsNothing);
      if (name.startsWith('V09')) await fix3Capture(tester, 'V09-oops');
    });
  }

  // One component for all three: V13b (premium_screen), R10 (the Daily
  // Test's and practice's leave dialog, the default sad mood) and R08's
  // reset (data_screen); each passes the sad mood.
  testWidgets(
      'the companion dialog (V13b, R10, R08 reset): the sad companion shows '
      'its cloud, over no text', (tester) async {
    await pumpFix3(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showCompanionDialog(
                context: context,
                hero: Avatar.fox,
                title: 'Leaving already, Ada?',
                body: 'Your free trial is one tap away.',
                primaryLabel: 'Start my free trial',
                secondaryLabel: 'Continue with free',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      size: const Size(402, 874),
      top: 62,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final sad = find.byWidgetPredicate(
        (w) => w is CompanionView && w.mood == CompanionMood.sad);
    expect(sad, findsOneWidget);
    expect(_props(tester, sad),
        contains('assets/companions/props/prop_cloud.webp'));
    final cloud = tester.getRect(find
        .descendant(of: sad, matching: find.byKey(CompanionView.propKey))
        .first);
    for (final t in [
      'Leaving already, Ada?',
      'Your free trial is one tap away.',
      'Start my free trial',
      'Continue with free',
    ]) {
      expect(cloud.overlaps(tester.getRect(find.text(t))), isFalse, reason: t);
    }
    await fix3Capture(tester, 'V13b-cloud');
  });

  testWidgets('R11: the error state\'s sad companion shows its cloud',
      (tester) async {
    await pumpFix3(
      tester,
      Scaffold(body: ErrorState(hero: Avatar.fox, onRetry: () async => false)),
      size: const Size(402, 874),
      top: 62,
    );
    final sad = find.byWidgetPredicate(
        (w) => w is CompanionView && w.mood == CompanionMood.sad);
    expect(_props(tester, sad),
        contains('assets/companions/props/prop_cloud.webp'));
    await fix3Capture(tester, 'R11-cloud');
  });
}
