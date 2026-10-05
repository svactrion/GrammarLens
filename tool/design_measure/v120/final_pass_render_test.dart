// 1.2.0 final pass: the screens without a mockup, with the real font, the
// real screens and fake services, light and dark.
//
//   DESIGN_MEASURE_OUT=docs/design/1.2.0/final-pass \
//     flutter test tool/design_measure/v120/final_pass_render_test.dart
//
// Images: `<screen>_<width>_<size>_<mode>.png` at 390 × 844 (the viewport),
// and `..._full.png` for the scrolling screens in a window tall enough to
// show the whole page.
//
// DESIGN_MEASURE_SWEEP=1 writes no images: it lays every screen out at
// 320, 360, 390 and 430 pt wide (844 tall) and at 375 × 667, at every text
// size, light and dark, in the real height and in a tall window (so lazy
// lists build every row), and writes `final_pass_sweep.txt`: each layout
// exception and each text that ends in an ellipsis. DESIGN_MEASURE_SCREENS
// (comma-separated names) limits either mode.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
import 'package:grammar_lens/screens/credits_screen.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/data_screen.dart';
import 'package:grammar_lens/screens/practice_length_picker.dart';
import 'package:grammar_lens/screens/results_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/screens/welcome_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/utils/loading_view.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

class _Subscription extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
}

class _Storage extends StorageService {
  @override
  Future<int> getFreePracticeCountForToday() async =>
      StorageService.freeDailyPracticeLimit;

  @override
  Future<void> recordPracticeCompletion(String topicId, int answered) async {}

  @override
  Future<void> insertErrors(List<ErrorEntry> entries) async {}

  @override
  Future<UserProfile?> getUserProfile() async => null;

  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      [
        for (final (prompt, mine, fixed) in [
          ('I saw ___ elephant at the zoo.', 'a', 'an'),
          ('She is ___ best student in the class.', 'a', 'the'),
        ])
          ErrorEntry(
            topicId: topicId,
            errorType: errorType,
            timestamp: DateTime(2026, 10, 3),
            prompt: prompt,
            userAnswer: mine,
            correctedAnswer: fixed,
            explanation: 'Use "an" before a vowel sound and "the" when '
                'there is only one of something.',
            source: ErrorSource.topicPractice,
          ),
      ];

  @override
  Future<AiConsent?> getAiConsent() async => null;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: 5, correct: 12, wrong: 6, skipped: 2);

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;

  @override
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async =>
      false;
}

final _topic = kTopics.first;

final _practiceItems = [
  for (final (id, text) in [
    ('i1', 'She ___ to the store yesterday.'),
    ('i2', 'I have never ___ sushi before.'),
    ('i3', 'They ___ home early last night.'),
    ('i4', 'If I ___ you, I would ask her.'),
    ('i5', 'We ___ dinner when the phone rang.'),
  ])
    PracticeItem(
        id: id, type: PracticeItemType.fillInBlank, instruction: text),
];

final _result = ScoringResult(topicId: _topic.id.name, feedback: const [
  ItemFeedback(
      itemId: 'i1',
      isCorrect: true,
      isSkipped: false,
      correctedAnswer: 'went',
      explanation: ''),
  ItemFeedback(
      itemId: 'i2',
      isCorrect: false,
      isSkipped: false,
      errorType: 'past_participle',
      rule: 'Present perfect: have + past participle.',
      correctedAnswer: 'eaten',
      explanation: 'After "have", use the past participle "eaten", not the '
          'past simple "ate".'),
  ItemFeedback(
      itemId: 'i3',
      isCorrect: true,
      isSkipped: false,
      correctedAnswer: 'went',
      explanation: ''),
  ItemFeedback(
      itemId: 'i4',
      isCorrect: false,
      isSkipped: true,
      correctedAnswer: 'were',
      explanation: 'In a second conditional, "were" is used for every '
          'subject.'),
  ItemFeedback(
      itemId: 'i5',
      isCorrect: true,
      isSkipped: false,
      correctedAnswer: 'were having',
      explanation: ''),
]);

DailyTestQuestion _q(String id, String topic, String text, String answer,
        {List<CommonWrongAnswer> wrong = const [], String? explanation}) =>
    DailyTestQuestion(
      item: PracticeItem(
          id: id, type: PracticeItemType.fillInBlank, instruction: text),
      topicId: topic,
      correctAnswer: answer,
      commonWrongAnswers: wrong,
      explanation: explanation,
    );

final _dailySet = DailyTestSet(day: '2026-10-05', questions: [
  _q('q1', 'articles', 'I bought ___ umbrella yesterday.', 'an'),
  _q('q2', 'articles', 'She is ___ tallest girl in her class.', 'the',
      wrong: const [
        CommonWrongAnswer(
            answer: 'a', comment: 'Superlatives take "the": there is one.'),
      ],
      explanation: 'A superlative names one person, so it takes "the".'),
  _q('q3', 'tenseSelection', 'Yesterday we ___ to the beach.', 'went',
      explanation: '"Yesterday" asks for the past simple.'),
  _q('q4', 'modalVerbs', 'You ___ wear a seatbelt. It is the law.', 'must'),
  _q('q5', 'prepositions', 'The meeting is ___ Monday.', 'on'),
]);

const _dailyAnswers = {
  'q1': 'an',
  'q2': 'a',
  'q3': 'go',
  'q4': '',
  'q5': 'on',
};

typedef _Screen = ({
  String name,
  bool scrolls,
  Widget Function() build,
  Future<void> Function(WidgetTester tester)? after,
});

final List<_Screen> _screens = [
  (
    name: 'welcome',
    scrolls: false,
    build: () => WelcomeScreen(onGetStarted: () {}),
    after: null,
  ),
  (
    name: 'results',
    scrolls: true,
    build: () => ResultsScreen(
          topic: _topic,
          result: _result,
          practiceSet:
              PracticeSet(topicId: _topic.id.name, items: _practiceItems),
          answers: const {
            'i1': 'went',
            'i2': 'ate',
            'i3': 'went',
            'i4': '',
            'i5': 'were having',
          },
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Subscription(),
        ),
    after: null,
  ),
  (
    name: 'daily_test_result',
    scrolls: true,
    build: () => DailyTestResultScreen(
          dailyTestSet: _dailySet,
          answers: _dailyAnswers,
          dailyTestService: DailyTestService(
              claudeService: ClaudeService(), storageService: _Storage()),
          analyticsService: AnalyticsService(),
        ),
    after: null,
  ),
  (
    name: 'weak_spot_detail',
    scrolls: true,
    build: () => WeakSpotDetailScreen(
          topic: _topic,
          spot: WeakSpot(
            topicId: _topic.id.name,
            errorType: 'missing_article',
            frequency: 4,
            lastSeen: DateTime(2026, 10, 3),
            latestExplanation: 'Use "an" before a vowel sound.',
            latestRule: 'a / an before a singular countable noun.',
          ),
          claudeService: ClaudeService(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Subscription(),
        ),
    after: null,
  ),
  (
    name: 'ai_consent',
    scrolls: true,
    build: () => const AiConsentScreen(),
    after: null,
  ),
  (
    name: 'data',
    scrolls: true,
    build: () => DataScreen(storageService: _Storage()),
    after: null,
  ),
  (
    name: 'credits',
    scrolls: true,
    build: () => const CreditsScreen(),
    after: null,
  ),
  (
    name: 'avatar_picker',
    scrolls: false,
    build: () => AvatarPickerScreen(
          currentAvatar: Avatar.values.first,
          onAvatarChanged: (_) {},
          heroTag: 'final_pass_avatar',
        ),
    after: null,
  ),
  (
    name: 'practice_length_picker',
    scrolls: false,
    build: () => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showPracticeLengthPicker(
                    context: context, initial: PracticeLength.standard),
                child: const Text('open'),
              ),
            ),
          ),
        ),
    after: (tester) async {
      await tester.tap(find.text('open'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
  ),
  (
    name: 'loading',
    scrolls: false,
    build: () => Scaffold(
          appBar: AppBar(title: const Text('Topic Practice')),
          body: const LoadingView(message: 'Preparing your questions…'),
        ),
    after: null,
  ),
  (
    name: 'medal_celebration',
    scrolls: false,
    build: () => Scaffold(
          body: MedalCelebration.tier(
            tier: MedalTier.silver,
            theme: ClimbThemeRotation.shownFor(2026, 10),
            month: 10,
            onClose: () {},
          ),
        ),
    after: null,
  ),
  (
    name: 'medal_celebration_welcome',
    scrolls: false,
    build: () => Scaffold(body: MedalCelebration.welcome(onClose: () {})),
    after: null,
  ),
];

void main() {
  final out = outDir();
  final sweep = Platform.environment['DESIGN_MEASURE_SWEEP'] == '1';
  final only = Platform.environment['DESIGN_MEASURE_SCREENS']
      ?.split(',')
      .map((s) => s.trim())
      .toSet();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  final screens = [
    for (final s in _screens)
      if (only == null || only.contains(s.name)) s
  ];
  final report = StringBuffer();
  tearDownAll(() {
    if (sweep) {
      File('$out/final_pass_sweep.txt').writeAsStringSync(report.toString());
    }
  });

  Future<void> pumpScreen(WidgetTester tester, _Screen screen, Size size,
      AppTextSize textSize, Brightness b, GlobalKey key) async {
    DebugTools.enabledForTesting = false;
    addTearDown(() => DebugTools.enabledForTesting = true);
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
    addTearDown(tester.view.reset);
    addTearDown(AppMessenger.clear);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(b, textSize: textSize),
        scaffoldMessengerKey: AppMessenger.key,
        // The ambient motion is held still: one frame to judge.
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: screen.build(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 2));
    if (screen.after != null) await screen.after!(tester);
    await tester.runAsync(() async {
      final context = key.currentContext!;
      await Future.wait([
        for (final e in find.byType(MedalBadge).evaluate())
          precacheImage(AssetImage((e.widget as MedalBadge).asset), context),
        for (final e in find.byType(Image).evaluate())
          if ((e.widget as Image).image is AssetImage)
            precacheImage((e.widget as Image).image, context),
      ]);
    });
    await tester.pump();
  }

  if (sweep) {
    const sizes = [
      Size(320, 844),
      Size(360, 844),
      Size(390, 844),
      Size(430, 844),
      Size(375, 667),
    ];
    for (final screen in screens) {
      for (final size in sizes) {
        for (final tall in [false, true]) {
          if (tall && !screen.scrolls) continue;
          for (final textSize in AppTextSize.values) {
            for (final b in Brightness.values) {
              final id = '${screen.name} ${size.width.toInt()}x'
                  '${tall ? 'tall' : size.height.toInt()} ${textSize.name} '
                  '${b.name}';
              testWidgets(id, (tester) async {
                final key = GlobalKey();
                final errors = <String>[];
                final previous = FlutterError.onError;
                FlutterError.onError = (d) => errors.add(d
                    .exceptionAsString()
                    .split('\n')
                    .first);
                try {
                  await pumpScreen(
                      tester,
                      screen,
                      tall ? Size(size.width, 2600) : size,
                      textSize,
                      b,
                      key);
                } finally {
                  FlutterError.onError = previous;
                }
                final cut = <String>[];
                void visit(RenderObject o) {
                  if (o is RenderParagraph && o.didExceedMaxLines) {
                    final text = o.text.toPlainText();
                    cut.add(text.length > 60
                        ? '${text.substring(0, 60)}…'
                        : text);
                  }
                  o.visitChildren(visit);
                }

                visit(tester.renderObject(find.byKey(key)));
                if (errors.isNotEmpty || cut.isNotEmpty) {
                  report.writeln(id);
                  for (final e in errors.toSet()) {
                    report.writeln('  exception: $e');
                  }
                  for (final c in cut.toSet()) {
                    report.writeln('  ellipsis: "$c"');
                  }
                }
              });
            }
          }
        }
      }
    }
    return;
  }

  const textSize = AppTextSize.medium;
  for (final screen in screens) {
    for (final tall in [false, true]) {
      if (tall && !screen.scrolls) continue;
      for (final b in Brightness.values) {
        final file = '${screen.name}_390_${textSize.name}_${b.name}'
            '${tall ? '_full' : ''}';
        testWidgets(file, (tester) async {
          final key = GlobalKey();
          await pumpScreen(tester, screen, Size(390, tall ? 2000 : 844),
              textSize, b, key);
          await tester.runAsync(() async {
            final img = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('$out/$file.png').writeAsBytesSync(bytes!.buffer.asUint8List());
          });
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
