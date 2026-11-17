import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/learning_goal.dart';
import '../motion.dart';
import '../services/getting_ready.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../widgets/companion_view.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/error_state.dart';
import '../widgets/learning_goal_icon.dart';
import '../widgets/rays.dart';
import '../widgets/speech_bubble.dart';

/// Onboarding's "Getting ready" step (V05b, SPEC §1.6): a real 0 → 100 %
/// bar over the three tasks [tasks] (save the name and buddy, get today's
/// Daily Test, open this month's mountain), run one after another. See
/// [GettingReadyModel] for the bar's rules. At 100 % the companion cheers,
/// confetti bursts from the flag, and [onDone] follows 600 ms later. Past
/// 8 s, or when a task fails, the R11 pattern with "Try again" runs the
/// remaining tasks again.
class GettingReadyScreen extends StatefulWidget {
  final String name;
  final Avatar hero;
  final LearningGoal? goal;

  /// The month's name and its mountain (for the third row and the "Your
  /// climb" card), and the mountain's steps.
  final String monthName;
  final String mountainName;
  final int steps;
  final int questionsPerDay;

  /// The three tasks, in order. Each completes when its work is done.
  final List<Future<void> Function()> tasks;
  final VoidCallback onDone;

  const GettingReadyScreen({
    super.key,
    required this.name,
    required this.hero,
    required this.goal,
    required this.monthName,
    required this.mountainName,
    required this.steps,
    required this.questionsPerDay,
    required this.tasks,
    required this.onDone,
  });

  /// The celebration at 100 % before the next screen (SPEC §1.16: 0.6 s).
  static const Duration doneHold = Duration(milliseconds: 600);

  @override
  State<GettingReadyScreen> createState() => _GettingReadyScreenState();
}

class _GettingReadyScreenState extends State<GettingReadyScreen>
    with SingleTickerProviderStateMixin {
  final _model = GettingReadyModel();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  bool _running = false;
  bool _failed = false;
  bool _finished = false;
  int _reported = 0;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    unawaited(_run());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hold?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    try {
      while (_model.done < widget.tasks.length) {
        await widget.tasks[_model.done]();
        if (!mounted) return;
        _model.taskDone();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _running = false;
    }
  }

  void _onTick(Duration now) {
    final dt = now - _last;
    _last = now;
    if (_failed) return;
    _model.advance(dt);
    final reached = _model.stopsReached;
    while (_reported < reached) {
      _reported++;
      if (_reported == GettingReadyModel.stops.length) {
        HapticMap.success();
      } else {
        HapticMap.light();
      }
    }
    if (_model.timedOut) {
      setState(() => _failed = true);
      return;
    }
    if (_model.complete && !_finished) {
      _finished = true;
      _hold = Timer(GettingReadyScreen.doneHold, widget.onDone);
    }
    setState(() {});
  }

  Future<bool> _retry() async {
    _model.retry();
    setState(() => _failed = false);
    await _run();
    return !_failed;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (_failed) {
      return Scaffold(
        backgroundColor: c.page,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ErrorState(hero: widget.hero, onRetry: _retry),
            ),
          ),
        ),
      );
    }
    final percent = (_model.value * 100).round();
    final reached = _model.stopsReached;
    final atTop = _model.complete;
    final rows = [
      (Icons.person_outline_rounded, l10n.readyRowSaved),
      (Icons.calendar_today_outlined, l10n.readyRowTest),
      (Icons.track_changes_rounded, l10n.readyRowMountain(widget.monthName)),
    ];
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.orangeSoft, c.page],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxHeight < 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: compact ? 190 : 250,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        const _Clouds(),
                        Rays(color: c.card, size: compact ? 260 : 320),
                        // The board's soft disc behind the companion.
                        Container(
                          width: compact ? 124 : 160,
                          height: compact ? 124 : 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.card.withValues(alpha: .55),
                          ),
                        ),
                        // The board's four sparkles, placed from the
                        // companion's centre.
                        for (final (dx, dy, size, ms, delay) in const [
                          (-94.0, -60.0, 30.0, 1800, 0),
                          (100.0, -16.0, 26.0, 2200, 600),
                          (-84.0, 76.0, 22.0, 2000, 1100),
                          (115.0, -95.0, 20.0, 1600, 300),
                        ])
                          Transform.translate(
                            offset: Offset(dx, dy) * (compact ? 140 / 180 : 1),
                            child: _Sparkle(
                                size: size * (compact ? 140 / 180 : 1),
                                period: Duration(milliseconds: ms),
                                delay: Duration(milliseconds: delay)),
                          ),
                        CompanionView(
                          hero: widget.hero,
                          // A slow task: the bar waits at its stop with
                          // the companion thinking (SPEC §1.16).
                          mood: atTop
                              ? CompanionMood.cheer
                              : _model.waiting
                                  ? CompanionMood.think
                                  : CompanionMood.inspect,
                          size: compact ? 140 : 180,
                        ),
                        PositionedDirectional(
                          top: 6,
                          end: 0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: SpeechBubble(
                              text: widget.goal?.readyLine(l10n) ??
                                  l10n.readyBubbleNone,
                              pointer: BubblePointer.bottomStart,
                              compact: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.readyTitle(widget.name),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.text, letterSpacing: -.6),
                  ),
                  const SizedBox(height: 6),
                  Semantics(
                    liveRegion: true,
                    label: l10n.readyPercentSemantics(percent),
                    excludeSemantics: true,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$percent'), // l10n-guard: a number
                        TextSpan(
                            text: '%', // l10n-guard: the percent sign
                            style: TextStyle(fontSize: 30, color: c.navy)),
                      ]),
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: theme.textTheme.displayMedium!
                          .withWeight(FontWeight.w900)
                          .copyWith(
                        color: c.navy,
                        fontSize: 60,
                        height: 1.05,
                        letterSpacing: -2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ReadyBar(value: _model.value, reached: reached, done: atTop),
                  const SizedBox(height: 18),
                  for (final (i, (icon, label)) in rows.indexed)
                    _ReadyRow(
                        icon: icon,
                        label: label,
                        done: i < reached,
                        active: i == reached),
                  const SizedBox(height: 14),
                  _YourClimb(
                    name: widget.name,
                    hero: widget.hero,
                    goal: widget.goal,
                    mountain: widget.mountainName,
                    steps: widget.steps,
                    perDay: widget.questionsPerDay,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// The thick striped orange bar with its three stops and the summit flag
/// (V05b, matched to the board in fix round 3, B2): a 26 pt warm track
/// with an inset top shadow; the orange fill with light diagonal stripes
/// that travel and a gloss line on top; 28 pt stop circles (white with an
/// orange ring, then green with a white tick); the last stop 16 pt from the
/// end, the flag's pole standing on it with its pennant waving; a gold glow
/// when the bar is full.
class _ReadyBar extends StatefulWidget {
  final double value;
  final int reached;
  final bool done;
  const _ReadyBar(
      {required this.value, required this.reached, required this.done});

  static const barTop = 44.0;
  static const barHeight = 26.0;
  static const stopSize = 28.0;
  static const endInset = 16.0;
  static const height = 74.0;
  static const fillKey = ValueKey('ready_bar_fill');
  static const poleKey = ValueKey('ready_bar_pole');
  static const pennantKey = ValueKey('ready_bar_pennant');
  static ValueKey<String> stopKey(int i) => ValueKey('ready_bar_stop_$i');

  @override
  State<_ReadyBar> createState() => _ReadyBarState();
}

class _ReadyBarState extends State<_ReadyBar> with TickerProviderStateMixin {
  /// The stripes travel one period in 800 ms; the pennant waves in 1.6 s.
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context)) {
      if (!_loop.isAnimating) _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: _ReadyBar.height,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        // A stop's centre: its share of the track, the last one held 16 pt
        // inside the end (the board).
        double x(double v) {
          final along = math.min(w * v, w - _ReadyBar.endInset);
          return rtl ? w - along : along;
        }

        final end = x(1);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: _ReadyBar.barTop,
              height: _ReadyBar.barHeight,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.done ? 1 : 0),
                duration: AppMotion.orInstant(
                    context, const Duration(milliseconds: 900)),
                builder: (context, glow, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                          color: c.gold.withValues(
                              alpha: .55 * math.sin(math.pi * glow)),
                          spreadRadius: 8 * math.sin(math.pi * glow)),
                    ],
                  ),
                  child: child,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: AnimatedBuilder(
                    animation: _loop,
                    builder: (context, _) => CustomPaint(
                      key: _ReadyBar.fillKey,
                      painter: _StripedBar(
                        value: widget.value,
                        fill: c.orange,
                        stripe: Colors.white.withValues(alpha: .28),
                        gloss: Colors.white.withValues(alpha: .35),
                        track: c.warmTrack,
                        inset: c.orangeDeep.withValues(alpha: .16),
                        shift: (_loop.value * 2) % 1,
                        rtl: rtl,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The flag's ground shadow, its pole on the last stop, and the
            // pennant at the pole's top.
            Positioned(
              left: end - 7,
              top: _ReadyBar.barTop - 2,
              width: 14,
              height: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x59281409),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            Positioned(
              key: _ReadyBar.poleKey,
              left: end - 5.5,
              top: 0,
              width: 11,
              height: _ReadyBar.barTop + 1,
              child: Image.asset('assets/ui/summit_flag_pole_v2.webp',
                  fit: BoxFit.contain, excludeFromSemantics: true),
            ),
            Positioned(
              key: _ReadyBar.pennantKey,
              left: rtl ? end - 27 : end,
              top: 2,
              width: 27,
              height: 18,
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, child) {
                  final t = math.sin(2 * math.pi * _loop.value) * .5 + .5;
                  return Transform(
                    alignment: rtl
                        ? AlignmentDirectional.centerEnd
                        : Alignment.centerLeft,
                    transform: Matrix4.identity()
                      ..setEntry(1, 0, math.tan(-5 * math.pi / 180 * t))
                      ..scaleByDouble(1 - .07 * t, 1, 1, 1),
                    child: child,
                  );
                },
                child: Transform.flip(
                  flipX: rtl,
                  child: Image.asset('assets/ui/summit_flag_pennant_v2.webp',
                      fit: BoxFit.contain, excludeFromSemantics: true),
                ),
              ),
            ),
            for (var i = 0; i < GettingReadyModel.stops.length; i++)
              Positioned(
                key: _ReadyBar.stopKey(i),
                left: x(GettingReadyModel.stops[i]) - _ReadyBar.stopSize / 2,
                top: _ReadyBar.barTop - 1,
                width: _ReadyBar.stopSize,
                height: _ReadyBar.stopSize,
                child: _Stop(done: i < widget.reached),
              ),
            if (widget.done && !AppMotion.reduced(context))
              ConfettiBurst(
                origin: Offset(end, _ReadyBar.barTop + 6),
                colors: [c.orange, c.navy, c.gold, c.green],
                count: 6,
                length: const Duration(milliseconds: 1200),
              ),
          ],
        );
      }),
    );
  }
}

class _StripedBar extends CustomPainter {
  final double value;
  final Color fill;
  final Color stripe;
  final Color gloss;
  final Color track;
  final Color inset;

  /// The stripes' travel, 0–1 of one period.
  final double shift;
  final bool rtl;

  _StripedBar({
    required this.value,
    required this.fill,
    required this.stripe,
    required this.gloss,
    required this.track,
    required this.inset,
    required this.shift,
    required this.rtl,
  });

  /// One light stripe and one gap, across the bar (the board's 10 + 10 px
  /// at −45°).
  static const period = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    // The track's inset shadow along its top.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 3), Paint()..color = inset);
    final w = size.width * value;
    if (w <= 0) return;
    final rect = rtl
        ? Rect.fromLTWH(size.width - w, 0, w, size.height)
        : Rect.fromLTWH(0, 0, w, size.height);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(13)));
    canvas.drawRect(rect, Paint()..color = fill);
    final p = Paint()..color = stripe;
    final h = size.height;
    final offset = (rtl ? -1 : 1) * shift * period;
    for (var x = -h - period + offset; x < size.width + period; x += period) {
      canvas.drawPath(
        Path()
          ..moveTo(x, h)
          ..lineTo(x + period / 2, h)
          ..lineTo(x + period / 2 + h, 0)
          ..lineTo(x + h, 0)
          ..close(),
        p,
      );
    }
    // The gloss line along the fill's top.
    if (rect.width > 12) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.left + 6, 4, rect.width - 12, 6),
              const Radius.circular(3)),
          Paint()..color = gloss);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripedBar old) =>
      old.value != value || old.shift != shift || old.track != track;
}

class _Stop extends StatelessWidget {
  final bool done;
  const _Stop({required this.done});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // The board: a white circle with an orange ring; when its work is done
    // it pops (0.4 → 1.25 → 1) into a green one with a white ring and tick.
    return AnimatedSwitcher(
      duration: AppMotion.orInstant(context, AppMotion.base),
      transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween(begin: .4, end: 1.0)
              .chain(CurveTween(curve: AppMotion.pop))
              .animate(animation),
          child: child),
      child: Container(
        key: ValueKey(done),
        decoration: BoxDecoration(
          color: done ? c.green : c.card,
          shape: BoxShape.circle,
          border: Border.all(color: done ? c.onNavy : c.orange, width: 3),
        ),
        child:
            done ? Icon(Icons.check_rounded, size: 16, color: c.onNavy) : null,
      ),
    );
  }
}

/// V05b's four sparkles around the companion (the board's prop_sparkle):
/// each pops, turns and fades on its own rhythm; still with the loops off.
class _Sparkle extends StatefulWidget {
  final double size;
  final Duration period;
  final Duration delay;
  const _Sparkle(
      {required this.size, required this.period, required this.delay});

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context)) {
      if (!_c.isAnimating && _start == null) {
        _start = Timer(widget.delay, () {
          if (mounted) _c.repeat();
        });
      }
    } else {
      _start?.cancel();
      _start = null;
      _c.stop();
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset('assets/companions/props/prop_sparkle.webp',
        width: widget.size, height: widget.size, excludeFromSemantics: true);
    if (!AppMotion.loopsOn(context)) return image;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // gl-sparkle: 0 → 1.1 (30 %) → 0.9 (60 %), turning 40°, gone at 80 %.
        final scale = t < .3
            ? 1.1 * t / .3
            : t < .6
                ? 1.1 - .2 * (t - .3) / .3
                : .9;
        final opacity = t < .3
            ? t / .3
            : t < .6
                ? 1.0
                : t < .8
                    ? 1 - (t - .6) / .2
                    : 0.0;
        return Opacity(
          opacity: opacity.clamp(0, 1).toDouble(),
          child: Transform.rotate(
            angle: 40 * math.pi / 180 * math.min(1, t / .6),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: image,
    );
  }
}

class _ReadyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;

  /// The row whose work is running now (the board: full colour, pulsing
  /// dots); rows not started yet are faint.
  final bool active;
  const _ReadyRow(
      {required this.icon,
      required this.label,
      required this.done,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: done || active ? 1 : .35,
      duration: AppMotion.orInstant(context, AppMotion.base),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: AppMotion.orInstant(context, AppMotion.base),
              transitionBuilder: (child, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: AppMotion.pop),
                  child: child),
              child: Container(
                key: ValueKey(done),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: done ? c.green : c.navy.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: done
                    ? Icon(Icons.check_rounded, size: 18, color: c.onNavy)
                    : _Dots(color: c.navy, running: active),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: c.navy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall!
                    .withWeight(FontWeight.w800)
                    .copyWith(color: c.text, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three 4 pt dots; while [running] they pulse one after another (the
/// board's gl-dots, 1.2 s, 0.2 s apart); still with the loops off.
class _Dots extends StatefulWidget {
  final Color color;
  final bool running;
  const _Dots({required this.color, required this.running});

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  void _sync() {
    if (widget.running && AppMotion.loopsOn(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Dots old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(
                    alpha: !_c.isAnimating
                        ? 1
                        : () {
                            final t = (_c.value - i * .2 / 1.2) % 1;
                            return t < .4
                                ? .2 + .8 * t / .4
                                : t < .8
                                    ? 1 - .8 * (t - .4) / .4
                                    : .2;
                          }()),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Your climb": the choices so far as chips (name, buddy, goal, this
/// month's mountain and its steps, the daily questions).
class _YourClimb extends StatelessWidget {
  final String name;
  final Avatar hero;
  final LearningGoal? goal;
  final String mountain;
  final int steps;
  final int perDay;

  const _YourClimb({
    required this.name,
    required this.hero,
    required this.goal,
    required this.mountain,
    required this.steps,
    required this.perDay,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chips = [
      (Icons.edit_outlined, name, c.sky, c.onSky),
      (Icons.auto_awesome_outlined, hero.name(l10n), c.cream, c.orangeDeep),
      if (goal != null)
        (
          learningGoalIcon(goal!),
          switch (goal!) {
            LearningGoal.examPrep => l10n.readyGoalExam,
            LearningGoal.work => l10n.readyGoalWork,
            LearningGoal.school => l10n.readyGoalSchool,
            LearningGoal.general => l10n.readyGoalGeneral,
          },
          c.sky,
          c.onSky
        ),
      (
        Icons.track_changes_rounded,
        l10n.readyMountainChip(mountain, steps),
        c.cream,
        c.orangeDeep
      ),
      (
        Icons.calendar_today_outlined,
        l10n.readyPerDayChip(perDay),
        c.greenSoft,
        c.onGreenSoft
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: lipCard(c, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.readyYourClimb,
              style: theme.textTheme.labelMedium!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.muted, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, (icon, text, bg, fg)) in chips.indexed)
                _ChipIn(
                  delay: Duration(milliseconds: 120 * i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 15, color: fg),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge!
                                .withWeight(FontWeight.w800)
                                .copyWith(color: fg)),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A chip that enters after [delay] (120 ms apart).
class _ChipIn extends StatelessWidget {
  final Duration delay;
  final Widget child;
  const _ChipIn({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    final total = delay + AppMotion.base;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1,
          curve: AppMotion.pop),
      builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: .8 + .2 * t, child: child)),
      child: child,
    );
  }
}

/// Two soft clouds drifting behind the companion.
class _Clouds extends StatefulWidget {
  const _Clouds();

  @override
  State<_Clouds> createState() => _CloudsState();
}

class _CloudsState extends State<_Clouds> with SingleTickerProviderStateMixin {
  AnimationController? _drift;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _drift == null) {
      _drift =
          AnimationController(vsync: this, duration: const Duration(seconds: 8))
            ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget cloud(double w) => Container(
          width: w,
          height: w * .38,
          decoration: BoxDecoration(
            color: c.card.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(w),
          ),
        );
    Widget build(double t) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: -40 + 16 * t, top: 10, child: cloud(120)),
            Positioned(right: -30 - 16 * t, top: 70, child: cloud(110)),
            Positioned(
                left: 10 + 10 * math.sin(t * math.pi),
                bottom: 30,
                child: cloud(80)),
          ],
        );
    final d = _drift;
    return Positioned.fill(
      child: IgnorePointer(
        child: d == null
            ? build(0)
            : AnimatedBuilder(
                animation: d, builder: (context, _) => build(d.value)),
      ),
    );
  }
}
