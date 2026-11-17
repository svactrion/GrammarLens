import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../motion.dart';
import '../utils/haptics.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'companion_view.dart';
import 'review_top_card.dart';
import 'pressable_button.dart';
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

  /// V24f (free users, SPEC §1.15): the dream bubble, the "All done"
  /// header and the Premium card with "Wake <Hero> up". Null for Premium
  /// users, who keep V24.
  final RestOffer? offer;

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
    this.offer,
  });

  static const sceneHeight = 470.0;

  /// V24f's scene is shorter, so the Premium card's button is on the first
  /// view (the board's scene takes under half the screen).
  static const freeSceneHeight = 300.0;

  /// How far above the companion's step V24f's camera centres, in image
  /// widths (about 130 pt at a phone's scale).
  static const freeFocusLift = .13;

  static const dreamKey = ValueKey('rest_dream');
  static const awakeBubbleKey = ValueKey('rest_awake_bubble');
  static const premiumCardKey = ValueKey('rest_premium_card');
  static const wakeKey = ValueKey('rest_wake');
  static const seeYouKey = ValueKey('rest_see_you');
  static ValueKey<String> ticketKey(int i) => ValueKey('rest_ticket_$i');

  /// V24s: how long the wake-up plays before the paywall rises.
  static const wakeLead = Duration(milliseconds: 600);

  @override
  State<RestScene> createState() => _RestSceneState();
}

class _RestSceneState extends State<RestScene>
    with SingleTickerProviderStateMixin {
  Timer? _minute;

  /// V24s: "Wake <Hero> up" was tapped: the companion is awake while the
  /// paywall is open; it falls asleep again when the paywall closes.
  bool _awake = false;

  /// The wake-up hop (one, 500 ms).
  late final AnimationController _hop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

  Future<void> _wake() async {
    final offer = widget.offer;
    if (offer == null || _awake) return;
    setState(() => _awake = true);
    if (!AppMotion.reduced(context)) {
      HapticMap.light();
      unawaited(_hop.forward(from: 0));
    }
    await Future<void>.delayed(
        AppMotion.orInstant(context, RestScene.wakeLead));
    if (!mounted) return;
    await offer.onWake();
    if (mounted) setState(() => _awake = false);
  }

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
    _hop.dispose();
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
    final offer = widget.offer;
    // V24f's scene is shorter: the camera looks a little higher up the
    // mountain so the companion sits near the scene's bottom, under the
    // dream bubble (as on the board), not behind it.
    final step0 = ClimbRoute(days).stepAt(step);
    final focus = offer == null
        ? step0
        : Offset(step0.dx, step0.dy - RestScene.freeFocusLift);
    // The panel is the night's own colour in both themes (the board).
    final panel = c.nightTop;
    const onPanel = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height:
              offer == null ? RestScene.sceneHeight : RestScene.freeSceneHeight,
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
                      // The camp stands at the companion's step.
                      final p = map.toBox(step0);
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
                          child: AnimatedBuilder(
                            animation: _hop,
                            builder: (context, child) => Transform.translate(
                                offset: Offset(0,
                                    -16 * k * math.sin(math.pi * _hop.value)),
                                child: child),
                            child: CompanionView(
                                hero: widget.hero,
                                mood: _awake
                                    ? CompanionMood.wave
                                    : CompanionMood.sleep,
                                // V24f: a dream bubble instead of the Zzz.
                                showProp: offer == null,
                                poseSwitch: _awake
                                    ? const Duration(milliseconds: 200)
                                    : const Duration(milliseconds: 400),
                                size: 110 * k),
                          ),
                        ),
                        // The campfire in front.
                        Positioned(
                          left: p.dx + 70 * k,
                          top: p.dy - 40 * k,
                          width: 76 * k,
                          height: 96 * k,
                          // V24s: the fire grows as the companion wakes.
                          child: AnimatedScale(
                            scale: _awake ? 1.25 : 1,
                            alignment: Alignment.bottomCenter,
                            duration: AppMotion.orInstant(
                                context, const Duration(milliseconds: 300)),
                            curve: AppMotion.pop,
                            child: const Campfire(),
                          ),
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
                              child: AnimatedSwitcher(
                                duration: AppMotion.orInstant(
                                    context, AppMotion.base),
                                child: offer == null
                                    ? SpeechBubble(
                                        text: l10n.restBubble,
                                        pointer: BubblePointer.bottomStart,
                                        compact: true,
                                      )
                                    : _awake
                                        ? SpeechBubble(
                                            key: RestScene.awakeBubbleKey,
                                            text: l10n.restAwake,
                                            pointer: BubblePointer.bottomStart,
                                            compact: true,
                                          )
                                        : offer.weakSpot == null
                                            ? const SizedBox.shrink()
                                            : _DreamBubble(
                                                key: RestScene.dreamKey,
                                                hero: widget.hero.name(l10n),
                                                spot: offer.weakSpot!),
                              ),
                            ),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
                if (offer == null)
                  PositionedDirectional(
                    key: RestScene.seeYouKey,
                    start: 12,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
        if (offer != null)
          _FreePanel(
            offer: offer,
            hero: widget.hero,
            testLine: widget.testLine,
            countdown: '$hh:$mm',
            countdownSemantics:
                l10n.restCountdownSemantics(left.inHours, left.inMinutes % 60),
            awake: _awake,
            onWake: _wake,
          )
        else
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
                                i <
                                        (step % 10 == 0 && step > 0
                                            ? 10
                                            : step % 10)
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
class Campfire extends StatefulWidget {
  const Campfire({super.key});

  @override
  State<Campfire> createState() => _CampfireState();
}

class _CampfireState extends State<Campfire>
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

/// V24f's offer (SPEC §1.15): what the free users' rest scene says and does.
class RestOffer {
  /// Today's weak spot (topic names stay English), or null: no dream
  /// bubble, and the card names the topics instead.
  final String? weakSpot;

  /// The store's free trial on the paywall's preselected plan, in days, or
  /// null (the button then promises none).
  final int? trialDays;

  /// The real number of practice topics (the fallback line counts them).
  final int topics;

  /// Opens the paywall (V13r); completes when it has closed.
  final Future<void> Function() onWake;

  const RestOffer({
    required this.weakSpot,
    required this.trialDays,
    required this.topics,
    required this.onWake,
  });
}

/// V24f: "<HERO> IS DREAMING OF…", today's weak spot and "today's weak
/// spot", with three small cloud dots from the head (200 ms apart); the
/// bubble floats (3.2 s).
class _DreamBubble extends StatefulWidget {
  final String hero;
  final String spot;
  const _DreamBubble({super.key, required this.hero, required this.spot});

  @override
  State<_DreamBubble> createState() => _DreamBubbleState();
}

class _DreamBubbleState extends State<_DreamBubble>
    with TickerProviderStateMixin {
  late final AnimationController _dots = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  AnimationController? _float;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _dots.value = 1;
    } else if (_dots.value == 0 && !_dots.isAnimating) {
      _dots.forward();
    }
    if (AppMotion.loopsOn(context) && _float == null) {
      _float = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3200))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _dots.dispose();
    _float?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: c.lip, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.restDreamingOf(widget.hero).toUpperCase(),
              style: theme.textTheme.labelSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.muted, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(widget.spot,
              style: theme.textTheme.titleMedium!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.text)),
          Text(l10n.restTodaysWeakSpot,
              style: theme.textTheme.labelMedium!
                  .withWeight(FontWeight.w800)
                  .copyWith(color: c.navy)),
        ],
      ),
    );
    Widget dot(int i, double size) => AnimatedBuilder(
          animation: _dots,
          builder: (context, child) => Opacity(
              opacity: ((_dots.value * 3) - (2 - i)).clamp(0.0, 1.0),
              child: child),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
          ),
        );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        // The dots run from the head up to the bubble: the nearest first.
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 92, top: 4),
          child: dot(0, 12),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 104, top: 3),
          child: dot(1, 8),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 112, top: 3),
          child: dot(2, 5),
        ),
      ],
    );
    final f = _float;
    return Semantics(
      container: true,
      label: '${l10n.restDreamingOf(widget.hero)} ${widget.spot}, '
          '${l10n.restTodaysWeakSpot}',
      excludeSemantics: true,
      child: f == null
          ? content
          : AnimatedBuilder(
              animation: f,
              builder: (context, child) => Transform.translate(
                  offset: Offset(0, -4 + 4 * math.cos(2 * math.pi * f.value)),
                  child: child),
              child: content,
            ),
    );
  }
}

/// V24f's sheet: the "All done for today" header with two done ticks and
/// the countdown to the next free Daily Test, then the Premium card: navy
/// to plum, a thin gold border and a slow glint; "PREMIUM" and "Not
/// sleepy yet?", "Keep practising today", five mini tickets (one used,
/// four locked, popping in 60 ms apart), the free and Premium allowances,
/// today's weak spot, and "Wake <Hero> up". The card slides up 300 ms after
/// the scene; it glows while the companion wakes (V24s).
class _FreePanel extends StatelessWidget {
  final RestOffer offer;
  final Avatar hero;
  final String testLine;
  final String countdown;
  final String countdownSemantics;
  final bool awake;
  final VoidCallback onWake;

  const _FreePanel({
    required this.offer,
    required this.hero,
    required this.testLine,
    required this.countdown,
    required this.countdownSemantics,
    required this.awake,
    required this.onWake,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reduced = AppMotion.reduced(context);
    const onPanel = Colors.white;
    final muted = onPanel.withValues(alpha: .72);
    Widget tick(String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: c.green, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 12, color: onPanel),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium!
                    .withWeight(FontWeight.w800)
                    .copyWith(color: muted)),
          ),
        ]);
    final spot = offer.weakSpot;
    final days = offer.trialDays;
    final card = AnimatedContainer(
      key: RestScene.premiumCardKey,
      duration: AppMotion.orInstant(context, AppMotion.base),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.navy, AppColors.premiumPlum],
        ),
        border: Border.all(color: c.gold.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
              color: c.gold.withValues(alpha: awake ? .55 : 0),
              blurRadius: 18,
              spreadRadius: 4),
        ],
      ),
      child: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: CardGlint())),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: c.gold, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome_rounded, size: 12, color: c.onOrange),
                  const SizedBox(width: 4),
                  Text(l10n.featurePremium.toUpperCase(),
                      style: theme.textTheme.labelSmall!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.onOrange, letterSpacing: .8)),
                ]),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(l10n.restNotSleepy,
                    style: theme.textTheme.labelLarge!
                        .withWeight(FontWeight.w800)
                        .copyWith(color: muted)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(l10n.restKeepPractising,
                style: theme.textTheme.titleLarge!
                    .withWeight(FontWeight.w900)
                    .copyWith(color: onPanel)),
            const SizedBox(height: 10),
            Semantics(
              label: l10n.restFreeVsPremium(
                  StorageService.freeDailyPracticeLimit,
                  StorageService.dailySessionLimit),
              excludeSemantics: true,
              child: Row(children: [
                for (var i = 0; i < StorageService.dailySessionLimit; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      key: RestScene.ticketKey(i),
                      tween: Tween(begin: reduced ? 1 : 0, end: 1),
                      duration: reduced
                          ? Duration.zero
                          : AppMotion.base + AppMotion.stagger * (i + 5),
                      curve: Interval(
                          (AppMotion.stagger * (i + 5)).inMilliseconds /
                              (AppMotion.base + AppMotion.stagger * (i + 5))
                                  .inMilliseconds,
                          1,
                          curve: AppMotion.pop),
                      builder: (context, t, child) =>
                          Transform.scale(scale: t, child: child),
                      child: i < StorageService.freeDailyPracticeLimit
                          ? _MiniTicket.used(l10n.restTicketUsedStub)
                          : const _MiniTicket.locked(),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            Text(
                l10n.restFreeVsPremium(StorageService.freeDailyPracticeLimit,
                    StorageService.dailySessionLimit),
                style: theme.textTheme.labelMedium!.copyWith(color: muted)),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: spot == null
                    ? [TextSpan(text: l10n.restPickAnyTopic(offer.topics))]
                    : emphasizedSpans(l10n.restPractiseSpot(spot),
                        emphasized: [spot], style: TextStyle(color: c.gold)),
              ),
              style: theme.textTheme.bodyMedium!
                  .withWeight(FontWeight.w800)
                  .copyWith(color: onPanel),
            ),
            const SizedBox(height: 12),
            // While the companion wakes the button stays orange (V24s) but
            // takes no second tap.
            IgnorePointer(
              ignoring: awake,
              child: PressableButton(
                key: RestScene.wakeKey,
                label: days == null
                    ? l10n.restWakeUp(hero.name(l10n))
                    : l10n.restWakeUpTrial(hero.name(l10n), days),
                tone: ButtonTone.orange,
                trailingIcon: Icons.arrow_forward_rounded,
                shine: true,
                haptic: ButtonHaptic.medium,
                onPressed: onWake,
              ),
            ),
          ],
        ),
      ]),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.nightTop, c.nightBottom],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(Icons.nightlight_round, color: c.gold, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.restTitle,
                      style: theme.textTheme.titleLarge!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: onPanel)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 12, runSpacing: 4, children: [
                    tick(testLine),
                    tick(l10n.restFreeTicketUsed),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: countdownSemantics,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    countdown,
                    textScaler: TextScaler.noScaling,
                    style: theme.textTheme.headlineSmall!
                        .withWeight(FontWeight.w900)
                        .copyWith(
                            color: onPanel,
                            fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  Text(l10n.restNextFreeTest,
                      style: theme.textTheme.labelSmall!
                          .withWeight(FontWeight.w700)
                          .copyWith(color: muted)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // The card slides up 300 ms after the scene.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduced ? 1 : 0, end: 1),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 300) + AppMotion.slow,
            curve: const Interval(.43, 1, curve: Curves.easeOutCubic),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                  offset: Offset(0, 24 * (1 - t)), child: child),
            ),
            child: card,
          ),
        ],
      ),
    );
  }
}

/// One of V24f's five mini tickets: the used one (dashed, grey, "USED") or
/// a locked one (orange, a lock).
class _MiniTicket extends StatelessWidget {
  final String? usedLabel;
  const _MiniTicket.used(String label) : usedLabel = label;
  const _MiniTicket.locked() : usedLabel = null;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final used = usedLabel != null;
    return SizedBox(
      height: 34,
      child: used
          ? CustomPaint(
              painter:
                  _DashedBorder(color: Colors.white.withValues(alpha: .45)),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(usedLabel!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall!
                            .withWeight(FontWeight.w900)
                            .copyWith(
                                color: Colors.white.withValues(alpha: .6),
                                letterSpacing: .6)),
                  ),
                ),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: c.orange,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(color: c.orangeDeep, offset: const Offset(0, 3))
                ],
              ),
              child: Icon(Icons.lock_rounded, size: 15, color: c.onOrange),
            ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  _DashedBorder({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(9)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
