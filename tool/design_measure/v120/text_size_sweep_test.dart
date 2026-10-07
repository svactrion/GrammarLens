// 1.2.0 final pass (4c): the approved screens with the real font at the
// shifted text sizes, at 320 × 568, 360 × 780, 390 × 844, 430 × 932 and
// 375 × 667, light and dark. Writes `text_size_sweep.txt`: every layout
// exception, every text that ends in an ellipsis, and the one-line rules
// (the trail plaque, the nav bar labels, the segmented controls), the
// paywall footer's share and where its links are, and on the question
// screen whether the answer field is above the keyboard.
//
//   DESIGN_MEASURE_OUT=build/design_measure/v120_sweep \
//     flutter test tool/design_measure/v120/text_size_sweep_test.dart
//
// DESIGN_MEASURE_SIZES (large) and DESIGN_MEASURE_SCREENS (all) narrow it;
// DESIGN_MEASURE_SHOTS=1 also writes a PNG per case.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/app_segmented_button.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/question_view.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

class _Subs extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
  @override
  Future<Offering?> getOfferings() async => _offering();
  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
          List<String> productIds) async =>
      {for (final id in productIds) id: TrialEligibility.eligible};
}

Offering _offering() {
  const context = PresentedOfferingContext('default', null, null);
  const monthly = Package(
      '\$rc_monthly',
      PackageType.monthly,
      StoreProduct(
          'grammarlens_premium_monthly', '', 'Monthly', 5.99, '\$5.99', 'USD',
          introductoryPrice:
              IntroductoryPrice(0, '\$0.00', 'P3D', 1, PeriodUnit.day, 3),
          subscriptionPeriod: 'P1M'),
      context);
  const annual = Package(
      '\$rc_annual',
      PackageType.annual,
      StoreProduct(
          'grammarlens_premium_annual', '', 'Annual', 49.99, '\$49.99', 'USD',
          introductoryPrice:
              IntroductoryPrice(0, '\$0.00', 'P1W', 1, PeriodUnit.week, 1),
          subscriptionPeriod: 'P1Y',
          pricePerMonth: 4.16,
          pricePerMonthString: '\$4.16'),
      context);
  return const Offering('default', '', {}, [monthly, annual],
      monthly: monthly, annual: annual);
}

class _Storage extends StorageService {
  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: 12, correct: 30, wrong: 14, skipped: 4);
  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => null;
  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => null;
  @override
  Future<bool> claimOneTimeFlag(String key) async => false;
  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      [
        for (final (topic, type, n) in [
          ('modalPastForms', 'reported_speech_backshift', 5),
          ('articles', 'missing_article', 3),
          ('tenseSelection', 'past_simple_vs_present_perfect', 2),
        ])
          WeakSpot(
            topicId: topic,
            errorType: type,
            frequency: n,
            lastSeen: DateTime(2026, 10, 4),
            latestExplanation: 'Move the tense one step back in reported '
                'speech when the reporting verb is in the past.',
            latestRule: 'Backshift in reported speech.',
          ),
      ];
  @override
  Future<int> getFreePracticeCountForToday() async => 0;
  @override
  Future<ReviewSortOrder> getReviewSortOrder() async => ReviewSortOrder.recent;
  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {
        'modalVerbs': TopicStats(practiced: 12, weakSpotCount: 2),
        'articles': TopicStats(practiced: 1, weakSpotCount: 1),
      };
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];
  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async =>
      MonthlyMedalProgress(
        year: 2026,
        month: 10,
        score: 96,
        maxScore: MonthlyMedalRules.maxScore(2026, 10),
        activeDays: 12,
        correct: 0,
        wrong: 0,
        skipped: 0,
      );
  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => [
        MonthlyMedalResult(
          year: 2026,
          month: 9,
          score: 200,
          maxScore: MonthlyMedalRules.maxScore(2026, 9),
          activeDays: 20,
          correct: 0,
          wrong: 0,
          skipped: 0,
          tier: MedalTier.gold,
          ruleVersion: 1,
          finalizedAt: DateTime(2026, 10, 1),
        ),
      ];
  @override
  Future<WelcomeBadge?> getWelcomeBadge() async => WelcomeBadge(
      earnedAt: DateTime(2026, 9, 2), ruleVersion: 1, backfilled: false);
  @override
  Future<Map<(int, int), String>> getClimbMonthThemes() async => const {};
  @override
  Future<UserProfile?> getUserProfile() async => UserProfile(
      name: 'Ada', learningGoal: LearningGoal.work, avatar: Avatar.values[13]);
}

const _tabs = [
  NavShellTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
  NavShellTab(
      icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Review'),
  NavShellTab(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile'),
];

Widget _shell(int index, Widget body) => FloatingNavShell(
    body: body, tabs: _tabs, selectedIndex: index, onTabChange: (_) {});

const _practiceSet = PracticeSet(topicId: 'gerundVsInfinitive', items: [
  PracticeItem(
    id: 'long',
    type: PracticeItemType.sentenceWriting,
    context: 'You are chatting with a new friend about your hobbies and '
        'free-time activities. You want to mention one thing you really '
        'enjoy doing and one thing you have recently decided to start doing.',
    instruction: "Write two connected sentences: use a gerund after a verb "
        "like 'enjoy', 'love', or 'can’t stand' for the first, and an "
        "infinitive after a verb like 'decide', 'plan', or 'want' for the "
        'second.',
  ),
]);

typedef _Screen = ({
  String name,
  double keyboard,
  Widget Function(AppTextSize size) build,
  Future<void> Function(WidgetTester tester)? after,
});

final List<_Screen> _screens = [
  (
    name: 'home',
    keyboard: 0,
    build: (size) => _shell(
        0,
        HomeScreen(
          active: true,
          userName: 'Ada',
          avatar: Avatar.values.first,
          claudeService: ClaudeService(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Subs(),
          clock: () => DateTime(2026, 10, 14, 15),
        )),
    after: null,
  ),
  (
    name: 'review',
    keyboard: 0,
    build: (size) => _shell(
        1,
        ReviewScreen(
          claudeService: ClaudeService(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Subs(),
          active: true,
          onGoToPractice: () {},
        )),
    after: null,
  ),
  (
    name: 'profile',
    keyboard: 0,
    build: (size) => _shell(
        2,
        SettingsScreen(
          active: true,
          themeMode: AppThemeMode.light,
          onSelectThemeMode: (_) {},
          textSize: size,
          onSelectTextSize: (_) {},
          profile: const UserProfile(name: 'Ada', learningGoal: LearningGoal.general)
              .copyWith(avatar: Avatar.values.last),
          storageService: _Storage(),
          onProfileUpdated: (_) {},
          analyticsService: AnalyticsService(),
          onResetOnboarding: () {},
        )),
    after: null,
  ),
  (
    name: 'topic_practice',
    keyboard: 0,
    build: (size) => TopicPracticeScreen(
          claudeService: ClaudeService(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: SubscriptionService(),
        ),
    after: null,
  ),
  (
    name: 'question_keyboard',
    keyboard: 1,
    build: (size) => PracticeScreen(
          topic: const Topic(
            id: TopicId.gerundVsInfinitive,
            title: 'Gerund vs. Infinitive',
            description: '',
            icon: Icons.school,
          ),
          practiceSet: _practiceSet,
          claudeService: ClaudeService(),
          storageService: StorageService(),
          analyticsService: AnalyticsService(),
          subscriptionService: SubscriptionService(),
        ),
    after: (tester) async {
      await tester.enterText(find.byKey(QuestionView.answerFieldKey),
          'I enjoy hiking with my friends. I have decided to learn to cook.');
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'onboarding_step1',
    keyboard: 0,
    build: (size) => OnboardingScreen(onComplete: (_) {}),
    after: (tester) async {
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'onboarding_step1_keyboard',
    keyboard: 1,
    build: (size) => OnboardingScreen(onComplete: (_) {}),
    after: (tester) async {
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'onboarding_step2',
    keyboard: 0,
    build: (size) => OnboardingScreen(onComplete: (_) {}),
    after: (tester) async {
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(OnboardingScreen.continueKey));
      await tester.tap(find.byKey(OnboardingScreen.continueKey));
      await tester.pumpAndSettle();
    },
  ),
  (
    name: 'paywall',
    keyboard: 0,
    build: (size) => PremiumScreen(
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          analyticsSource: AnalyticsService.paywallSourceHome,
          subscriptionService: _Subs(),
        ),
    after: null,
  ),
];

/// A device size and its keyboard height.
typedef _Device = ({Size size, double keyboard, double top, double bottom});

const List<_Device> _devices = [
  (size: Size(320, 568), keyboard: 253, top: 20, bottom: 0),
  (size: Size(360, 780), keyboard: 300, top: 47, bottom: 34),
  (size: Size(390, 844), keyboard: 336, top: 47, bottom: 34),
  (size: Size(430, 932), keyboard: 346, top: 59, bottom: 34),
  (size: Size(375, 667), keyboard: 260, top: 20, bottom: 0),
];

int _lines(RenderParagraph p) =>
    p.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: p.text.toPlainText().length))
        .map((b) => b.top.round())
        .toSet()
        .length;

void main() {
  final out = outDir();
  final shots = Platform.environment['DESIGN_MEASURE_SHOTS'] == '1';
  final sizes = [
    for (final s in (Platform.environment['DESIGN_MEASURE_SIZES'] ?? 'large')
        .split(','))
      AppTextSize.values.byName(s.trim())
  ];
  final only = Platform.environment['DESIGN_MEASURE_SCREENS']
      ?.split(',')
      .map((s) => s.trim())
      .toSet();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  final report = <String, StringBuffer>{};
  tearDownAll(() {
    final all = StringBuffer();
    for (final k in report.keys.toList()..sort()) {
      all.write(report[k]);
    }
    File('$out/text_size_sweep.txt').writeAsStringSync(all.toString());
  });

  for (final screen in _screens) {
    if (only != null && !only.contains(screen.name)) continue;
    for (final device in _devices) {
      for (final size in sizes) {
        for (final b in Brightness.values) {
          final id = '${screen.name} ${device.size.width.toInt()}x'
              '${device.size.height.toInt()} ${size.name} ${b.name}';
          testWidgets(id, (tester) async {
            final buf = report[id] = StringBuffer();
            final notes = <String>[];
            DebugTools.enabledForTesting = false;
            addTearDown(() => DebugTools.enabledForTesting = true);
            final keyboard = screen.keyboard > 0 ? device.keyboard : 0.0;
            tester.view.physicalSize = device.size * 3;
            tester.view.devicePixelRatio = 3;
            final pad = FakeViewPadding(
                top: device.top * 3, bottom: device.bottom * 3);
            tester.view.padding = keyboard > 0
                ? FakeViewPadding(top: device.top * 3)
                : pad;
            tester.view.viewPadding = pad;
            tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
            addTearDown(tester.view.reset);
            final errors = <String>[];
            final previous = FlutterError.onError;
            FlutterError.onError =
                (d) => errors.add(d.exceptionAsString().split('\n').first);
            final key = GlobalKey();
            try {
              await tester.pumpWidget(RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(b, textSize: size),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: child!),
                  home: screen.build(size),
                ),
              ));
              await tester.pump(const Duration(milliseconds: 500));
              await tester.pump(const Duration(seconds: 3));
              if (screen.after != null) await screen.after!(tester);
              await tester.pump(const Duration(seconds: 1));
            } finally {
              FlutterError.onError = previous;
            }

            final root = tester.renderObject(find.byKey(key));
            final cut = <String>{};
            void visit(RenderObject o) {
              if (o is RenderParagraph && o.didExceedMaxLines) {
                final t = o.text.toPlainText();
                cut.add(t.length > 50 ? '${t.substring(0, 50)}…' : t);
              }
              o.visitChildren(visit);
            }

            visit(root);

            void oneLine(String what, Finder within) {
              for (final e in find
                  .descendant(of: within, matching: find.byType(RichText))
                  .evaluate()) {
                final p = e.renderObject! as RenderParagraph;
                final t = p.text.toPlainText();
                if (t.trim().isEmpty) continue;
                if (_lines(p) > 1) notes.add('$what on ${_lines(p)} lines: "$t"');
              }
            }

            if (find.byKey(ClimbCard.plaqueKey).evaluate().isNotEmpty) {
              oneLine('the plaque', find.byKey(ClimbCard.plaqueKey));
            }
            if (find.byKey(FloatingNavShell.barKey).evaluate().isNotEmpty) {
              oneLine('a nav label', find.byKey(FloatingNavShell.barKey));
            }
            for (final e in find.byType(AppSegmentedButton).evaluate()) {
              oneLine('a segment', find.byWidget(e.widget));
            }
            if (screen.name == 'paywall') {
              final footer =
                  tester.getRect(find.byKey(const Key('premiumFooter')));
              final inFooter = find
                  .descendant(
                      of: find.byKey(const Key('premiumFooter')),
                      matching: find.text('Privacy Policy'))
                  .evaluate()
                  .isNotEmpty;
              notes.add('footer ${footer.height.toStringAsFixed(0)} pt = '
                  '${(footer.height / device.size.height).toStringAsFixed(3)}'
                  ' of the screen; links ${inFooter ? 'in the footer' : 'in the body'}');
            }
            if (screen.name == 'question_keyboard') {
              final field = tester.getRect(find.byKey(QuestionView.answerFieldKey));
              final kbTop = device.size.height - keyboard;
              notes.add('answer field ${field.top.toStringAsFixed(0)}–'
                  '${field.bottom.toStringAsFixed(0)}, keyboard top '
                  '${kbTop.toStringAsFixed(0)}'
                  '${field.bottom > kbTop + 0.5 ? ' — UNDER THE KEYBOARD' : ''}');
            }
            if (screen.name == 'onboarding_step1_keyboard') {
              final field =
                  tester.getRect(find.byKey(OnboardingScreen.nameFieldKey));
              final kbTop = device.size.height - keyboard;
              if (field.bottom > kbTop + 0.5) {
                notes.add('name field under the keyboard');
              }
            }

            buf.writeln(id);
            for (final e in errors.toSet()) {
              buf.writeln('  EXCEPTION: $e');
            }
            for (final c in cut) {
              buf.writeln('  ellipsis: "$c"');
            }
            for (final n in notes) {
              buf.writeln('  $n');
            }
            if (shots) {
              await tester.runAsync(() async {
                final img = await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
                final bytes =
                    await img.toByteData(format: ui.ImageByteFormat.png);
                File('$out/${id.replaceAll(' ', '_')}.png')
                    .writeAsBytesSync(bytes!.buffer.asUint8List());
              });
            }
          });
        }
      }
    }
  }
}
