import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../models/daily_test_set.dart';
import '../models/learning_goal.dart';
import '../models/user_profile.dart';
import '../theme.dart';
import '../utils/content_width.dart';
import '../widgets/avatar_carousel.dart';
import '../widgets/avatar_tile.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/brand_wordmark.dart';

/// The short privacy line under the goal options. Public so a test can pin
/// the wording to what the app actually does: the name never leaves the
/// device; the goal is the `learning_goal` analytics user property (1.2.0),
/// sent with usage data and never with the name; Firebase collects usage
/// and crash data. The AI facts are in [OnboardingScreen]'s "Your data &
/// AI" sheet, one tap away.
const String onboardingPrivacyNote =
    'Your name stays on this device. Your goal is sent with app usage data, '
    'never with your name. Usage and crash data is collected.';

/// The "Your data & AI" sheet's rows (heading, text), in order. Public for
/// the same reason as [onboardingPrivacyNote].
const List<(String, String)> onboardingDataFacts = [
  ('On this device', 'Your name stays on this device.'),
  (
    'Your learning goal',
    'Sent with app usage data, never with your name, to help us decide what '
        'to improve. It does not personalize your lessons.'
  ),
  (
    'AI feedback',
    'If you use Topic Practice, your answers are sent to Anthropic (Claude) '
        'to give you feedback. We ask for your permission first.'
  ),
  ('App diagnostics', 'Usage and crash data is collected.'),
];

/// Onboarding in two short steps (the 1.2.0 additional screens package),
/// after Welcome and before the first Daily Test:
///
/// 1. **Companion and name.** The avatar carousel (every avatar, the
///    existing IDs and loop) and the name, which is required (owner
///    decision, 2026-10-05): Continue stays disabled while the name is
///    empty or only spaces. At most [UserProfile.maxNameLength] characters.
/// 2. **Goal.** Asked to understand who uses the app, not to personalize
///    anything. No option is preselected; "Skip goal & start" finishes with
///    no goal (stored as `skipped`, never counted as general fluency).
///
/// Back on step 2 returns to step 1 with the name, the avatar and the goal
/// as they were. Nothing is saved until step 2 finishes ([onComplete]);
/// leaving earlier leaves onboarding not done.
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

  /// The step change: a short fade, none with reduce motion.
  static const Duration stepDuration = Duration(milliseconds: 200);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _dataLinkFocus = FocusNode(debugLabel: 'data link');
  LearningGoal? _selectedGoal;
  bool _onGoalStep = false;

  // Random on mount, never null (PRD v2 §13.5's "no empty state" rule): a
  // user who never touches the carousel still ends up with a real avatar.
  late Avatar _selectedAvatar = Avatar.random();

  @override
  void dispose() {
    _nameController.dispose();
    _dataLinkFocus.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  bool get _canContinue => _name.isNotEmpty;

  void _continue() {
    if (!_canContinue) return;
    FocusScope.of(context).unfocus();
    setState(() => _onGoalStep = true);
  }

  void _back() => setState(() => _onGoalStep = false);

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
    return PopScope(
      // A back gesture on the goal step goes to the first step, not out.
      canPop: !_onGoalStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _onGoalStep) _back();
      },
      child: BrandScaffold(
        // The status bar only: the step's own header is in the page.
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
        ),
        body: AnimatedSwitcher(
          duration:
              reduceMotion ? Duration.zero : OnboardingScreen.stepDuration,
          switchInCurve: Curves.easeOut,
          child: _onGoalStep ? _goalStep(context) : _nameStep(context),
        ),
      ),
    );
  }

  double _sidePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ContentWidth.sidePaddingOf(context, base: width < 360 ? 17 : 22);
  }

  Widget _nameStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final hPad = _sidePadding(context);
    final narrow = width < 360;
    // A tap anywhere outside the name field closes the keyboard and keeps
    // the name, so the companions can be looked at again in full (owner,
    // after Batch 11). Buttons and the carousel's drag still win their own
    // gestures; a tap never changes the companion.
    return GestureDetector(
      key: const ValueKey('onboarding_step_1'),
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          const _StepHeader(step: 1, onBack: null),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Heading(
                    eyebrow: 'A little practice. Every day.',
                    title: 'Meet your learning companion.',
                    subtitle: '${_countWord(DailyTestSet.questionCount)} '
                        'questions a day. A small step forward, together.',
                  ),
                  const SizedBox(height: 10),
                  // The warm glow behind the selected companion.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -.1),
                        radius: .55,
                        colors: [
                          palette.warm,
                          palette.warm.withValues(alpha: 0)
                        ],
                      ),
                    ),
                    child: AvatarCarousel(
                      initialAvatar: _selectedAvatar,
                      onSettled: (avatar) =>
                          setState(() => _selectedAvatar = avatar),
                      centerRadius: 75,
                      // 150 pt tiles 18 apart, as wide as the screen allows.
                      viewportFraction: (168 / width).clamp(0.3, 1.0),
                      neighborScale: .72,
                      neighborOpacity: .48,
                      showNavigation: true,
                    ),
                  ),
                  Text(
                    'Swipe to choose · Change it later in Profile',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.withWeight(FontWeight.w400)
                        .copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: _NameCard(
                      controller: _nameController,
                      padding: narrow ? 15 : 19,
                      onChanged: () => setState(() {}),
                      // The keyboard's Done only closes the keyboard; the next
                      // step is reached with Continue alone.
                      onSubmitted: () => FocusScope.of(context).unfocus(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _BottomActions(
            horizontalPadding: hPad,
            children: [
              _PrimaryCta(
                buttonKey: OnboardingScreen.continueKey,
                label: 'Continue',
                onPressed: _canContinue ? _continue : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalStep(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hPad = _sidePadding(context);
    final muted = theme.textTheme.labelSmall
        ?.withWeight(FontWeight.w400)
        .copyWith(color: colorScheme.onSurfaceVariant, height: 1.6);
    return Column(
      key: const ValueKey('onboarding_step_2'),
      children: [
        _StepHeader(step: 2, onBack: _back),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The companion picked on step 1, with the name.
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AvatarTile(avatar: _selectedAvatar, radius: 24),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          'One more thing, $_name.',
                          style: theme.textTheme.labelMedium
                              ?.withWeight(FontWeight.w700)
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 21),
                const _Heading(
                  eyebrow: 'Help shape GrammarLens',
                  title: 'What brings you to English?',
                  subtitle: 'Choose what matters most to you. Your answer '
                      'helps us decide what to improve next.',
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final goal in LearningGoal.values) ...[
                        if (goal != LearningGoal.values.first)
                          const SizedBox(height: 12),
                        _GoalOption(
                          key: OnboardingScreen.goalKey(goal),
                          goal: goal,
                          selected: goal == _selectedGoal,
                          onTap: () => setState(() => _selectedGoal = goal),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad + 1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.lock_outline_rounded,
                            size: 15, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(onboardingPrivacyNote, style: muted),
                            TextButton(
                              key: OnboardingScreen.dataLinkKey,
                              focusNode: _dataLinkFocus,
                              onPressed: _showDataSheet,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                foregroundColor: colorScheme.secondary,
                                textStyle: theme.textTheme.labelSmall
                                    ?.withWeight(FontWeight.w700),
                              ),
                              child: const Text(
                                  'How AI feedback uses your answers'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomActions(
          horizontalPadding: hPad,
          children: [
            _PrimaryCta(
              buttonKey: OnboardingScreen.startKey,
              label: 'Start my first test',
              onPressed:
                  _selectedGoal == null ? null : () => _finish(skipGoal: false),
            ),
            TextButton(
              key: OnboardingScreen.skipGoalKey,
              onPressed: () => _finish(skipGoal: true),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                foregroundColor: colorScheme.secondary,
                textStyle:
                    theme.textTheme.labelMedium?.withWeight(FontWeight.w700),
              ),
              child: const Text('Skip goal & start'),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Five" for 5: the Daily Test's question count in words, read from the
/// constant so the line cannot drift from the real test.
String _countWord(int n) {
  const words = [
    'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', //
    'Eight', 'Nine', 'Ten',
  ];
  return n >= 0 && n < words.length ? words[n] : '$n';
}

/// The step's top line: the wordmark (step 1) or Back (step 2), "Step N of
/// 2", and the two-part progress bar.
class _StepHeader extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;

  const _StepHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hPad = ContentWidth.sidePaddingOf(context, base: 19);
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    key: OnboardingScreen.backKey,
                    tooltip: 'Back',
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, size: 21),
                  )
                else
                  BrandWordmark(
                    style: theme.textTheme.titleLarge
                        ?.withWeight(FontWeight.w900)
                        .copyWith(
                            color: colorScheme.onSurface, letterSpacing: -.6),
                  ),
                const Spacer(),
                Text(
                  'Step $step of 2',
                  style: theme.textTheme.labelSmall
                      ?.withWeight(FontWeight.w700)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 26),
            child: Semantics(
              label: 'Step $step of 2',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 1; i <= 2; i++) ...[
                    if (i > 1) const SizedBox(width: 7),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The eyebrow (11 / 800, upper case, link colour), the title (29 / 900 at
/// Medium) and the supporting line, centred and wrapping.
class _Heading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _Heading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // The theme's 26 / 900 question title scaled to the mockup's 29, so it
    // follows the text size setting like every other style.
    final base = theme.textTheme.headlineMedium!;
    final titleStyle = base.copyWith(
      fontSize: base.fontSize! * 29 / 26,
      height: 1.15,
      letterSpacing: -.7,
      color: colorScheme.onSurface,
    );
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: ContentWidth.sidePaddingOf(context, base: 23)),
      child: Column(
        children: [
          Text(
            eyebrow.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w800)
                .copyWith(color: colorScheme.secondary, letterSpacing: 1.1),
          ),
          const SizedBox(height: 9),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: titleStyle),
          ),
          const SizedBox(height: 11),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// "What should we call you?": card surface, radius 22, the field at least
/// 52 tall with radius 13, and the line under it.
class _NameCard extends StatelessWidget {
  final TextEditingController controller;
  final double padding;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  const _NameCard({
    required this.controller,
    required this.padding,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: color, width: width),
        );
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(22),
        boxShadow: palette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What should we call you?',
            style: theme.textTheme.titleSmall
                ?.withWeight(FontWeight.w800)
                .copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: TextField(
              key: OnboardingScreen.nameFieldKey,
              controller: controller,
              maxLength: UserProfile.maxNameLength,
              // No visible counter (owner decision O2).
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      required maxLength}) =>
                  null,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              // Room above for the question and below for the card's line,
              // when the keyboard opens and the field scrolls into view.
              scrollPadding: const EdgeInsets.fromLTRB(20, 56, 20, 60),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Your name',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                enabledBorder: border(palette.inputBorder, 1),
                border: border(palette.inputBorder, 1),
                focusedBorder: border(colorScheme.secondary, 2),
              ),
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A nickname is fine. It stays on this device.',
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w400)
                .copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// The fixed area under the scrolling content: above the keyboard while it
/// is open, inside the bottom safe area otherwise.
class _BottomActions extends StatelessWidget {
  final double horizontalPadding;
  final List<Widget> children;

  const _BottomActions({
    required this.horizontalPadding,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding:
            EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// The step's main action: brandOrange with the onOrange text, at least
/// 54 tall, radius 17, 900, an arrow after the label; the app's opaque
/// disabled pairing while it cannot be used. No navy edge in dark mode.
class _PrimaryCta extends StatelessWidget {
  final Key buttonKey;
  final String label;
  final VoidCallback? onPressed;

  const _PrimaryCta({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        disabledBackgroundColor: palette.disabledFill,
        disabledForegroundColor: palette.disabledLabel,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: theme.textTheme.bodyLarge?.withWeight(FontWeight.w900),
      ).copyWith(side: const WidgetStatePropertyAll(BorderSide.none)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          const SizedBox(width: 9),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}

IconData _iconFor(LearningGoal goal) {
  switch (goal) {
    case LearningGoal.examPrep:
      return Icons.school_rounded;
    case LearningGoal.work:
      return Icons.work_rounded;
    case LearningGoal.general:
      return Icons.chat_bubble_rounded;
  }
}

/// One goal as a radio card: radius 21, at least 91 tall, the icon in a
/// 40 pt tile, title and description, and a radio mark. Selected: a 2 pt
/// link-coloured edge on the info surface, and the mark filled; screen
/// readers hear it as one of a group, selected or not.
class _GoalOption extends StatelessWidget {
  final LearningGoal goal;
  final bool selected;
  final VoidCallback onTap;

  const _GoalOption({
    super.key,
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final radius = BorderRadius.circular(21);
    final edge = selected ? 2.0 : 1.0;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 91),
            padding: EdgeInsets.symmetric(
                vertical: 17 - edge + 1,
                horizontal: (narrow ? 11 : 14) - edge + 1),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? colorScheme.secondary
                    : colorScheme.outlineVariant,
                width: edge,
              ),
              boxShadow: selected ? null : palette.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: narrow ? 36 : 40,
                  height: narrow ? 36 : 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.surfaceContainerHigh
                        : colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_iconFor(goal),
                      size: 21, color: colorScheme.secondary),
                ),
                SizedBox(width: narrow ? 8 : 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.label,
                        style: theme.textTheme.titleSmall
                            ?.withWeight(FontWeight.w800)
                            .copyWith(color: colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.description,
                        style: theme.textTheme.labelMedium
                            ?.withWeight(FontWeight.w400)
                            .copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.45),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: narrow ? 8 : 11),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected
                      ? colorScheme.secondary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
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
                'Your data & AI',
                style: theme.textTheme.titleLarge
                    ?.withWeight(FontWeight.w900)
                    .copyWith(color: colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
            for (final (heading, text) in onboardingDataFacts) ...[
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
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
