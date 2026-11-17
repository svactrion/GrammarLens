import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/topic_hints.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/topic.dart';
import '../motion.dart';
import '../theme.dart';
import 'companion_view.dart';
import 'skeleton.dart';

/// V18: practice questions being prepared. The companion thinks, three
/// question card skeletons shimmer, and the topic's hint cards rotate under
/// "Did you know?" (one every 3 s; the first one only when loops are off).
class PracticePreparing extends StatefulWidget {
  final Topic topic;
  final Avatar? hero;
  final String message;

  const PracticePreparing({
    super.key,
    required this.topic,
    required this.message,
    this.hero,
  });

  static const hintKey = ValueKey('practice_preparing_hint');

  /// How long each hint card stays.
  static const hintPeriod = Duration(seconds: 3);

  @override
  State<PracticePreparing> createState() => _PracticePreparingState();
}

class _PracticePreparingState extends State<PracticePreparing>
    with SingleTickerProviderStateMixin {
  AnimationController? _hints;

  List<String> get _lines => kTopicHints[widget.topic.id] ?? const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hints == null && AppMotion.loopsOn(context) && _lines.length > 1) {
      _hints = AnimationController(
          vsync: this, duration: PracticePreparing.hintPeriod * _lines.length)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _hints?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget skeletonCard() => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: lipCard(c, radius: 18),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBar(widthFactor: .35, height: 10),
              SizedBox(height: 10),
              SkeletonBar(height: 14),
              SizedBox(height: 6),
              SkeletonBar(widthFactor: .7, height: 14),
            ],
          ),
        );
    return Semantics(
      liveRegion: true,
      label: widget.message,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CompanionView(
                  hero: widget.hero ?? Avatar.fox,
                  mood: CompanionMood.think,
                  size: 104,
                  decorative: true),
            ),
            const SizedBox(height: 10),
            ExcludeSemantics(
              child: Text(widget.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium!
                      .withWeight(FontWeight.w800)
                      .copyWith(color: c.text)),
            ),
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Column(children: [
                skeletonCard(),
                skeletonCard(),
                skeletonCard(),
              ]),
            ),
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: lipCard(c,
                    color: c.goldSoft, border: c.gold, lip: c.goldDeep),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.practiceDidYouKnow.toUpperCase(),
                        style: theme.textTheme.labelSmall!
                            .withWeight(FontWeight.w900)
                            .copyWith(color: c.goldDeep, letterSpacing: 1.1)),
                    const SizedBox(height: 6),
                    _hints == null
                        ? _hint(context, 0)
                        : AnimatedBuilder(
                            animation: _hints!,
                            builder: (context, _) {
                              final i = math.min(
                                  (_hints!.value * _lines.length).floor(),
                                  _lines.length - 1);
                              return AnimatedSwitcher(
                                duration: AppMotion.base,
                                transitionBuilder: (child, a) =>
                                    SlideTransition(
                                  position: Tween(
                                          begin: const Offset(.15, 0),
                                          end: Offset.zero)
                                      .animate(a),
                                  child:
                                      FadeTransition(opacity: a, child: child),
                                ),
                                child: _hint(context, i),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, int i) => Text(
        _lines[i],
        key: ValueKey(i),
        style: Theme.of(context)
            .textTheme
            .bodyLarge!
            .withWeight(FontWeight.w700)
            .copyWith(color: AppColors.of(context).text),
      );
}
