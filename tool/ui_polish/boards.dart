// The UI polish board gallery's boards: id → the real widget or screen with
// fixed sample data. See gallery_app.dart.
import 'package:flutter/material.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'dart:math';
import 'dart:async';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/first_climb_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/month_transition.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/month_card_sheet.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
import 'package:grammar_lens/screens/getting_ready_screen.dart';
import 'package:grammar_lens/screens/lucky_wheel_screen.dart';
import 'package:grammar_lens/screens/mountain_intro_screen.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/screens/welcome_screen.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/daily_test_card.dart';
import 'package:grammar_lens/widgets/error_state.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';
import 'package:grammar_lens/widgets/ticket.dart';

/// Every board the gallery can show, in SPEC order.
final Map<String, WidgetBuilder> galleryBoards = {
  'V00-CompanionSystem': (_) => const _CompanionSystem(),
  'V00-MotionSystem': (_) => const _MotionSystem(),
  'X01-ExpressionKit': (_) => const _ExpressionKit(),
  'X03-HeroSet': (_) => const _HeroSet(),
  'X04-Ticket': (_) => const _TicketBoard(),
  'X05-DailyCard': (_) => const _DailyCardBoard(),
  // Under a Material, as in the app (the splash sits outside MaterialApp
  // there, where text has no debug underline).
  'V01-Splash': (_) => const Material(child: LaunchSplash()),
  'V02-Welcome': (_) => WelcomeScreen(onGetStarted: () {}),
  'V03-Meet': (_) => OnboardingScreen(onComplete: (_) {}),
  // Reached by the driver from V03 (taps): V03b, V04, V05.
  'V03b-LuckyWheel': (_) => LuckyWheelScreen(
      current: Avatar.fox,
      // Seeded so the capture lands on the same hero every run.
      random: Random(3),
      primaryLabel: (h) => 'Climb with ${h.semanticLabel}'),
  'V04-Name': (_) => OnboardingScreen(onComplete: (_) {}),
  'V05-Goal': (_) => OnboardingScreen(onComplete: (_) {}),
  'V05b-GettingReady': (_) => GettingReadyScreen(
        name: 'Ada',
        hero: Avatar.fox,
        goal: LearningGoal.work,
        monthName: 'November',
        mountainName: 'Ember Peak',
        steps: 30,
        questionsPerDay: 5,
        tasks: [
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
          () => Future<void>.delayed(const Duration(milliseconds: 900)),
          () => Future<void>.delayed(const Duration(seconds: 6)),
        ],
        onDone: () {},
      ),
  'V06-MountainIntro': (_) => MountainIntroScreen(
        theme: ClimbThemes.emberPeak,
        hero: Avatar.fox,
        days: 30,
        monthName: 'November',
        onStart: () {},
      ),
  'R06-AvatarChange': (_) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => AvatarPickerScreen(
                currentAvatar: Avatar.fox, onAvatarChanged: (_) {})),
      ),
  'R06s-B1-Turntable': (_) => OnboardingScreen(onComplete: (_) {}),
  'R06s-D-Wheel': (_) => LuckyWheelScreen(
      current: Avatar.fox,
      random: Random(3),
      primaryLabel: (h) => 'Climb with ${h.semanticLabel}'),
  'V07-Question': (_) => _dailyTest(),
  'V08-Correct': (_) => _dailyTest(),
  'V09-Wrong': (_) => _dailyTest(),
  'Q04-MultiBlank': (_) => _dailyTest(multiBlankFirst: true),
  'Q05-ErrorCorrection': (_) => _dailyTest(errorLast: true),
  'V10-Results': (_) => DailyTestResultScreen(
        dailyTestSet: _galleryDaySet(),
        answers: {
          for (final (i, q) in kDayZeroQuestions.indexed)
            q.item.id: i == 1 ? 'a' : q.correctAnswer,
        },
        dailyTestService: _GalleryDailyService(_galleryDaySet()),
        analyticsService: AnalyticsService(sink: const _NoAnalytics()),
        hero: Avatar.fox,
        userName: 'Ada',
      ),
  'V11-Badge': (context) => MedalCelebration.welcome(
      onClose: () {}, l10n: context.l10n, hero: Avatar.fox, name: 'Ada'),
  'R05-Medal': (context) => MedalCelebration.tier(
      tier: MedalTier.bronze,
      theme: ClimbThemes.emberPeak,
      month: 11,
      onClose: () {},
      l10n: context.l10n,
      hero: Avatar.fox,
      points: 75,
      nextTier: MedalTier.silver,
      nextAt: 150),
  // R10 over the real question screen: the driver taps the close button.
  'R10-Leave': (_) => _dailyTest(),
  // B5: Home and the mountain (the real Home in the real tab shell, with
  // fixed data).
  'V15-HomeNextDay': (_) => _home(steps: 1, correct: 4, wrong: 1),
  'V14-Home': (_) =>
      _home(steps: 2, correct: 8, wrong: 2, doneToday: true, weakSpot: true),
  'H03-HomeLoading': (_) => _home(steps: 1, loading: true),
  'H04-HomePremium': (_) => _home(
      steps: 2,
      correct: 8,
      wrong: 2,
      doneToday: true,
      weakSpot: true,
      premium: true,
      sessions: 2),
  'V24-DayComplete': (_) =>
      _home(steps: 3, correct: 13, wrong: 2, doneToday: true, freeUsed: 1),
  'V12-Climb': (_) => FirstClimbScreen(
      theme: ClimbThemes.emberPeak,
      hero: Avatar.fox,
      days: 30,
      onContinue: () {}),
  'V12b-ClimbStoryboard': (_) => FirstClimbScreen(
      theme: ClimbThemes.emberPeak,
      hero: Avatar.fox,
      days: 30,
      onContinue: () {}),
  'R04-MonthCard': (_) => MonthCardSheet(
        data: const MonthCardData(
          year: 2026,
          month: 11,
          theme: ClimbThemes.emberPeak,
          variant: MonthCardVariant.summary,
          previousTheme: ClimbThemes.greenSlope,
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
  'R04b-NewMountain': (_) => MonthCardSheet(
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
  'R11-Offline': (_) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: ErrorState(
                hero: Avatar.fox,
                onRetry: () async {
                  await Future<void>.delayed(const Duration(seconds: 1));
                  return false;
                }),
          ),
        ),
      ),
  'SY02-Snackbar': (_) => _OnMount(
        (context) => AppMessenger.show('Name saved',
            kind: MessageKind.success, actionLabel: 'Undo', onAction: () {}),
        child: const _QuestionBackdrop(),
      ),
};

/// Runs [action] once after the first frame (opens a dialog, a sheet, a
/// snackbar over [child]).
class _OnMount extends StatefulWidget {
  final void Function(BuildContext context) action;
  final Widget child;
  const _OnMount(this.action, {required this.child});

  @override
  State<_OnMount> createState() => _OnMountState();
}

class _OnMountState extends State<_OnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.action(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A plain page behind dialogs and messages.
class _QuestionBackdrop extends StatelessWidget {
  const _QuestionBackdrop();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(height: 220, decoration: lipCard(c)),
            const SizedBox(height: 20),
            Container(height: 120, decoration: lipCard(c)),
          ]),
        ),
      ),
    );
  }
}

class _TicketBoard extends StatefulWidget {
  const _TicketBoard();

  @override
  State<_TicketBoard> createState() => _TicketBoardState();
}

class _TicketBoardState extends State<_TicketBoard> {
  TicketState _tearing = TicketState.free;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _tearing = TicketState.tearing);
    });
  }

  @override
  Widget build(BuildContext context) {
    const next = Duration(hours: 20, minutes: 41);
    return SystemBoard(
        title: 'Ticket — one component, three states',
        children: [
          _label(context, '1 · FREE'),
          const Ticket(
              state: TicketState.free,
              title: '1 free practice',
              subtitle: 'Pick a weak spot below. AI feedback included.'),
          _label(context, '2 · TEARING'),
          Ticket(
              state: _tearing,
              title: '1 free practice',
              subtitle: 'Pick a weak spot below. AI feedback included.'),
          _label(context, '3 · USED'),
          const Ticket(
              state: TicketState.used,
              title: '1 free practice',
              subtitle: 'Nice work, Ada.',
              nextIn: next),
          _label(context, 'COMPACT · FREE (HOME)'),
          const Ticket(
              state: TicketState.free,
              compact: true,
              title: '1 free practice',
              subtitle: 'Use it on: Articles'),
          _label(context, 'COMPACT · USED'),
          const Ticket(
              state: TicketState.used,
              compact: true,
              title: '1 free practice',
              subtitle: 'Nice work, Ada.',
              nextIn: next),
        ]);
  }
}

class _DailyCardBoard extends StatelessWidget {
  const _DailyCardBoard();

  @override
  Widget build(BuildContext context) {
    return SystemBoard(title: 'Daily Test card — one skeleton', children: [
      _label(context, 'LOADING'),
      const DailyTestCard(state: DailyTestCardState.loading, hero: Avatar.fox),
      const SizedBox(height: 8),
      _label(context, 'WAITING (ORANGE)'),
      DailyTestCard(
          state: DailyTestCardState.todo,
          hero: Avatar.fox,
          title: 'Your next step.',
          subtitle: '5 questions · about 2 minutes',
          buttonLabel: 'Start today’s test',
          onPressed: () {}),
      const SizedBox(height: 8),
      _label(context, 'DONE (NAVY)'),
      DailyTestCard(
          state: DailyTestCardState.done,
          hero: Avatar.fox,
          title: 'Day 1 complete!',
          subtitle: '+9 points · step 1 reached',
          results: const [true, false, true, true, true],
          buttonLabel: 'Review answers',
          onPressed: () {}),
    ]);
  }
}

/// The scroll position of the board on screen, so the driver can capture
/// the lower part of a long system board (`scroll:<px>`).
final galleryScroll = ScrollController();

/// A system board: a title and its content, scrolling.
class SystemBoard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SystemBoard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: ListView(
          controller: galleryScroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall!
                    .withWeight(FontWeight.w900)
                    .copyWith(color: c.text)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelMedium!
              .withWeight(FontWeight.w900)
              .copyWith(color: AppColors.of(context).navy, letterSpacing: 1)),
    );

Widget _stage(BuildContext context, Avatar hero, Widget child,
        {double w = 104, double h = 104}) =>
    Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.stageFor(hero.order, Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );

class _CompanionSystem extends StatelessWidget {
  const _CompanionSystem();

  @override
  Widget build(BuildContext context) {
    return SystemBoard(title: 'Companion system', children: [
      _label(context, 'FOX · EVERY MOOD'),
      Wrap(spacing: 10, runSpacing: 22, children: [
        for (final mood in CompanionMood.values)
          Column(children: [
            _stage(context, Avatar.fox,
                CompanionView(hero: Avatar.fox, mood: mood, size: 76)),
            const SizedBox(height: 4),
            Text(mood.name),
          ]),
      ]),
      _label(context, 'THE NINE HEROES · IDLE'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final hero in Avatar.values)
          _stage(context, hero, CompanionView(hero: hero, size: 64),
              w: 76, h: 76),
      ]),
    ]);
  }
}

class _MotionSystem extends StatelessWidget {
  const _MotionSystem();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget swatch(Color color, String name) => Column(children: [
          Container(
              width: 52,
              height: 36,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.line))),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 11)),
        ]);
    return SystemBoard(title: 'Motion and touch system', children: [
      _label(context, 'BUTTONS: PRESSABLE 3D'),
      PressableButton(
          label: 'Primary', onPressed: () {}, tone: ButtonTone.orange),
      const SizedBox(height: 10),
      PressableButton(label: 'Secondary', onPressed: () {}),
      const SizedBox(height: 10),
      PressableButton(
          label: 'Correct', onPressed: () {}, tone: ButtonTone.green),
      const SizedBox(height: 10),
      const PressableButton(label: 'Disabled', onPressed: null),
      const SizedBox(height: 10),
      PressableButton(
          label: 'Shine',
          onPressed: () {},
          tone: ButtonTone.orange,
          shine: true),
      const SizedBox(height: 10),
      PressableButton(
          label: 'Outline', onPressed: () {}, tone: ButtonTone.outline),
      PressableButton(label: 'Text', onPressed: () {}, tone: ButtonTone.text),
      _label(context, 'COLOUR'),
      Wrap(spacing: 10, runSpacing: 10, children: [
        swatch(c.orange, 'Orange'),
        swatch(c.navy, 'Navy'),
        swatch(c.green, 'Green'),
        swatch(c.red, 'Red'),
        swatch(c.gold, 'Gold'),
        swatch(c.page, 'Cream'),
        swatch(c.sky, 'Sky'),
      ]),
    ]);
  }
}

class _ExpressionKit extends StatelessWidget {
  const _ExpressionKit();

  @override
  Widget build(BuildContext context) {
    const heroes = [Avatar.fox, Avatar.panda, Avatar.frog, Avatar.giraffe];
    const moods = [
      CompanionMood.cheer,
      CompanionMood.think,
      CompanionMood.sad,
      CompanionMood.sleep,
      CompanionMood.oops,
    ];
    return SystemBoard(title: 'Pose + expression kit', children: [
      for (final mood in moods) ...[
        _label(context, mood.name.toUpperCase()),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final hero in heroes)
              _stage(
                  context,
                  hero,
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: CompanionView(hero: hero, mood: mood, size: 58),
                  ),
                  w: 82,
                  h: 92),
          ],
        ),
      ],
    ]);
  }
}

class _HeroSet extends StatelessWidget {
  const _HeroSet();

  @override
  Widget build(BuildContext context) {
    const moods = [
      CompanionMood.wave,
      CompanionMood.cheer,
      CompanionMood.think,
      CompanionMood.inspect,
      CompanionMood.sad,
      CompanionMood.sleep,
    ];
    return SystemBoard(title: 'Hero set — 9 heroes × 6 poses', children: [
      for (final hero in Avatar.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            SizedBox(
                width: 54,
                child: Text(hero.name(context.l10n),
                    style: const TextStyle(fontSize: 12))),
            for (final mood in moods)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: _stage(
                    context,
                    hero,
                    CompanionView(
                        hero: hero, mood: mood, size: 44, showProp: false),
                    w: 50,
                    h: 50),
              ),
          ]),
        ),
    ]);
  }
}

/// Drops every event (the gallery sends nothing).
class _NoAnalytics implements AnalyticsSink {
  const _NoAnalytics();
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

DailyTestSet _galleryDaySet(
        {bool multiBlankFirst = false, bool errorLast = false}) =>
    DailyTestSet(
      day: '2026-11-17',
      questions: errorLast
          ? [
              for (final i in [0, 2, 3, 4, 1]) kDayZeroQuestions[i],
            ]
          : [
              if (multiBlankFirst)
                DailyTestQuestion(
                  item: const PracticeItem(
                    id: 'gallery_multi',
                    type: PracticeItemType.fillInBlank,
                    context:
                        'We had ____ lunch at ____ small café near ____ station.',
                    instruction: 'Fill in each blank with an article, or none.',
                  ),
                  topicId: 'articles',
                  correctAnswer:
                      'We had lunch at a small café near the station.',
                  commonWrongAnswers: const [],
                ),
              ...kDayZeroQuestions.take(multiBlankFirst ? 4 : 5),
            ],
    );

/// A Daily Test service that hands the gallery a fixed set and saves
/// nothing.
class _GalleryDailyService extends DailyTestService {
  final DailyTestSet set;
  _GalleryDailyService(this.set)
      : super(
            claudeService: ClaudeService(), storageService: _GalleryStorage());

  @override
  Future<DailyTestSet> getTodaysSet() async => set;

  @override
  Future<bool> completeDailyTest(
          Map<String, String> answers, List<ErrorEntry> errorEntries,
          {String? day, DateTime? completedAt}) async =>
      false;
}

class _GalleryStorage extends StorageService {}

Widget _dailyTest({bool multiBlankFirst = false, bool errorLast = false}) =>
    DailyTestScreen(
      dailyTestService: _GalleryDailyService(_galleryDaySet(
          multiBlankFirst: multiBlankFirst, errorLast: errorLast)),
      analyticsService: AnalyticsService(sink: const _NoAnalytics()),
      hero: Avatar.fox,
      userName: 'Ada',
      onFinished: (_, __) {},
      onExit: () {},
    );

/// A free (or [premium]) user's Home on 17 November 2026 at 9:41: [steps]
/// climbed this month with [correct] and [wrong] answers; today's test done
/// ([doneToday], 4 of 5 right) or waiting; one weak spot ([weakSpot]);
/// today's free practice ([freeUsed]) and sessions; [loading]: the test
/// and the month never arrive (H03).
Widget _home({
  required int steps,
  int correct = 0,
  int wrong = 0,
  bool doneToday = false,
  bool weakSpot = false,
  bool premium = false,
  int freeUsed = 0,
  int sessions = 0,
  bool loading = false,
}) =>
    Builder(builder: (context) {
      final l10n = context.l10n;
      return FloatingNavShell(
        // The driver's scroll captures move Home's own list.
        body: PrimaryScrollController(
          controller: galleryScroll,
          child: HomeScreen(
            active: true,
            userName: 'Ada',
            avatar: Avatar.fox,
            claudeService: ClaudeService(),
            storageService: _GalleryHomeStorage(
              steps: steps,
              correct: correct,
              wrong: wrong,
              doneToday: doneToday,
              weakSpot: weakSpot,
              freeUsed: freeUsed,
              sessions: sessions,
              loading: loading,
            ),
            analyticsService: AnalyticsService(sink: const _NoAnalytics()),
            subscriptionService: _GallerySubs(premium),
            clock: () => DateTime(2026, 11, 17, 9, 41),
          ),
        ),
        tabs: [
          NavShellTab(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: l10n.navHome),
          NavShellTab(
              icon: Icons.history_outlined,
              activeIcon: Icons.history,
              label: l10n.featureReview),
          NavShellTab(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: l10n.navProfile),
        ],
        selectedIndex: 0,
        onTabChange: (_) {},
      );
    });

class _GallerySubs extends SubscriptionService {
  final bool premium;
  _GallerySubs(this.premium);
  @override
  Future<bool> get hasFullAccess async => premium;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

class _GalleryHomeStorage extends StorageService {
  final int steps, correct, wrong, freeUsed, sessions;
  final bool doneToday, weakSpot, loading;
  _GalleryHomeStorage({
    required this.steps,
    required this.correct,
    required this.wrong,
    required this.doneToday,
    required this.weakSpot,
    required this.freeUsed,
    required this.sessions,
    required this.loading,
  });

  Future<T> _never<T>() => Completer<T>().future;

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) =>
      loading
          ? _never()
          : Future.value(
              (steps: steps, correct: correct, wrong: wrong, skipped: 0));

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemes.emberPeak.id;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() {
    if (loading) return _never();
    if (!doneToday) return Future.value(null);
    final set = _galleryDaySet();
    return Future.value(DailyTestSet(
      day: set.day,
      questions: set.questions,
      completedAt: DateTime(2026, 11, 17, 9, 30),
      answers: {
        for (final (i, q) in set.questions.indexed)
          q.item.id: i == 1 ? 'a' : q.correctAnswer,
      },
    ));
  }

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) =>
      getDailyTestSetForToday();

  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      weakSpot
          ? [
              WeakSpot(
                topicId: 'articles',
                errorType: 'missing_article',
                frequency: 3,
                lastSeen: DateTime(2026, 11, 16),
              ),
            ]
          : const [];

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};

  @override
  Future<int> getFreePracticeCountForToday() async => freeUsed;

  @override
  Future<int> getSessionCountForToday() async => sessions;
}
