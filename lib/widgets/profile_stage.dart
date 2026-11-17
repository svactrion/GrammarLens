import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import 'companion_view.dart';
import 'pressable_button.dart';

/// V23: the profile's top. The companion on its own coloured stage (it
/// waves when tapped) with "Change" (→ R06); a ribbon under it, settling
/// from 12 pt below, with the name, "Climbing with <Hero> · since <month
/// year>" and a pencil (→ PF04); then three stat tiles.
class ProfileStage extends StatefulWidget {
  final Avatar hero;
  final String name;
  final VoidCallback onChange;
  final VoidCallback onEditName;

  /// This month's points and step, and the weak spots saved; null while
  /// unknown (the tile shows a dash).
  final int? points;
  final int? step;
  final int? weakSpots;

  /// When the first Daily Test was completed; the ribbon's "· since
  /// <month year>" is left out while null (none yet, or not read).
  final DateTime? since;

  const ProfileStage({
    super.key,
    required this.hero,
    required this.name,
    required this.onChange,
    required this.onEditName,
    this.points,
    this.step,
    this.weakSpots,
    this.since,
  });

  static const changeKey = ValueKey('profile_change_buddy');
  static const pencilKey = ValueKey('profile_edit_name');
  static const nameKey = ValueKey('settings_name');
  static const climbingKey = ValueKey('profile_climbing_with');
  static const ribbonKey = ValueKey('profile_ribbon');
  static const tailStartKey = ValueKey('profile_ribbon_tail_start');
  static const tailEndKey = ValueKey('profile_ribbon_tail_end');

  /// The companion's stage.
  static const double stageHeight = 210;

  @override
  State<ProfileStage> createState() => _ProfileStageState();
}

class _ProfileStageState extends State<ProfileStage> {
  int _waves = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stage = AppColors.stageFor(widget.hero.order, theme.brightness);
    const dash = '–'; // l10n-guard: a placeholder for an unknown number
    final since = widget.since;
    Widget tile(String value, String label, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: lipCard(c, radius: 18),
            child: Column(children: [
              Icon(icon, size: 20, color: c.orangeDeep),
              const SizedBox(height: 4),
              Text(value,
                  style: theme.textTheme.titleLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text)),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall!
                      .withWeight(FontWeight.w700)
                      .copyWith(color: c.muted)),
            ]),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // V23: the ribbon overlaps the stage's bottom by 40 pt. The ribbon
        // sizes the stack (it may grow with a wrapped line); the stage is
        // pinned to its top.
        Stack(clipBehavior: Clip.none, children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: ProfileStage.stageHeight,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                height: ProfileStage.stageHeight,
                decoration: BoxDecoration(
                  color: stage,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _waves++),
                    child: CompanionView(
                      key: ValueKey(_waves),
                      hero: widget.hero,
                      mood:
                          _waves == 0 ? CompanionMood.idle : CompanionMood.wave,
                      size: 150,
                      semanticLabel: widget.hero.name(l10n),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 12,
                end: 12,
                child: PressableButton(
                  key: ProfileStage.changeKey,
                  label: l10n.profileChange,
                  semanticLabel: l10n.settingsChangeAvatar,
                  tone: ButtonTone.outline,
                  height: 40,
                  expand: false,
                  leadingIcon: Icons.autorenew_rounded,
                  haptic: ButtonHaptic.light,
                  onPressed: widget.onChange,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(
                top: ProfileStage.stageHeight - _Ribbon.overlap),
            child: Center(
              child: _Ribbon(
                name: widget.name,
                line: since == null
                    ? l10n.profileClimbingWith(widget.hero.name(l10n))
                    : l10n.profileClimbingWithSince(widget.hero.name(l10n),
                        monthYearShort(since.year, since.month, l10n)),
                onEditName: widget.onEditName,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          tile(widget.points?.toString() ?? dash, l10n.profileStatPoints,
              Icons.star_rounded),
          const SizedBox(width: 8),
          tile(widget.step?.toString() ?? dash, l10n.profileStatStep,
              Icons.flag_rounded),
          const SizedBox(width: 8),
          tile(widget.weakSpots?.toString() ?? dash, l10n.profileStatWeakSpots,
              Icons.history_rounded),
        ]),
      ],
    );
  }
}

/// V23's navy ribbon (fix round 2, item 4, the board's values): 286 × 62,
/// radius 16, a #1B4FB0 → navy fill on a 5 pt lip; two 46 × 46 tails with
/// V-cut ends, 26 pt outside each end and 14 pt down; the name (23/900,
/// white), "Climbing with <Hero> · since <Mon YYYY>" (12/700) and a 40 × 40
/// pencil (radius 12, white at 14 %). It settles from 12 pt below
/// (300 ms, easeOutBack). On a narrow screen it narrows so the tails stay
/// on screen; a long line wraps and the ribbon grows.
class _Ribbon extends StatelessWidget {
  final String name;
  final String line;
  final VoidCallback onEditName;

  const _Ribbon(
      {required this.name, required this.line, required this.onEditName});

  static const double width = 286;
  static const double height = 62;
  static const double lip = 5;
  static const double overlap = 40;
  static const double tail = 46;
  static const double tailOut = 26;
  static const double tailDown = 14;
  static const settle = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reduced = AppMotion.reduced(context);
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth.isFinite
          ? (constraints.maxWidth - 2 * tailOut - 8).clamp(180.0, width)
          : width;
      Widget tailOf(bool start) => PositionedDirectional(
            key: start ? ProfileStage.tailStartKey : ProfileStage.tailEndKey,
            start: start ? -tailOut : null,
            end: start ? null : -tailOut,
            top: tailDown,
            width: tail,
            height: tail,
            child: ClipPath(
              clipper: _TailClipper(
                  outerLeft: start ==
                      (Directionality.of(context) == TextDirection.ltr)),
              child: const ColoredBox(color: AppColors.ribbonLip),
            ),
          );
      final body = Container(
        key: ProfileStage.ribbonKey,
        width: w,
        constraints: const BoxConstraints(minHeight: height),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 8, 10, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.ribbonTop, c.navy],
          ),
          boxShadow: const [
            BoxShadow(color: AppColors.ribbonLip, offset: Offset(0, lip))
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One line: a long name scales down instead of wrapping.
                AnimatedSwitcher(
                  duration: AppMotion.orInstant(context, AppMotion.fast),
                  child: FittedBox(
                    key: ValueKey(name),
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      name,
                      key: ProfileStage.nameKey,
                      maxLines: 1,
                      style: theme.textTheme.titleLarge!
                          .withWeight(FontWeight.w900)
                          .copyWith(fontSize: 23, height: 1.1, color: c.onNavy),
                    ),
                  ),
                ),
                Text(
                  line,
                  key: ProfileStage.climbingKey,
                  style: theme.textTheme.labelMedium!
                      .withWeight(FontWeight.w700)
                      .copyWith(
                          fontSize: 12,
                          height: 1.25,
                          color: AppColors.onRibbonMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: l10n.settingsEditName,
            child: Semantics(
              button: true,
              label: l10n.settingsEditName,
              excludeSemantics: true,
              child: InkResponse(
                key: ProfileStage.pencilKey,
                // The opener plays the light haptic (SPEC V23).
                onTap: onEditName,
                radius: 24,
                // 44 pt to tap, the board's 40 pt to see.
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.onNavy.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Icon(Icons.edit_rounded, size: 20, color: c.onNavy),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: reduced ? Duration.zero : settle,
        curve: Curves.easeOutBack,
        builder: (context, t, child) =>
            Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
        child: Padding(
          padding: const EdgeInsets.only(bottom: lip),
          child: Stack(clipBehavior: Clip.none, children: [
            tailOf(true),
            tailOf(false),
            Material(type: MaterialType.transparency, child: body),
          ]),
        ),
      );
    });
  }
}

/// A ribbon tail: a square with a V cut into its outer end (the board's
/// `clip-path`: the notch reaches 34 % in).
class _TailClipper extends CustomClipper<Path> {
  final bool outerLeft;
  const _TailClipper({required this.outerLeft});

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    return outerLeft
        ? (Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..lineTo(w * .34, h / 2)
          ..close())
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w * .66, h / 2)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close());
  }

  @override
  bool shouldReclip(_TailClipper oldClipper) =>
      oldClipper.outerLeft != outerLeft;
}
