import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/topic_hints.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/topic.dart';
import '../motion.dart';
import '../theme.dart';
import 'centered_scroll.dart';
import 'companion_view.dart';
import 'skeleton.dart';
import 'thinking_dots.dart';

/// V18: practice questions being prepared, the one loading screen of topic
/// and weak-spot practice (SPEC V18, v11). As on the board: the companion
/// thinks over three pulsing dots, the message names the count and the
/// topic ("Writing 3 questions on …"), two question card skeletons shimmer,
/// and the topic's hint cards rotate under "Did you know?" on a sky card
/// with a pager (one every 3 s; the first one only when loops are off).
/// The skeletons and the hint card are one width, the content's (fix round
/// 3, B7: on the device the skeletons were narrower, a yellow hint card and
/// the topic as a big page title).
class PracticePreparing extends StatefulWidget {
  final Topic topic;
  final Avatar? hero;

  /// The questions being written; null shows [message] instead of
  /// "Writing [questionCount] questions on [topic]…".
  final int? questionCount;
  final String message;

  const PracticePreparing({
    super.key,
    required this.topic,
    required this.message,
    this.questionCount,
    this.hero,
  });

  /// Hint [i]'s text (a new key per hint, so each change slides in).
  static ValueKey<String> hintKey(int i) =>
      ValueKey('practice_preparing_hint_$i');
  static const hintCardKey = ValueKey('practice_preparing_hint_card');
  static ValueKey<String> skeletonKey(int i) =>
      ValueKey('practice_preparing_skeleton_$i');

  /// The board's companion size.
  static const double companionSize = 130;

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
    final count = widget.questionCount;
    final message = count == null
        ? widget.message
        : l10n.practicePreparingTopic(count, widget.topic.title(l10n));
    // The board's bars: the card's line colour, shimmering lighter.
    Widget bar(double share) => SkeletonBar(
          widthFactor: share,
          height: 14,
          radius: 7,
          color: c.line.withValues(alpha: .6),
          highlight: c.line.withValues(alpha: .25),
        );
    Widget skeletonCard(int i) => Container(
          key: PracticePreparing.skeletonKey(i),
          padding: const EdgeInsets.all(18),
          decoration: lipCard(c, lipHeight: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(.4),
              const SizedBox(height: 10),
              bar(.9),
              const SizedBox(height: 10),
              bar(.7),
            ],
          ),
        );
    return Semantics(
      liveRegion: true,
      label: message,
      // v12: centred in the space under the header (V18, as V20).
      child: CenteredScroll(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CompanionView(
                  hero: widget.hero ?? Avatar.fox,
                  mood: CompanionMood.think,
                  size: PracticePreparing.companionSize,
                  decorative: true),
            ),
            const SizedBox(height: 8),
            Center(child: ThinkingDots(color: c.navyText)),
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text, height: 1.4)),
            ),
            const SizedBox(height: 16),
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  skeletonCard(0),
                  const SizedBox(height: 16),
                  skeletonCard(1),
                ],
              ),
            ),
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                key: PracticePreparing.hintCardKey,
                padding: const EdgeInsets.all(16),
                decoration: lipCard(c, color: c.sky, lipHeight: 4),
                child: _hints == null
                    ? _hintBody(context, 0)
                    : AnimatedBuilder(
                        animation: _hints!,
                        builder: (context, _) => _hintBody(
                            context,
                            math.min((_hints!.value * _lines.length).floor(),
                                _lines.length - 1)),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Did you know?", hint [i] (sliding in from the right when it
  /// changes) and the pager.
  Widget _hintBody(BuildContext context, int i) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.practiceDidYouKnow.toUpperCase(),
            style: theme.textTheme.labelSmall!
                .withWeight(FontWeight.w900)
                .copyWith(color: c.navyText, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: AppMotion.base,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.topStart,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, a) => SlideTransition(
            position:
                Tween(begin: const Offset(.15, 0), end: Offset.zero).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
          child: _hint(context, i),
        ),
        if (_lines.length > 1) ...[
          const SizedBox(height: 8),
          Row(children: [
            for (var k = 0; k < _lines.length; k++)
              AnimatedContainer(
                duration: AppMotion.base,
                margin: const EdgeInsetsDirectional.only(end: 5),
                width: k == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: k == i ? c.navyText : c.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ],
      ],
    );
  }

  Widget _hint(BuildContext context, int i) => Text(
        _lines[i],
        key: PracticePreparing.hintKey(i),
        style: Theme.of(context)
            .textTheme
            .bodyLarge!
            .withWeight(FontWeight.w600)
            .copyWith(color: AppColors.of(context).text, height: 1.4),
      );
}
