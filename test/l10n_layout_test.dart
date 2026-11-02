import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/models/welcome_badge.dart';
import 'package:grammar_lens/screens/practice_length_picker.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/settings_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/home_greeting.dart';
import 'package:grammar_lens/widgets/locked_premium_pill.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';
import 'package:grammar_lens/widgets/monthly_medal_collection.dart';
import 'package:grammar_lens/widgets/question_view.dart';
import 'package:grammar_lens/widgets/topic_hint_card.dart';

/// 1.4.0 B5 (docs/1.4.0-b5-batch0-report.md §4, §8 Q8): the sites whose
/// labels cannot grow, in every Latin-script interface language, at
/// 320 pt and the Large text size with the bundled font. A site passes when
/// it lays out without an exception and no one-line label is cut (an
/// ellipsis, a fade or a clip), apart from the two that truncate by design.
///
/// Japanese, Korean and Arabic are not measured here: Nunito Sans has no
/// glyphs for them and `flutter test` has no system font fallback, so
/// their widths are the device's to check (report §4).
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  final locales = [
    for (final lang in const ['en', 'tr', 'de', 'es', 'pt'])
      if (File('lib/l10n/app_$lang.arb').existsSync()) Locale(lang),
  ];

  testWidgets('the check itself flags a one-line label that is cut',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Text('A label far too long to fit on one line of a phone',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ));
    expect(_cutLabels(tester), hasLength(1));
  });

  for (final locale in locales) {
    group('${locale.languageCode} at 320 pt, Large', () {
      for (final site in _sites) {
        testWidgets(site.name, (tester) async {
          tester.view.physicalSize = Size(320, site.height) * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(Brightness.light, textSize: AppTextSize.large),
            home: Builder(builder: (context) => site.build(context)),
          ));
          await tester.pumpAndSettle();
          await site.after?.call(tester);
          expect(tester.takeException(), isNull);
          final cut = _cutLabels(tester);
          expect(cut, isEmpty,
              reason: 'One-line labels cut at 320 pt, Large '
                  '(${locale.languageCode}):\n${cut.join('\n')}');
        });
      }
    });
  }
}

class _Site {
  final String name;
  final double height;
  final Widget Function(BuildContext context) build;
  final Future<void> Function(WidgetTester tester)? after;
  const _Site(this.name, this.build, {this.height = 568, this.after});
}

final _sites = <_Site>[
  _Site(
    'bottom navigation',
    (context) => FloatingNavShell(
      body: const SizedBox.expand(),
      tabs: [
        NavShellTab(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: context.l10n.navHome),
        NavShellTab(
            icon: Icons.history_outlined,
            activeIcon: Icons.history,
            label: context.l10n.featureReview),
        NavShellTab(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: context.l10n.navProfile),
      ],
      selectedIndex: 0,
      onTabChange: (_) {},
    ),
  ),
  _Site(
    'Profile: segmented buttons, language field, medals',
    height: 2200,
    (context) => SettingsScreen(
      active: true,
      themeMode: AppThemeMode.system,
      onSelectThemeMode: (_) {},
      textSize: AppTextSize.large,
      onSelectTextSize: (_) {},
      profile: const UserProfile(name: 'Ada', learningGoal: LearningGoal.work),
      storageService: _Storage(),
      onProfileUpdated: (_) {},
      onResetOnboarding: () {},
      subscriptionService: _Subscriptions(),
      analyticsService: AnalyticsService(sink: _NoSink()),
    ),
  ),
  _Site(
    'hint slider label',
    (context) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TopicHintSlider(
          topic: topicById(TopicId.gerundVsInfinitive),
          points: kTopicHints[TopicId.gerundVsInfinitive]!,
        ),
      ),
    ),
  ),
  _Site(
    'Premium pills',
    (context) => const Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LockedPremiumPill(),
          LockedPremiumPill(showChevron: false),
        ]),
      ),
    ),
  ),
  _Site(
    'paywall: plan cards, table, button, footer',
    height: 3200,
    (context) => PremiumScreen(
      storageService: _Storage(),
      analyticsService: AnalyticsService(sink: _NoSink()),
      analyticsSource: AnalyticsService.paywallSourceHome,
      subscriptionService:
          _Subscriptions(offering: buildDebugFixtureOffering()),
    ),
    after: (tester) async {
      // The prices loaded: both plan cards, then the comparison table open.
      expect(find.byKey(const ValueKey('planCard_Annual')), findsOneWidget);
      expect(find.byKey(const ValueKey('planCard_Monthly')), findsOneWidget);
      await tester.tap(find.byKey(PremiumScreen.compareToggleKey));
      await tester.pumpAndSettle();
      // At 320 pt the table is the stacked layout (no strip header): its
      // first row, in this language, is on screen.
      final l10n = tester.element(find.byType(PremiumScreen)).l10n;
      expect(find.text(l10n.paywallRowDailyTest), findsWidgets);
    },
  ),
  _Site(
    'climb card: plaque and chips',
    (context) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ClimbCard(
          month: DateTime(2026, 9),
          steps: 12,
          days: 30,
          mountain: MonthlyMountain(
              days: 30, completedDays: 12, avatar: Avatar.values.first),
          scoreBar: const SizedBox(height: 40),
        ),
      ),
    ),
  ),
  _Site(
    'climb score bar: tier labels',
    (context) => Scaffold(
      body: Center(
        child: ClimbScoreBar(
          score: 120,
          maxScore: MonthlyMedalRules.maxScore(2026, 11),
          thresholds: {
            for (final tier in MedalTier.values)
              tier: MonthlyMedalRules.threshold(2026, 11, tier),
          },
        ),
      ),
    ),
  ),
  _Site(
    'medal shelf: month labels',
    (context) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MonthlyMedalCollection(
          welcomeBadge: WelcomeBadge(
              earnedAt: DateTime(2026, 9, 3),
              ruleVersion: 1,
              backfilled: false),
          currentProgress: const MonthlyMedalProgress(
            year: 2026,
            month: 11,
            score: 40,
            maxScore: 300,
            activeDays: 4,
            correct: 12,
            wrong: 6,
            skipped: 2,
          ),
          results: [
            for (final month in [9, 10])
              MonthlyMedalResult(
                year: 2026,
                month: month,
                score: 200,
                maxScore: 300,
                activeDays: 20,
                correct: 60,
                wrong: 20,
                skipped: 0,
                tier: MedalTier.values[month - 9],
                ruleVersion: 1,
                finalizedAt: DateTime(2026, month + 1, 1),
              ),
          ],
        ),
      ),
    ),
  ),
  _Site(
    'question header: type label, topic tag, counter',
    (context) => Scaffold(
      body: QuestionView(
        item: const PracticeItem(
          id: 'q1',
          type: PracticeItemType.errorCorrection,
          context: 'She can speaks three languages.',
          instruction: 'Find the mistake and rewrite the full sentence.',
        ),
        index: 9,
        total: 10,
        topic: topicById(TopicId.gerundVsInfinitive),
        drafts: AnswerDrafts(const ['q1']),
        onChanged: (_) {},
        horizontalPadding: 14,
      ),
    ),
  ),
  _Site(
    'length sheet: the start button',
    (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showPracticeLengthPicker(
              context: context, initial: PracticeLength.extended),
          child: const Text('open'),
        ),
      ),
    ),
    after: (tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    },
  ),
  _Site(
    'Home greeting with a long name',
    (context) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: HomeGreeting(
          word: context.l10n.greetingAfternoon,
          name: 'Maximiliana',
          withName: context.l10n.greetingWithName(
              context.l10n.greetingAfternoon,
              context.l10n.greetingName('Maximiliana')),
          lead: context.l10n.greetingLead(context.l10n.greetingAfternoon),
          addressedName: context.l10n.greetingName('Maximiliana'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    ),
  ),
];

/// Every one-line paragraph on screen whose text is wider than its box
/// (cut by an ellipsis, a fade or a clip), except the greeting's name line,
/// which may be cut by design (a very long name), and anything inside a
/// `FittedBox`, which scales down instead of cutting.
List<String> _cutLabels(WidgetTester tester) {
  final cut = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    final oneLine = paragraph.maxLines == 1 || !paragraph.softWrap;
    if (!oneLine) continue;
    if (element.findAncestorWidgetOfExactType<FittedBox>() != null) continue;
    if (element.findAncestorWidgetOfExactType<HomeGreeting>() != null &&
        paragraph.text.toPlainText() == 'Maximiliana') {
      continue;
    }
    final needed = paragraph.getMaxIntrinsicWidth(double.infinity);
    if (needed > paragraph.size.width + 0.5) {
      cut.add('"${paragraph.text.toPlainText()}" needs '
          '${needed.toStringAsFixed(1)}, has '
          '${paragraph.size.width.toStringAsFixed(1)}');
    }
  }
  return cut;
}

class _Storage extends StorageService {
  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async => const [];

  @override
  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() async =>
      const MonthlyMedalProgress(
        year: 2026,
        month: 11,
        score: 120,
        maxScore: 300,
        activeDays: 12,
        correct: 40,
        wrong: 20,
        skipped: 0,
      );

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => const [];

  @override
  Future<WelcomeBadge?> getWelcomeBadge() async => null;

  @override
  Future<UserProfile?> getUserProfile() async =>
      const UserProfile(name: 'Ada', learningGoal: LearningGoal.work);
}

class _Subscriptions extends SubscriptionService {
  final Offering? offering;
  _Subscriptions({this.offering});

  @override
  Future<Offering?> getOfferings() async => offering;

  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
          List<String> productIds) async =>
      {for (final id in productIds) id: TrialEligibility.eligible};

  @override
  Future<bool> get hasFullAccess async => false;
}

class _NoSink implements AnalyticsSink {
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}
