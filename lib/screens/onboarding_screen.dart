import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/learning_goal.dart';
import '../models/user_profile.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/content_width.dart';
import '../utils/haptics.dart';
import '../widgets/learning_goal_icon.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/buddy_picker.dart';
import '../widgets/companion_view.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/pressable_button.dart';
import '../widgets/speech_bubble.dart';
import 'lucky_wheel_screen.dart';

/// The short privacy line under the goal options. Public so a test can pin
/// the wording to what the app actually does: the name never leaves the
/// device; the goal is the `learning_goal` analytics user property (1.2.0),
/// sent with usage data and never with the name; Firebase collects usage
/// and crash data. The AI facts are in [OnboardingScreen]'s "Your data &
/// AI" sheet, one tap away.
String onboardingPrivacyNote(AppLocalizations l10n) =>
    l10n.onboardingPrivacyNote;

/// The "Your data & AI" sheet's rows (heading, text), in order. Public for
/// the same reason as [onboardingPrivacyNote].
List<(String, String)> onboardingDataFacts(AppLocalizations l10n) => [
      (l10n.onboardingDataDeviceHeading, l10n.onboardingDataDeviceBody),
      (l10n.onboardingDataGoalHeading, l10n.onboardingDataGoalBody),
      (l10n.onboardingDataAiHeading, l10n.onboardingDataAiBody),
      (
        l10n.onboardingDataDiagnosticsHeading,
        l10n.onboardingDataDiagnosticsBody
      ),
    ];

/// Onboarding in three short steps (UI polish V03–V05), after Welcome and
/// before "Getting ready" (V05b, in [FirstLaunchFlow]):
///
/// 1. **Choose your buddy** (V03): the turntable ([BuddyPicker]); "Try my
///    luck" opens the wheel (V03b). Starts with Fox in front.
/// 2. **Name** (V04): the buddy asks in its bubble; the name is required
///    (Continue stays disabled while it is empty or only spaces), at most
///    [UserProfile.maxNameLength] characters.
/// 3. **Goal** (V05): three big cards; the buddy pops out of the chosen one
///    and reacts. Stored only (SPEC §1.12): it changes no content. "Skip
///    for now" finishes with no goal (stored as `skipped`).
///
/// Back returns to the previous step with everything as it was. Nothing is
/// saved until the last step finishes ([onComplete]).
class OnboardingScreen extends StatefulWidget {
  final ValueChanged<UserProfile> onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  static const nameFieldKey = ValueKey('onboarding_name');
  static const continueKey = ValueKey('onboarding_continue');
  static const backKey = ValueKey('onboarding_back');
  static const startKey = ValueKey('onboarding_start');
  static const skipGoalKey = ValueKey('onboarding_skip_goal');
  static const dataLinkKey = ValueKey('onboarding_data_link');
  static const gotItKey = ValueKey('onboarding_data_got_it');
  static ValueKey<String> goalKey(LearningGoal goal) =>
      ValueKey('onboarding_goal_${goal.name}');

  /// The cross-fade between steps.
  static const Duration stepDuration = AppMotion.base;

  /// The number of dots in the onboarding's step indicator: buddy, name,
  /// goal, this month's mountain.
  static const int stepCount = 4;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { buddy, name, goal }

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _dataLinkFocus = FocusNode(debugLabel: 'data link');
  LearningGoal? _selectedGoal;
  _Step _step = _Step.buddy;

  // Never null (PRD v2 §13.5's "no empty state" rule): the turntable
  // starts with Fox in front (V03, "1 / 9").
  Avatar _selectedAvatar = Avatar.fox;

  /// The buddy's nod while the name is typed (V04: at most 4 Hz).
  late final AnimationController _nod;

  @override
  void initState() {
    super.initState();
    _nod = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dataLinkFocus.dispose();
    _nod.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  bool get _canContinue => _name.isNotEmpty;

  void _chooseBuddy(Avatar hero) {
    setState(() {
      _selectedAvatar = hero;
      _step = _Step.name;
    });
  }

  Future<Avatar?> _tryLuck(Avatar front) async {
    final result = await openLuckyWheel(
      context,
      current: front,
      primaryLabel: (hero) =>
          context.l10n.buddyClimbWith(hero.name(context.l10n)),
    );
    if (!mounted || result == null) return null;
    if (result.confirmed) {
      _chooseBuddy(result.hero);
      return null;
    }
    return result.hero;
  }

  void _continue() {
    if (!_canContinue) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = _Step.goal);
  }

  void _back() => setState(() {
        _step = _step == _Step.goal ? _Step.name : _Step.buddy;
      });

  void _onNameChanged() {
    setState(() {});
    if (!_nod.isAnimating && !AppMotion.reduced(context)) {
      _nod.forward(from: 0);
    }
  }

  void _finish({required bool skipGoal}) {
    if (!_canContinue) return;
    if (!skipGoal && _selectedGoal == null) return;
    widget.onComplete(UserProfile(
      name: _name,
      learningGoal: skipGoal ? null : _selectedGoal,
      avatar: _selectedAvatar,
    ));
  }

  Future<void> _showDataSheet() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _DataDialog(),
    );
    // Back to the link that opened it.
    if (mounted) _dataLinkFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget page = switch (_step) {
      _Step.buddy => BuddyPicker(
          key: const ValueKey('onboarding_step_buddy'),
          initial: _selectedAvatar,
          title: context.l10n.buddyTitle,
          subtitle: context.l10n.buddySubtitle(Avatar.count),
          primaryLabel: (hero) =>
              context.l10n.buddyClimbWith(hero.name(context.l10n)),
          onConfirm: _chooseBuddy,
          onTryLuck: _tryLuck,
          step: 1,
          stepCount: OnboardingScreen.stepCount,
        ),
      _Step.name => BrandScaffold(
          key: const ValueKey('onboarding_step_1'),
          appBar: AppBar(
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
            scrolledUnderElevation: 0,
          ),
          body: _nameStep(context),
        ),
      _Step.goal => BrandScaffold(
          key: const ValueKey('onboarding_step_2'),
          appBar: AppBar(
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
            scrolledUnderElevation: 0,
          ),
          body: _goalStep(context),
        ),
    };
    return PopScope(
      // A back gesture on a later step goes to the step before, not out.
      canPop: _step == _Step.buddy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step != _Step.buddy) _back();
      },
      child: Material(
        color: AppColors.of(context).page,
        child: AnimatedSwitcher(
          duration:
              reduceMotion ? Duration.zero : OnboardingScreen.stepDuration,
          switchInCurve: Curves.easeOut,
          child: page,
        ),
      ),
    );
  }

  double _sidePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ContentWidth.sidePaddingOf(context, base: width < 360 ? 16 : 20);
  }

  Widget _nameStep(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final hPad = _sidePadding(context);
    // A tap anywhere outside the name field closes the keyboard and keeps
    // the name.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          _StepTop(step: 2, onBack: _back),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _nod,
                        builder: (context, child) {
                          final t = _nod.value;
                          final a = math.sin(t * math.pi) * -7 * math.pi / 180;
                          return Transform.rotate(
                            angle: a,
                            alignment: const Alignment(0, .84),
                            child: Transform.translate(
                                offset: Offset(0, 2 * math.sin(t * math.pi)),
                                child: child),
                          );
                        },
                        child: CompanionView(
                          hero: _selectedAvatar,
                          mood: CompanionMood.idle,
                          size: 92,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SpeechBubble(
                          text: context.l10n.onboardingNameQuestion,
                          pointer: BubblePointer.start,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.onboardingNameHint,
                    style: theme.textTheme.labelLarge!
                        .withWeight(FontWeight.w800)
                        .copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: OnboardingScreen.nameFieldKey,
                    controller: _nameController,
                    maxLength: UserProfile.maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.nickname],
                    onChanged: (_) => _onNameChanged(),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    style: theme.textTheme.headlineSmall!
                        .withWeight(FontWeight.w800)
                        .copyWith(color: c.text),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: context.l10n.onboardingNameHint,
                      fillColor: c.card,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: c.line, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: c.navy, width: 3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.onboardingNameNote,
                    style: theme.textTheme.bodySmall!.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 12),
            child: AnimatedOpacity(
              opacity: 1,
              duration: AppMotion.orInstant(
                  context, const Duration(milliseconds: 200)),
              child: PressableButton(
                key: OnboardingScreen.continueKey,
                label: context.l10n.commonContinue,
                tone: ButtonTone.orange,
                haptic: ButtonHaptic.light,
                trailingIcon: _arrow(context),
                onPressed: _canContinue ? _continue : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalStep(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final hPad = _sidePadding(context);
    final muted = theme.textTheme.labelSmall!
        .withWeight(FontWeight.w400)
        .copyWith(color: c.muted, height: 1.6);
    return Column(
      children: [
        _StepTop(step: 3, onBack: _back, bar: true),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CompanionView(
                        hero: _selectedAvatar,
                        mood: CompanionMood.wave,
                        size: 44),
                    const SizedBox(width: 6),
                    Flexible(
                      child: SpeechBubble(
                        text: context.l10n.onboardingNiceToMeet(_name),
                        pointer: BubblePointer.start,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.onboardingGoalQuestion(_name),
                  style: theme.textTheme.headlineMedium!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text, letterSpacing: -.8),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.onboardingGoalPickOne,
                  style: theme.textTheme.bodyMedium!.copyWith(color: c.muted),
                ),
                const SizedBox(height: 18),
                for (final (i, goal) in LearningGoal.values.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _Entrance(
                    delay: AppMotion.stagger * i,
                    child: GoalCard(
                      key: OnboardingScreen.goalKey(goal),
                      goal: goal,
                      hero: _selectedAvatar,
                      selected: goal == _selectedGoal,
                      onTap: () {
                        if (_selectedGoal == goal) return;
                        HapticMap.selection();
                        setState(() => _selectedGoal = goal);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.lock_outline_rounded,
                          size: 15, color: c.muted),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(onboardingPrivacyNote(context.l10n),
                              style: muted),
                          TextButton(
                            key: OnboardingScreen.dataLinkKey,
                            focusNode: _dataLinkFocus,
                            onPressed: _showDataSheet,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: EdgeInsets.zero,
                              alignment: AlignmentDirectional.centerStart,
                              foregroundColor: c.navy,
                              textStyle: theme.textTheme.labelSmall!
                                  .withWeight(FontWeight.w700),
                            ),
                            child: Text(context.l10n.onboardingDataLink),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 6),
          child: Column(
            children: [
              PressableButton(
                key: OnboardingScreen.startKey,
                label: context.l10n.commonContinue,
                tone: ButtonTone.orange,
                shine: _selectedGoal != null,
                trailingIcon: _arrow(context),
                onPressed: _selectedGoal == null
                    ? null
                    : () => _finish(skipGoal: false),
              ),
              PressableButton(
                key: OnboardingScreen.skipGoalKey,
                label: context.l10n.onboardingSkipForNow,
                tone: ButtonTone.text,
                height: 44,
                haptic: ButtonHaptic.light,
                onPressed: () => _finish(skipGoal: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _arrow(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
          ? Icons.arrow_back_rounded
          : Icons.arrow_forward_rounded;
}

/// The step's top line: Back (from step 2 on) and the step dots, or the
/// goal step's progress bar with "N of M".
class _StepTop extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  final bool bar;

  const _StepTop({required this.step, required this.onBack, this.bar = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    const total = OnboardingScreen.stepCount;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            key: OnboardingScreen.backKey,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: c.text),
          ),
          Expanded(
            child: bar
                ? Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: (step - 1) / total, end: step / total),
                          duration:
                              AppMotion.orInstant(context, AppMotion.slow),
                          curve: AppMotion.enter,
                          builder: (context, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 10,
                            color: c.orange,
                            backgroundColor: c.track,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.l10n.onboardingStepShort(step, total),
                      style: theme.textTheme.labelMedium!
                          .withWeight(FontWeight.w800)
                          .copyWith(color: c.muted),
                    ),
                  ])
                : Center(child: OnboardingStepDots(step: step, count: total)),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Rises 16 px and fades in after [delay] (V05: cards from below, 60 ms
/// apart).
class _Entrance extends StatelessWidget {
  final Duration delay;
  final Widget child;
  const _Entrance({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final total = AppMotion.slow + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? AppMotion.fast : total,
      curve: reduced
          ? Curves.linear
          : Interval(delay.inMilliseconds / total.inMilliseconds, 1,
              curve: AppMotion.enter),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
            offset: Offset(0, reduced ? 0 : 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// One goal as a big card (V05): an icon tile, title and description. The
/// selected card gets a navy frame on the sky surface and lifts (1.03, a
/// slight tilt); the buddy pops out of its corner in the cheer pose with a
/// 4-piece confetti burst, and a reaction line appears 150 ms later.
/// Screen readers hear it as one of a group, selected or not.
class GoalCard extends StatelessWidget {
  final LearningGoal goal;
  final Avatar hero;
  final bool selected;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.hero,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final reduced = AppMotion.reduced(context);
    final duration = AppMotion.orInstant(context, AppMotion.base);
    final tilt = switch (goal) {
      LearningGoal.examPrep => -2.0,
      LearningGoal.work => 2.0,
      LearningGoal.school => 1.5,
      LearningGoal.general => -1.5,
    };
    final (tile, tileFg) = switch (goal) {
      LearningGoal.examPrep => (c.cream, c.orangeDeep),
      LearningGoal.work => (c.sky, c.navy),
      LearningGoal.school => (c.lilac, c.onLilac),
      LearningGoal.general => (c.greenSoft, c.greenDeep),
    };
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: '${goal.label(l10n)}. ${goal.description(l10n)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: selected && !reduced ? 1.03 : 1,
          duration: duration,
          curve: AppMotion.pop,
          child: AnimatedRotation(
            turns: selected && !reduced ? tilt / 360 : 0,
            duration: duration,
            curve: AppMotion.pop,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: AppMotion.orInstant(context, AppMotion.fast),
                  // V05 v10 (four cards): 80 tall, 13 / 14 padding.
                  constraints: const BoxConstraints(minHeight: 80),
                  padding: EdgeInsetsDirectional.fromSTEB(
                      14, 13, selected ? 86 : 14, 13),
                  decoration: lipCard(
                    c,
                    color: selected ? c.sky : c.card,
                    border: selected ? c.navy : c.line,
                    lip: selected ? c.navy : c.lip,
                    borderWidth: selected ? 3 : 2,
                    radius: 24,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: selected ? c.card : tile,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(learningGoalIcon(goal),
                            color: tileFg, size: 26),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.label(l10n),
                              style: theme.textTheme.titleLarge!
                                  .withWeight(FontWeight.w900)
                                  .copyWith(color: c.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              goal.description(l10n),
                              style: theme.textTheme.bodySmall!
                                  .copyWith(color: c.muted),
                            ),
                            AnimatedSize(
                              // Never zero: a zero-length AnimatedSize
                              // re-dirties its own layout.
                              duration: reduced
                                  ? const Duration(milliseconds: 1)
                                  : duration,
                              child: selected
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: _Delayed(
                                        delay:
                                            const Duration(milliseconds: 150),
                                        child: Text(
                                          goal.reaction(l10n),
                                          style: theme.textTheme.labelLarge!
                                              .withWeight(FontWeight.w900)
                                              .copyWith(
                                                  color: c.navy,
                                                  fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  end: 4,
                  bottom: 6,
                  child: AnimatedSwitcher(
                    duration: duration,
                    transitionBuilder: (child, animation) => SlideTransition(
                      position:
                          Tween(begin: const Offset(0, .6), end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: animation, curve: AppMotion.pop)),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: selected
                        ? _PopOut(
                            key: ValueKey(goal),
                            hero: hero,
                          )
                        : const SizedBox(key: ValueKey('none'), width: 76),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The buddy that pops out of the chosen card in the cheer pose, with four
/// confetti pieces and a light haptic.
class _PopOut extends StatefulWidget {
  final Avatar hero;
  const _PopOut({super.key, required this.hero});

  @override
  State<_PopOut> createState() => _PopOutState();
}

class _PopOutState extends State<_PopOut> {
  @override
  void initState() {
    super.initState();
    HapticMap.light();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CompanionView(hero: widget.hero, mood: CompanionMood.cheer, size: 76),
          if (!AppMotion.reduced(context))
            ConfettiBurst(
              origin: const Offset(38, 10),
              colors: [
                AppColors.of(context).orange,
                AppColors.of(context).navy,
                AppColors.of(context).gold,
                AppColors.of(context).green,
              ],
              count: 4,
              length: const Duration(milliseconds: 900),
            ),
        ],
      ),
    );
  }
}

/// Shows [child] after [delay] with a short fade.
class _Delayed extends StatelessWidget {
  final Duration delay;
  final Widget child;
  const _Delayed({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    final total = delay + AppMotion.fast;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}

/// "Your data & AI": the facts in [onboardingDataFacts], readable in one
/// place. Information only: "Got it" closes it and records nothing. It
/// never stands in for the separate AI permission step
/// (`ai_consent_screen.dart`), which Topic Practice still asks first. As a
/// dialog it takes the focus while open and blocks the page behind.
class _DataDialog extends StatelessWidget {
  const _DataDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final body = theme.textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.6);
    return Dialog(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(23),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.l10n.onboardingDataTitle,
                style: theme.textTheme.titleLarge
                    ?.withWeight(FontWeight.w900)
                    .copyWith(color: colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
            for (final (heading, text)
                in onboardingDataFacts(context.l10n)) ...[
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$heading\n',
                    style: body
                        ?.withWeight(FontWeight.w800)
                        .copyWith(color: colorScheme.onSurface),
                  ),
                  TextSpan(text: text),
                ]),
                style: body,
              ),
              const SizedBox(height: 15),
            ],
            const SizedBox(height: 4),
            FilledButton(
              key: OnboardingScreen.gotItKey,
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.onboardingDataGotIt),
            ),
          ],
        ),
      ),
    );
  }
}
