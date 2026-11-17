import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'companion_view.dart';

/// V20: the wait between Submit and the results. The companion inspects
/// through its magnifier; a scan window with the clay lens sweeps over the
/// answer cards (3.2 s); a checklist ticks 0.8 s apart (light haptic each);
/// an indeterminate bar runs under "Your feedback is on its way".
class PracticeReviewing extends StatefulWidget {
  final Avatar? hero;
  final String topic;

  /// The answers being checked, as written.
  final List<String> answers;

  const PracticeReviewing({
    super.key,
    required this.topic,
    required this.answers,
    this.hero,
  });

  static const tick = Duration(milliseconds: 800);
  static const sweep = Duration(milliseconds: 3200);

  @override
  State<PracticeReviewing> createState() => _PracticeReviewingState();
}

class _PracticeReviewingState extends State<PracticeReviewing>
    with TickerProviderStateMixin {
  late final AnimationController _ticks =
      AnimationController(vsync: this, duration: PracticeReviewing.tick * 3)
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
    final n = (_ticks.value * 3 + 1e-9).floor().clamp(0, 3);
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
                    Positioned(
                      right: 8,
                      top: y - 14,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        child: ExcludeSemantics(
          child: Column(
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    AnimatedSwitcher(
                      duration: AppMotion.orInstant(context, AppMotion.fast),
                      transitionBuilder: (child, a) =>
                          ScaleTransition(scale: a, child: child),
                      child: i < _ticked
                          ? Icon(Icons.check_circle_rounded,
                              key: const ValueKey(true),
                              color: c.green,
                              size: 22)
                          : Icon(Icons.radio_button_unchecked_rounded,
                              key: const ValueKey(false),
                              color: c.line,
                              size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(step,
                          style: theme.textTheme.bodyMedium!
                              .withWeight(i < _ticked
                                  ? FontWeight.w800
                                  : FontWeight.w600)
                              .copyWith(color: i < _ticked ? c.text : c.muted)),
                    ),
                  ]),
                ),
              const SizedBox(height: 14),
              Text(l10n.practiceReviewingOnItsWay.toUpperCase(),
                  style: theme.textTheme.labelSmall!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.navy, letterSpacing: 1.1)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  color: c.navy,
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
