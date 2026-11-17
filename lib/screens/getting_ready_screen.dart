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

  /// The pause at 100 % before the next screen.
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
                        CompanionView(
                          hero: widget.hero,
                          mood: atTop
                              ? CompanionMood.cheer
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
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ReadyBar(value: _model.value, reached: reached, done: atTop),
                  const SizedBox(height: 18),
                  for (final (i, (icon, label)) in rows.indexed)
                    _ReadyRow(icon: icon, label: label, done: i < reached),
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

/// The thick striped orange bar with its three stops and the summit flag.
class _ReadyBar extends StatelessWidget {
  final double value;
  final int reached;
  final bool done;
  const _ReadyBar(
      {required this.value, required this.reached, required this.done});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 58,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth - 12;
        final rtl = Directionality.of(context) == TextDirection.rtl;
        double x(double v) => rtl ? box.maxWidth - 12 - w * v : w * v;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 12,
              top: 26,
              height: 26,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CustomPaint(
                  painter: _StripedBar(
                    value: value,
                    fill: c.orange,
                    stripe: c.orangeDeep.withValues(alpha: .35),
                    track: c.track,
                    rtl: rtl,
                  ),
                ),
              ),
            ),
            // The summit flag at the end.
            Positioned(
              left: rtl ? -4 : null,
              right: rtl ? null : -4,
              top: -6,
              width: 40,
              height: 34,
              child: Image.asset('assets/ui/summit_flag_pennant_v2.webp',
                  fit: BoxFit.contain, excludeFromSemantics: true),
            ),
            for (var i = 0; i < GettingReadyModel.stops.length; i++)
              Positioned(
                left: x(GettingReadyModel.stops[i]) - 13,
                top: 26,
                width: 26,
                height: 26,
                child: _Stop(done: i < reached),
              ),
            if (done && !AppMotion.reduced(context))
              ConfettiBurst(
                origin: Offset(x(1), 30),
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
  final Color track;
  final bool rtl;

  _StripedBar({
    required this.value,
    required this.fill,
    required this.stripe,
    required this.track,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    final w = size.width * value;
    final rect = rtl
        ? Rect.fromLTWH(size.width - w, 0, w, size.height)
        : Rect.fromLTWH(0, 0, w, size.height);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..color = fill);
    final p = Paint()..color = stripe;
    for (var x = -size.height; x < size.width; x += 22) {
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + 11, size.height)
          ..lineTo(x + 11 + size.height, 0)
          ..lineTo(x + size.height, 0)
          ..close(),
        p,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripedBar old) => old.value != value;
}

class _Stop extends StatelessWidget {
  final bool done;
  const _Stop({required this.done});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedScale(
      scale: done ? 1 : .9,
      duration: AppMotion.orInstant(context, AppMotion.base),
      curve: AppMotion.pop,
      child: Container(
        decoration: BoxDecoration(
          color: done ? c.green : c.card,
          shape: BoxShape.circle,
          border: Border.all(color: done ? c.card : c.orange, width: 3),
        ),
        child:
            done ? Icon(Icons.check_rounded, size: 14, color: c.onNavy) : null,
      ),
    );
  }
}

class _ReadyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  const _ReadyRow(
      {required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: done ? 1 : .55,
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
                  color: done ? c.green : c.track,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    done ? Icons.check_rounded : Icons.more_horiz_rounded,
                    size: 18,
                    color: done ? c.onNavy : c.muted),
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
          Icons.work_outline_rounded,
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
