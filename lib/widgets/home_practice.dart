import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../data/topics.dart';
import '../l10n/l10n.dart';
import '../models/topic.dart';
import '../motion.dart';
import '../theme.dart';
import 'pressable_button.dart';
import 'step_bar.dart';
import '../utils/upper_case.dart';

/// A topic's tile colours (V14, H04, R01), by topic.
(Color, Color) topicTileColors(AppColors c, TopicId id) => switch (id) {
      TopicId.gerundVsInfinitive => (c.cream, c.orangeDeep),
      TopicId.modalVerbs => (c.sky, c.onSky),
      TopicId.modalPastForms => (c.greenSoft, c.onGreenSoft),
      TopicId.tenseSelection => (c.lilac, c.onLilac),
      TopicId.articles => (c.goldSoft, c.goldText),
      TopicId.conditionals => (c.sky, c.onSky),
      TopicId.passiveVoice => (c.lilac, c.onLilac),
      TopicId.prepositions => (c.greenSoft, c.onGreenSoft),
      TopicId.relativeClauses => (c.cream, c.orangeDeep),
      TopicId.comparativesSuperlatives => (c.goldSoft, c.goldText),
    };

/// The free user's topic showcase on Home (V14): "Topic practice" with the
/// Premium chip, the user's weak spot topic as a navy "Picked for you"
/// card, the other topics as locked tiles that float, and "Unlock all N
/// topics". Every tap opens the paywall.
class TopicShowcase extends StatelessWidget {
  /// The topic of the user's weak spot today, or null.
  final Topic? picked;
  final VoidCallback onOpenPaywall;

  const TopicShowcase({super.key, this.picked, required this.onOpenPaywall});

  static const unlockKey = ValueKey('home_unlock_topics');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Every topic Topic Practice offers, the first-wave ones included
    // (the row scrolls sideways).
    final topics = practiceTopics();
    final picked = this.picked ?? topics.first;
    final others = [
      for (final t in topics)
        if (t.id != picked.id) t
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: lipCard(c, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(l10n.homeTopicPractice,
                  style: theme.textTheme.titleLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text)),
            ),
            const PremiumChip(),
          ]),
          const SizedBox(height: 6),
          Text(l10n.homeShowcaseLead,
              style: theme.textTheme.bodyMedium!.copyWith(color: c.muted)),
          const SizedBox(height: 14),
          PressableCard(
            onTap: onOpenPaywall,
            semanticLabel:
                '${l10n.homePickedForYou}. ${picked.title(l10n)}. ${l10n.homePickedLine}',
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: lipCard(c,
                  color: c.navy, border: c.navy, lip: c.navyDeep, radius: 22),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(picked.icon, color: c.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(upperCaseFor(context, l10n.homePickedForYou),
                          style: theme.textTheme.labelSmall!
                              .withWeight(FontWeight.w900)
                              .copyWith(color: c.gold, letterSpacing: 1.1)),
                      Text(picked.title(l10n),
                          style: theme.textTheme.titleMedium!
                              .withWeight(FontWeight.w900)
                              .copyWith(color: c.onNavy)),
                      Text(l10n.homePickedLine,
                          style: theme.textTheme.labelMedium!
                              .copyWith(color: c.onNavyMuted)),
                    ],
                  ),
                ),
                Icon(Icons.lock_outline_rounded, color: c.onNavyMuted),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            // 96 pt at the default text size; grows with it.
            height: MediaQuery.textScalerOf(context).scale(96),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: others.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => FloatingTile(
                index: i,
                child: TopicTile(
                  topic: others[i],
                  locked: true,
                  width: 116,
                  onTap: onOpenPaywall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          PressableButton(
            key: unlockKey,
            label: l10n.homeUnlockTopics(practiceTopics().length),
            tone: ButtonTone.orange,
            trailingIcon: Directionality.of(context) == TextDirection.rtl
                ? Icons.arrow_back_rounded
                : Icons.arrow_forward_rounded,
            onPressed: onOpenPaywall,
          ),
        ],
      ),
    );
  }
}

/// The Premium user's practice card on Home (H04): "Sessions today N/5" as
/// segments, the topics as unlocked tiles, "Practice your weak spot".
class PracticeCard extends StatelessWidget {
  final int sessionsToday;
  final int sessionLimit;
  final ValueChanged<Topic> onOpenTopic;
  final VoidCallback onPracticeWeakSpot;

  const PracticeCard({
    super.key,
    required this.sessionsToday,
    required this.sessionLimit,
    required this.onOpenTopic,
    required this.onPracticeWeakSpot,
  });

  static const weakSpotKey = ValueKey('home_practice_weak_spot');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final shown = practiceTopics().take(4).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: lipCard(c, radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(l10n.homePracticeTitle,
                  style: theme.textTheme.titleLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text)),
            ),
            const PremiumChip(check: true),
          ]),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.homeSessionsSemantics(sessionsToday, sessionLimit),
            excludeSemantics: true,
            child: Row(children: [
              Flexible(
                child: Text(l10n.homeSessionsToday,
                    maxLines: 2,
                    style: theme.textTheme.labelLarge!
                        .withWeight(FontWeight.w800)
                        .copyWith(color: c.muted)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StepBar(
                  segments: [
                    for (var i = 0; i < sessionLimit; i++)
                      i < sessionsToday ? c.navyText : null,
                  ],
                  track: c.track,
                  height: 9,
                  gap: 6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                  '${math.min(sessionsToday, sessionLimit)}/$sessionLimit', // l10n-guard: a count
                  style: theme.textTheme.labelLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.navyText)),
            ]),
          ),
          const SizedBox(height: 14),
          // Two tiles a row, each row as tall as its taller tile (the text
          // size decides, not a fixed ratio).
          for (var r = 0; r < shown.length; r += 2) ...[
            if (r > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = r; i < r + 2; i++) ...[
                    if (i > r) const SizedBox(width: 10),
                    Expanded(
                      child: i < shown.length
                          ? FloatingTile(
                              index: i,
                              child: TopicTile(
                                  topic: shown[i],
                                  locked: false,
                                  onTap: () => onOpenTopic(shown[i])),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          PressableButton(
            key: weakSpotKey,
            label: l10n.homePracticeWeakSpot,
            tone: ButtonTone.navy,
            trailingIcon: Directionality.of(context) == TextDirection.rtl
                ? Icons.arrow_back_rounded
                : Icons.arrow_forward_rounded,
            onPressed: onPracticeWeakSpot,
          ),
        ],
      ),
    );
  }
}

/// The gold "Premium" chip (V14, H04).
class PremiumChip extends StatelessWidget {
  final bool check;
  const PremiumChip({super.key, this.check = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.gold,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(check ? Icons.check_rounded : Icons.auto_awesome_outlined,
            size: 14, color: c.onOrange),
        const SizedBox(width: 5),
        Text(
          check
              ? context.l10n.featurePremium
              : upperCaseIn('en', context.l10n.featurePremium),
          style: Theme.of(context)
              .textTheme
              .labelMedium!
              .withWeight(FontWeight.w900)
              .copyWith(color: c.onOrange, letterSpacing: check ? 0 : 1),
        ),
      ]),
    );
  }
}

/// A topic tile in its colour, with a lock when it is not open.
class TopicTile extends StatelessWidget {
  final Topic topic;
  final bool locked;
  final double? width;
  final VoidCallback onTap;

  const TopicTile({
    super.key,
    required this.topic,
    required this.locked,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (bg, fg) = topicTileColors(c, topic.id);
    return PressableCard(
      onTap: onTap,
      semanticLabel: topic.title(context.l10n),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(topic.icon, color: fg, size: 20),
              const Spacer(),
              if (locked) Icon(Icons.lock_outline_rounded, color: fg, size: 16),
            ]),
            const SizedBox(height: 8),
            const Spacer(),
            Text(
              topic.title(context.l10n),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .withWeight(FontWeight.w800)
                  .copyWith(color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floats its child up and down (3.4 s, staggered by [index]) as an ambient
/// loop.
class FloatingTile extends StatefulWidget {
  final int index;
  final Widget child;
  const FloatingTile({super.key, required this.index, required this.child});

  @override
  State<FloatingTile> createState() => _FloatingTileState();
}

class _FloatingTileState extends State<FloatingTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _loop == null) {
      _loop = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3400))
        ..value = (widget.index * .23) % 1.0
        ..repeat();
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loop = _loop;
    if (loop == null) return widget.child;
    return AnimatedBuilder(
      animation: loop,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -3 * (1 - math.cos(2 * math.pi * loop.value)) / 2),
        child: child,
      ),
      child: widget.child,
    );
  }
}
