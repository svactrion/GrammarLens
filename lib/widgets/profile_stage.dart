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
/// from 12 pt below, with the name, "Climbing with <Hero>" and a pencil
/// (→ PF04); then three stat tiles.
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

  const ProfileStage({
    super.key,
    required this.hero,
    required this.name,
    required this.onChange,
    required this.onEditName,
    this.points,
    this.step,
    this.weakSpots,
  });

  static const changeKey = ValueKey('profile_change_buddy');
  static const pencilKey = ValueKey('profile_edit_name');
  static const nameKey = ValueKey('settings_name');

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
        Stack(clipBehavior: Clip.none, children: [
          Container(
            height: 210,
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
                  mood: _waves == 0 ? CompanionMood.idle : CompanionMood.wave,
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
        // The ribbon settles from 12 pt below as the stage opens.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: AppMotion.reduced(context) ? 1 : 0, end: 1),
          duration:
              AppMotion.orInstant(context, AppMotion.base + AppMotion.press),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Transform.translate(
              offset: Offset(0, 12 * (1 - t) - 18), child: child),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: lipCard(c,
                color: c.navy, border: c.navy, lip: c.navyDeep, radius: 18),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.orInstant(context, AppMotion.fast),
                      child: Text(
                        widget.name,
                        key: ProfileStage.nameKey,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge!
                            .withWeight(FontWeight.w900)
                            .copyWith(color: c.onNavy),
                      ),
                    ),
                    Text(l10n.profileClimbingWith(widget.hero.name(l10n)),
                        style: theme.textTheme.labelMedium!
                            .withWeight(FontWeight.w700)
                            .copyWith(color: c.onNavyMuted)),
                  ],
                ),
              ),
              IconButton(
                key: ProfileStage.pencilKey,
                tooltip: l10n.settingsEditName,
                onPressed: widget.onEditName,
                icon: Icon(Icons.edit_rounded, color: c.onNavy),
              ),
            ]),
          ),
        ),
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
