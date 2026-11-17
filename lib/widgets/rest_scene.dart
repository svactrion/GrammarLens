import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../motion.dart';
import '../theme.dart';
import 'companion_view.dart';
import 'monthly_climb/climb_route.dart';
import 'monthly_climb/mountain_scene.dart';
import 'speech_bubble.dart';
import 'step_bar.dart';

/// The time left until local midnight (the next Daily Test, the next free
/// ticket).
Duration timeToMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);

/// The rest scene (V24, SPEC §1.8): replaces Home's content once every daily
/// right is used. The camp at the companion's own step — the tent behind,
/// the campfire in front (the logs image, the flame drawn on top with its
/// base in the middle of the pile), warm ground light, rising sparks — the
/// companion asleep with its Zzz, "See you tomorrow, <name>", and a
/// countdown to the next Daily Test (local midnight), updated every minute.
/// The board's reminder switch comes in through [reminder] (TASK-widgets
/// fixed decision 7).
class RestScene extends StatefulWidget {
  final ClimbTheme theme;
  final int days;
  final int steps;
  final Avatar hero;
  final String name;

  /// "4/5 · +9 points" for the Daily Test tile, and the practice tile's
  /// line ("Ticket used" / "5/5 sessions").
  final String testLine;
  final String practiceLine;

  /// The score capsule, top right over the scene.
  final Widget? capsule;

  /// V24's "Remind me tomorrow" row (TASK-widgets fixed decision 7), under
  /// the countdown; none in previews.
  final Widget? reminder;
  final DateTime Function() clock;

  const RestScene({
    super.key,
    required this.theme,
    required this.days,
    required this.steps,
    required this.hero,
    required this.name,
    required this.testLine,
    required this.practiceLine,
    required this.clock,
    this.capsule,
    this.reminder,
  });

  static const sceneHeight = 470.0;

  @override
  State<RestScene> createState() => _RestSceneState();
}

class _RestSceneState extends State<RestScene> {
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final left = timeToMidnight(widget.clock());
    final hh = left.inHours.toString().padLeft(2, '0');
    final mm = (left.inMinutes % 60).toString().padLeft(2, '0');
    final days = widget.days.clamp(28, 31);
    final step = widget.steps.clamp(0, days);
    final focus = ClimbRoute(days).stepAt(step);
    // The panel is the night's own colour in both themes (the board).
    final panel = c.nightTop;
    const onPanel = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: RestScene.sceneHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned.fill(
                  child: MountainScene(
                    theme: widget.theme,
                    days: days,
                    showFlag: false,
                    zoom: 2.4,
                    focus: focus,
                    overlay: (context, map) {
                      final p = map.toBox(focus);
                      final k = map.scale / 900;
                      return Stack(clipBehavior: Clip.none, children: [
                        // The tent behind the companion.
                        Positioned(
                          left: p.dx + 4 * k,
                          top: p.dy - 120 * k,
                          width: 130 * k,
                          height: 110 * k,
                          child: Image.asset('assets/climb/objects/tent.webp',
                              fit: BoxFit.contain, excludeFromSemantics: true),
                        ),
                        // The companion asleep at its step.
                        Positioned(
                          left: p.dx - 70 * k,
                          top: p.dy - 104 * k,
                          width: 110 * k,
                          height: 110 * k,
                          child: CompanionView(
                              hero: widget.hero,
                              mood: CompanionMood.sleep,
                              size: 110 * k),
                        ),
                        // The campfire in front.
                        Positioned(
                          left: p.dx + 70 * k,
                          top: p.dy - 40 * k,
                          width: 76 * k,
                          height: 96 * k,
                          child: const _Campfire(),
                        ),
                        // The bubble above the sleeping companion, below
                        // the name chip and the capsule.
                        Positioned(
                          left: p.dx - 120 * k,
                          right: 16,
                          top: math.max(72.0, p.dy - 104 * k - 74),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 230),
                              child: SpeechBubble(
                                text: l10n.restBubble,
                                pointer: BubblePointer.bottomStart,
                                compact: true,
                              ),
                            ),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
                PositionedDirectional(
                  start: 12,
                  top: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: panel.withValues(alpha: .82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.restSeeYou(widget.name),
                      style: theme.textTheme.labelLarge!
                          .withWeight(FontWeight.w800)
                          .copyWith(color: onPanel),
                    ),
                  ),
                ),
                if (widget.capsule != null)
                  PositionedDirectional(
                      end: 10, top: 10, child: widget.capsule!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.nightTop, c.nightBottom],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.nightlight_round, color: c.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.restTitle,
                      style: theme.textTheme.titleLarge!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: onPanel)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(l10n.restBody,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(color: onPanel.withValues(alpha: .75))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _DoneTile(
                        title: l10n.featureDailyTest, line: widget.testLine)),
                const SizedBox(width: 10),
                Expanded(
                    child: _DoneTile(
                        title: l10n.restPracticeTitle,
                        line: widget.practiceLine)),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.restNextTest(step + 1).toUpperCase(),
                          style: theme.textTheme.labelMedium!
                              .withWeight(FontWeight.w900)
                              .copyWith(
                                  color: onPanel.withValues(alpha: .7),
                                  letterSpacing: 1.1),
                        ),
                        const SizedBox(height: 8),
                        StepBar(
                          segments: [
                            for (var i = 0; i < 10; i++)
                              i < (step % 10 == 0 && step > 0 ? 10 : step % 10)
                                  ? c.gold
                                  : null,
                          ],
                          track: Colors.white.withValues(alpha: .18),
                          height: 6,
                          gap: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Semantics(
                    label: l10n.restCountdownSemantics(
                        left.inHours, left.inMinutes % 60),
                    excludeSemantics: true,
                    child: Text(
                      '$hh:$mm', // l10n-guard: a time span of numbers
                      textScaler: TextScaler.noScaling,
                      style: theme.textTheme.headlineMedium!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: onPanel, fontFeatures: const [
                        FontFeature.tabularFigures()
                      ]),
                    ),
                  ),
                ]),
              ),
              if (widget.reminder != null) ...[
                const SizedBox(height: 10),
                widget.reminder!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DoneTile extends StatelessWidget {
  final String title;
  final String line;
  const _DoneTile({required this.title, required this.line});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: c.green, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: Colors.white)),
              Text(line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium!
                      .copyWith(color: Colors.white.withValues(alpha: .7))),
            ],
          ),
        ),
      ]),
    );
  }
}

/// The campfire: the logs image with two flame layers flickering in
/// opposite phase (0.5 s and 0.38 s), sparks rising (1.4 s) and a warm
/// ground light breathing (1.6 s). Still under Reduce Motion.
class _Campfire extends StatefulWidget {
  const _Campfire();

  @override
  State<_Campfire> createState() => _CampfireState();
}

class _CampfireState extends State<_Campfire>
    with SingleTickerProviderStateMixin {
  AnimationController? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _t == null) {
      // One clock for every layer: 5.6 s holds whole cycles of each.
      _t = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 5600))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _t?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget paint(double seconds) => CustomPaint(
          painter: _FirePainter(
              seconds: seconds, flame: c.orange, core: c.gold, glow: c.orange),
          foregroundPainter:
              _FlamePainter(seconds: seconds, flame: c.orange, core: c.gold),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: .5,
              child: Image.asset('assets/ui/campfire_logs.webp',
                  fit: BoxFit.contain, excludeFromSemantics: true),
            ),
          ),
        );
    final t = _t;
    return ExcludeSemantics(
      child: t == null
          ? paint(0)
          : AnimatedBuilder(
              animation: t, builder: (context, _) => paint(t.value * 5.6)),
    );
  }
}

/// The ground light and the rising sparks, under the logs.
class _FirePainter extends CustomPainter {
  final double seconds;
  final Color flame;
  final Color core;
  final Color glow;
  _FirePainter(
      {required this.seconds,
      required this.flame,
      required this.core,
      required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final breathe = .75 + .25 * math.sin(seconds / 1.6 * 2 * math.pi);
    final base = Offset(size.width / 2, size.height * .82);
    canvas.drawOval(
        Rect.fromCenter(
            center: base,
            width: size.width * 1.6 * breathe,
            height: size.height * .35 * breathe),
        Paint()
          ..shader = RadialGradient(colors: [
            glow.withValues(alpha: .45),
            glow.withValues(alpha: 0),
          ]).createShader(Rect.fromCenter(
              center: base,
              width: size.width * 1.6,
              height: size.height * .35)));
    for (var i = 0; i < 4; i++) {
      final p = ((seconds + i * .35) / 1.4) % 1.0;
      final x = size.width / 2 + math.sin((p + i) * 6) * size.width * .12;
      final y = size.height * .55 - p * size.height * .6;
      canvas.drawCircle(
          Offset(x, y), 1.6, Paint()..color = core.withValues(alpha: 1 - p));
    }
  }

  @override
  bool shouldRepaint(_FirePainter old) => old.seconds != seconds;
}

/// The flame drawn on top of the logs, its base in the middle of the pile.
class _FlamePainter extends CustomPainter {
  final double seconds;
  final Color flame;
  final Color core;
  _FlamePainter(
      {required this.seconds, required this.flame, required this.core});

  Path _flame(Offset base, double w, double h) => Path()
    ..moveTo(base.dx - w / 2, base.dy)
    ..quadraticBezierTo(
        base.dx - w * .6, base.dy - h * .55, base.dx, base.dy - h)
    ..quadraticBezierTo(
        base.dx + w * .6, base.dy - h * .55, base.dx + w / 2, base.dy)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset(size.width / 2, size.height * .78);
    final a = math.sin(seconds / .5 * 2 * math.pi);
    final b = -math.sin(seconds / .38 * 2 * math.pi);
    canvas.drawPath(
        _flame(
            base, size.width * (.46 + .04 * a), size.height * (.62 + .06 * a)),
        Paint()..color = flame);
    canvas.drawPath(
        _flame(
            base, size.width * (.26 + .03 * b), size.height * (.4 + .05 * b)),
        Paint()..color = core);
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.seconds != seconds;
}
