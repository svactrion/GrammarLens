// The UI polish board gallery's boards: id → the real widget or screen with
// fixed sample data. See gallery_app.dart.
import 'package:flutter/material.dart';
import 'package:grammar_lens/app_colors.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'dart:math';

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
import 'package:grammar_lens/widgets/companion_dialog.dart';
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
  'V01-Splash': (_) => const LaunchSplash(),
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
  'R10-Leave': (_) => const _OnMount(_openLeave, child: _QuestionBackdrop()),
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

void _openLeave(BuildContext context) => showCompanionDialog(
      context: context,
      hero: Avatar.fox,
      title: context.l10n.dailyTestLeaveTitle,
      body: context.l10n.leaveProgressBody(1, 5),
      primaryLabel: context.l10n.leaveKeepGoing,
      secondaryLabel: context.l10n.commonLeave,
    );

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
