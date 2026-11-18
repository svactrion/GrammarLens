import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'centered_scroll.dart';
import 'companion_view.dart';
import '../utils/upper_case.dart';

/// V20: the wait between Submit and the results. The companion inspects
/// through its magnifier; a scan window with the clay lens sweeps over the
/// answer cards (3.2 s), the lens inside the window; a checklist; an
/// indeterminate bar runs under "Your feedback is on its way". v12: the
/// content is centred in the space under the header, and the checklist is
/// honest: the first two items tick 0.8 s apart (light haptic each), the
/// last ("Writing your feedback") stays in progress (a pulsing dot) until
/// the result arrives ([done]) and ticks with it.
class PracticeReviewing extends StatefulWidget {
  final Avatar? hero;
  final String topic;

  /// The answers being checked, as written.
  final List<String> answers;

  /// The result has arrived: the last item ticks (its haptic is the
  /// result's own success).
  final bool done;

  const PracticeReviewing({
    super.key,
    required this.topic,
    required this.answers,
    this.hero,
    this.done = false,
  });

  static const tick = Duration(milliseconds: 800);
  static const sweep = Duration(milliseconds: 3200);

  /// The checklist's items: 0–2 ticked, the last in progress until [done].
  static ValueKey<String> stepKey(int i) => ValueKey('reviewing_step_$i');
  static const tickedKey = ValueKey(true);
  static const waitingKey = ValueKey('reviewing_waiting');
  static const lensKey = ValueKey('reviewing_lens');
  static const windowKey = ValueKey('reviewing_window');

  /// The items that tick on their own timers (the last waits for [done]).
  static const timedSteps = 2;

  @override
  State<PracticeReviewing> createState() => _PracticeReviewingState();
}

class _PracticeReviewingState extends State<PracticeReviewing>
    with TickerProviderStateMixin {
  late final AnimationController _ticks = AnimationController(
      vsync: this,
      duration: PracticeReviewing.tick * PracticeReviewing.timedSteps)
    ..addListener(_onTick);
  AnimationController? _sweep;
  int _ticked = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ticks.isAnimating && _ticks.value == 0) {
      if (AppMotion.reduced(context)) {
        _ticks.value = 1;
      } else {
        _ticks.forward();
      }
    }
    if (_sweep == null && AppMotion.loopsOn(context)) {
      _sweep =
          AnimationController(vsync: this, duration: PracticeReviewing.sweep)
            ..repeat(reverse: true);
    }
  }

  void _onTick() {
    const steps = PracticeReviewing.timedSteps;
    final n = (_ticks.value * steps + 1e-9).floor().clamp(0, steps);
    if (n > _ticked) {
      setState(() => _ticked = n);
      if (!AppMotion.reduced(context)) HapticMap.light();
    }
  }

  @override
  void dispose() {
    _ticks.dispose();
    _sweep?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final answers = [
      for (final a in widget.answers)
        if (a.trim().isNotEmpty) a.trim(),
    ];
    final steps = [
      l10n.practiceReviewingRead,
      l10n.practiceReviewingRules,
      l10n.practiceReviewingWrite,
    ];
    Widget cards = Column(
      children: [
        for (final a in answers.take(4))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: lipCard(c, radius: 16),
            child: Text(a,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium!
                    .withWeight(FontWeight.w700)
                    .copyWith(color: c.text)),
          ),
      ],
    );
    final sweep = _sweep;
    if (sweep != null && answers.isNotEmpty) {
      cards = Stack(children: [
        cards,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: sweep,
              builder: (context, _) => LayoutBuilder(
                builder: (context, box) {
                  final t = Curves.easeInOut.transform(sweep.value);
                  final y =
                      (box.maxHeight - 56).clamp(0.0, double.infinity) * t;
                  return Stack(children: [
                    Positioned(
                      key: PracticeReviewing.windowKey,
                      left: 0,
                      right: 0,
                      top: y,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: c.orange, width: 2.5),
                          borderRadius: BorderRadius.circular(16),
                          color: c.orange.withValues(alpha: .08),
                        ),
                      ),
                    ),
                    // v12: the lens inside the window (it used to stand
                    // 14 pt above it, out of the card at the top).
                    PositionedDirectional(
                      key: PracticeReviewing.lensKey,
                      end: 8,
                      top: y + 6,
                      width: 44,
                      height: 44,
                      child: Image.asset('assets/ui/lens.webp',
                          fit: BoxFit.contain, excludeFromSemantics: true),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ),
      ]);
    }
    return Semantics(
      liveRegion: true,
      label: l10n.practiceReviewingTitle,
      child: CenteredScroll(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CompanionView(
                    hero: widget.hero ?? Avatar.fox,
                    mood: CompanionMood.inspect,
                    size: 96,
                    decorative: true),
              ),
              const SizedBox(height: 8),
              Text(l10n.practiceReviewingTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text)),
              Text(l10n.practiceReviewingCount(widget.topic, answers.length),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge!.copyWith(color: c.muted)),
              const SizedBox(height: 14),
              cards,
              const SizedBox(height: 10),
              for (final (i, step) in steps.indexed)
                Builder(builder: (context) {
                  final last = i == steps.length - 1;
                  final ticked = last ? widget.done : i < _ticked;
                  // The last item is in progress once the timed ones have
                  // ticked, until the result arrives.
                  final waiting = last &&
                      !widget.done &&
                      _ticked >= PracticeReviewing.timedSteps;
                  return Padding(
                    key: PracticeReviewing.stepKey(i),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox.square(
                        dimension: 22,
                        child: AnimatedSwitcher(
                          duration:
                              AppMotion.orInstant(context, AppMotion.fast),
                          transitionBuilder: (child, a) =>
                              ScaleTransition(scale: a, child: child),
                          child: ticked
                              ? Icon(Icons.check_circle_rounded,
                                  key: PracticeReviewing.tickedKey,
                                  color: c.green,
                                  size: 22)
                              : waiting
                                  ? _PulsingDot(
                                      key: PracticeReviewing.waitingKey,
                                      color: c.navyText)
                                  : Icon(Icons.radio_button_unchecked_rounded,
                                      key: const ValueKey(false),
                                      color: c.line,
                                      size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(step,
                            style: theme.textTheme.bodyMedium!
                                .withWeight(ticked || waiting
                                    ? FontWeight.w800
                                    : FontWeight.w600)
                                .copyWith(
                                    color:
                                        ticked || waiting ? c.text : c.muted)),
                      ),
                    ]),
                  );
                }),
              const SizedBox(height: 14),
              Text(upperCaseFor(context, l10n.practiceReviewingOnItsWay),
                  style: theme.textTheme.labelSmall!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.navyText, letterSpacing: 1.1)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  color: c.navyText,
                  backgroundColor: c.track,
                  // Reduce Motion: a still bar (no loop).
                  value: AppMotion.loopsOn(context) ? null : math.min(1, .6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// V20 v12: the item in progress, a dot that pulses (1.2 s; still under
/// Reduce Motion).
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({super.key, required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _t == null) {
      _t = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1200))
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
    Widget dot(double p) {
      final wave = (1 - math.cos(2 * math.pi * p)) / 2;
      return Center(
        child: Container(
          width: 10 + 4 * wave,
          height: 10 + 4 * wave,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: .55 + .45 * wave),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    final t = _t;
    return t == null
        ? dot(.5)
        : AnimatedBuilder(animation: t, builder: (context, _) => dot(t.value));
  }
}
