import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/l10n/generated/app_localizations.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/screens/first_climb_screen.dart';
import 'package:grammar_lens/screens/premium_on_screen.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/daily_test_card.dart';
import 'package:grammar_lens/widgets/error_state.dart';
import 'package:grammar_lens/widgets/home_practice.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';
import 'package:grammar_lens/widgets/practice_preparing.dart';
import 'package:grammar_lens/widgets/practice_reviewing.dart';
import 'package:grammar_lens/widgets/profile_stage.dart';
import 'package:grammar_lens/widgets/rest_scene.dart';
import 'package:grammar_lens/widgets/review_parts.dart';
import 'package:grammar_lens/widgets/score_capsule.dart';
import 'package:grammar_lens/widgets/ticket.dart';

/// UI polish B10 (SPEC §6): every new screen and component in the dark
/// theme (SY03), in Arabic (right to left), at the largest text size and
/// with Reduce Motion — nothing overflows or throws, at 320 pt wide.
enum _Pass { dark, arabic, largest, reduceMotion }

typedef _Site = ({String name, bool page, WidgetBuilder build});

final _spot = WeakSpot(
  topicId: 'articles',
  errorType: 'the_with_superlatives',
  frequency: 1,
  lastSeen: DateTime(2026, 11, 17),
);

final _mistake = ErrorEntry(
  topicId: 'articles',
  errorType: 'the_with_superlatives',
  timestamp: DateTime(2026, 11, 17),
  source: ErrorSource.dailyTest,
  userAnswer: 'She is a tallest girl in her class.',
  correctedAnswer: 'She is the tallest girl in her class.',
);

final List<_Site> _sites = [
  (
    name: 'Daily Test card, three states',
    page: false,
    build: (_) => Column(children: [
          for (final state in DailyTestCardState.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DailyTestCard(
                state: state,
                hero: Avatar.fox,
                title: 'Your next step.',
                subtitle: '5 questions · about 2 minutes',
                results: const [true, false, true, true, true],
                questionCount: 5,
                buttonLabel: 'Start today’s test',
                onPressed: () {},
              ),
            ),
        ]),
  ),
  (
    name: 'Ticket, three states and compact',
    page: false,
    build: (_) => Column(children: [
          for (final state in TicketState.values)
            for (final compact in [false, true])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Ticket(
                  state: state,
                  compact: compact,
                  title: '1 free practice',
                  subtitle: 'Use it on: The With Superlatives',
                  nextIn: const Duration(hours: 20, minutes: 41),
                ),
              ),
        ]),
  ),
  (
    name: 'Score capsule',
    page: false,
    build: (_) =>
        const ScoreCapsule(points: 18, year: 2026, month: 11, today: 9),
  ),
  (
    name: 'Rest scene',
    page: false,
    build: (_) => RestScene(
          theme: ClimbThemes.emberPeak,
          days: 30,
          steps: 3,
          hero: Avatar.fox,
          name: 'Ada',
          testLine: '4/5 · +9 points',
          practiceLine: 'Ticket used',
          clock: () => DateTime(2026, 11, 17, 13, 36),
        ),
  ),
  (
    name: 'Topic showcase and practice card',
    page: false,
    build: (_) => Column(children: [
          TopicShowcase(picked: kTopics.last, onOpenPaywall: () {}),
          const SizedBox(height: 12),
          PracticeCard(
            sessionsToday: 2,
            sessionLimit: 5,
            onOpenTopic: (_) {},
            onPracticeWeakSpot: () {},
          ),
        ]),
  ),
  (
    name: 'Review: weak spot card and empty state',
    page: false,
    build: (_) => Column(children: [
          ReviewSpotCard(
            topic: kTopics.last,
            spot: _spot,
            mistake: _mistake,
            onTap: () {},
            actionLabel: 'Practice with my ticket',
            onAction: () {},
          ),
          const SizedBox(height: 12),
          ReviewEmpty(hero: Avatar.fox, onGoToDailyTest: () {}),
        ]),
  ),
  (
    name: 'Practice: preparing and reviewing',
    page: false,
    build: (_) => Column(children: [
          SizedBox(
            height: 700,
            child: PracticePreparing(
                topic: kTopics.last,
                message: 'Preparing your questions…',
                hero: Avatar.fox),
          ),
          const SizedBox(
            height: 700,
            child: PracticeReviewing(
              topic: 'Articles',
              hero: Avatar.fox,
              answers: ['This is the best pizza in town.'],
            ),
          ),
        ]),
  ),
  (
    name: 'Profile stage',
    page: false,
    build: (_) => ProfileStage(
          hero: Avatar.fox,
          name: 'Maximiliana Alexandrina',
          onChange: () {},
          onEditName: () {},
          points: 171,
          step: 22,
          weakSpots: 3,
          since: DateTime(2026, 11, 2),
        ),
  ),
  (
    name: 'Error state',
    page: false,
    build: (_) => ErrorState(hero: Avatar.fox, onRetry: () async => false),
  ),
  (
    name: 'First climb (V12)',
    page: true,
    build: (_) => FirstClimbScreen(
        theme: ClimbThemes.emberPeak,
        hero: Avatar.fox,
        days: 30,
        onContinue: () {}),
  ),
  (
    name: 'Month recap (R04)',
    page: true,
    build: (_) => MonthCardSheet(
          data: const MonthCardData(
            year: 2026,
            month: 11,
            theme: ClimbThemes.emberPeak,
            variant: MonthCardVariant.summary,
            previousYear: 2026,
            previousMonth: 10,
            tier: MedalTier.silver,
            steps: 24,
            days: 31,
            score: 229,
            nearMiss: (MedalTier.gold, 4),
          ),
          avatar: Avatar.fox,
          onClose: () {},
        ),
  ),
  (
    name: 'New mountain (R04b)',
    page: true,
    build: (_) => MonthCardSheet(
          data: const MonthCardData(
            year: 2026,
            month: 11,
            theme: ClimbThemes.emberPeak,
            variant: MonthCardVariant.fresh,
            previousYear: 2026,
            previousMonth: 10,
          ),
          avatar: Avatar.fox,
          onClose: () {},
        ),
  ),
  (
    name: 'Premium on (PW05)',
    page: true,
    build: (_) => PremiumOnScreen(
        hero: Avatar.fox,
        topics: 5,
        sessions: 5,
        trialEnds: DateTime(2026, 11, 24)),
  ),
];

void main() {
  for (final pass in _Pass.values) {
    group('B10 ${pass.name}', () {
      for (final site in _sites) {
        testWidgets(site.name, (tester) async {
          tester.view.physicalSize = const Size(320, 640) * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          if (pass == _Pass.reduceMotion) {
            tester.platformDispatcher.accessibilityFeaturesTestValue =
                const FakeAccessibilityFeatures(disableAnimations: true);
            addTearDown(
                tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
          }
          final brightness =
              pass == _Pass.dark ? Brightness.dark : Brightness.light;
          await tester.pumpWidget(MaterialApp(
            locale: Locale(pass == _Pass.arabic ? 'ar' : 'en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(brightness,
                textSize: pass == _Pass.largest
                    ? AppTextSize.large
                    : AppTextSize.medium),
            builder: (context, child) => pass == _Pass.largest
                ? MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: child!,
                  )
                : child!,
            home: site.page
                ? Builder(builder: site.build)
                : Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: Builder(builder: site.build),
                    ),
                  ),
          ));
          await tester.pump(const Duration(seconds: 5));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          if (pass == _Pass.reduceMotion) {
            expect(AppMotion.reduced(tester.element(find.byType(Builder).last)),
                isTrue);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    });
  }
}
