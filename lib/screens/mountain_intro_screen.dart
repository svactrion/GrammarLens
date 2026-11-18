import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/buddy_picker.dart';
import '../widgets/monthly_climb/mountain_scene.dart';
import '../widgets/pressable_button.dart';
import '../utils/upper_case.dart';

/// This month's mountain (V06): the month's whole mountain with the summit
/// flag (v2) on the summit and the avatar at the start; below,
/// "<MONTH> · <MOUNTAIN>", the title, a line, and "Take my first step"
/// (→ the Day-0 Daily Test, a medium haptic).
///
/// Motion: the mountain scales 0.9 → 1 (600 ms, easeOutCubic); the flag's
/// pole pops and the pennant waves; the avatar hops twice at the start; the
/// bottom panel slides up 24 px (300 ms). Reduce Motion: all at rest.
class MountainIntroScreen extends StatefulWidget {
  final ClimbTheme theme;
  final Avatar hero;
  final int days;
  final String monthName;
  final VoidCallback onStart;

  const MountainIntroScreen({
    super.key,
    required this.theme,
    required this.hero,
    required this.days,
    required this.monthName,
    required this.onStart,
  });

  static const startKey = ValueKey('mountain_intro_start');

  @override
  State<MountainIntroScreen> createState() => _MountainIntroScreenState();
}

class _MountainIntroScreenState extends State<MountainIntroScreen>
    with SingleTickerProviderStateMixin {
  static const _length = Duration(milliseconds: 1700);
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(vsync: this, duration: _length);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.value == 0 && !_intro.isAnimating) {
      if (AppMotion.reduced(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  double _t(int startMs, int lengthMs) =>
      ((_intro.value * _length.inMilliseconds - startMs) / lengthMs)
          .clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.page,
      body: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final scale = .9 + .1 * AppMotion.enter.transform(_t(0, 600));
          final flag = _t(450, 400);
          // Two hops at the start, 300 ms each.
          final hopT = _t(900, 600);
          final hop = hopT == 0 || hopT == 1
              ? 0.0
              : math.sin(math.pi * ((hopT * 2) % 1.0)) * 12;
          final panel = AppMotion.enter.transform(_t(200, 300));
          return Column(
            children: [
              Container(
                color: c.orangeSoft,
                child: const SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 34,
                    child: Center(child: OnboardingStepDots(step: 4)),
                  ),
                ),
              ),
              Expanded(
                child: Transform.scale(
                  scale: scale,
                  child: MountainScene(
                    theme: widget.theme,
                    days: widget.days,
                    avatar: widget.hero,
                    avatarDay: 0,
                    avatarSize: 64,
                    avatarLift: hop,
                    flagPop: flag,
                    alignment: Alignment.topCenter,
                    overlay: (context, map) {
                      final p = map.toBox(MountainScene.flagPointFor(
                          widget.theme, Theme.of(context).brightness));
                      return Stack(children: [
                        Positioned(
                          left: p.dx + 22,
                          top: p.dy - map.imageSize.width * .12,
                          // With the flag on the summit (fix round 2) the
                          // chip starts further right: it scales down
                          // rather than run off a narrow screen.
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth:
                                    math.max(0, map.box.width - p.dx - 22 - 8)),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Opacity(
                                opacity: flag,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l10n.mountainIntroSummit(widget.days),
                                    style: text.labelMedium!
                                        .withWeight(FontWeight.w900)
                                        .copyWith(color: c.navyText),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
              ),
              Opacity(
                opacity: panel,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - panel)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.page,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.mountainIntroEyebrow(
                                upperCaseFor(context, widget.monthName),
                                upperCaseFor(
                                    context, widget.theme.title(l10n))),
                            style: text.labelMedium!
                                .withWeight(FontWeight.w900)
                                .copyWith(
                                    color: c.orangeText, letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.mountainIntroTitle,
                            style: text.headlineMedium!
                                .withWeight(FontWeight.w900)
                                .copyWith(color: c.text, letterSpacing: -.8),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.mountainIntroBody,
                            style: text.bodyMedium!.copyWith(color: c.muted),
                          ),
                          const SizedBox(height: 22),
                          PressableButton(
                            key: MountainIntroScreen.startKey,
                            label: l10n.mountainIntroStart,
                            tone: ButtonTone.orange,
                            shine: true,
                            trailingIcon:
                                Directionality.of(context) == TextDirection.rtl
                                    ? Icons.arrow_back_rounded
                                    : Icons.arrow_forward_rounded,
                            onPressed: widget.onStart,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
