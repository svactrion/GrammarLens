import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/error_entry.dart';
import '../models/review_sort_order.dart';
import '../models/topic.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/answer_diff.dart';
import '../utils/text_format.dart';
import 'app_sheet.dart';
import 'companion_view.dart';
import 'pressable_button.dart';

/// A mistake inline in one sentence (V16, R03): the learner's wrong words
/// struck through in red, the right ones in green, the rest plain. Built
/// from the stored answer and correction ([diffAnswer]); when the two
/// cannot be lined up word by word, the answer struck through and then the
/// correction.
class InlineMistake extends StatelessWidget {
  final ErrorEntry entry;
  final TextStyle? style;
  const InlineMistake({super.key, required this.entry, this.style});

  /// The spans for [entry], or null when it has nothing to show.
  static List<(String, _Mark)>? parts(ErrorEntry entry) {
    final user = entry.userAnswer?.trim() ?? '';
    final fixed = entry.correctedAnswer?.trim() ?? '';
    if (fixed.isEmpty) return null;
    if (user.isEmpty) return [(fixed, _Mark.right)];
    final diff = diffAnswer(
        userAnswer: user, correctedAnswer: fixed, prompt: entry.prompt);
    if (!diff.highlighted) {
      return [(user, _Mark.wrong), (' ', _Mark.plain), (fixed, _Mark.right)];
    }
    final out = <(String, _Mark)>[];
    void add(String text, _Mark mark) {
      if (out.isNotEmpty) out.add((' ', _Mark.plain));
      out.add((text, mark));
    }

    var i = 0, j = 0;
    final u = diff.user, c = diff.corrected;
    while (i < u.length || j < c.length) {
      final uPlain = i < u.length && !u[i].painted;
      final cPlain = j < c.length && !c[j].painted;
      if (uPlain && cPlain) {
        add(c[j].text, _Mark.plain);
        i++;
        j++;
        continue;
      }
      var moved = false;
      while (i < u.length && u[i].painted) {
        add(u[i].core, _Mark.wrong);
        i++;
        moved = true;
      }
      while (j < c.length && c[j].painted) {
        add(c[j].text, _Mark.right);
        j++;
        moved = true;
      }
      if (!moved) {
        // One side has run out: the rest of the other, as it is.
        if (i < u.length) {
          add(u[i].text, _Mark.wrong);
          i++;
        } else if (j < c.length) {
          add(c[j].text, _Mark.plain);
          j++;
        }
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = style ??
        Theme.of(context)
            .textTheme
            .bodyLarge!
            .withWeight(FontWeight.w700)
            .copyWith(color: c.text);
    final spans = parts(entry);
    if (spans == null) return const SizedBox.shrink();
    return Text.rich(TextSpan(style: base, children: [
      for (final (text, mark) in spans)
        TextSpan(
          text: text,
          style: switch (mark) {
            _Mark.plain => null,
            _Mark.wrong => TextStyle(
                color: c.redText,
                decoration: TextDecoration.lineThrough,
                decorationColor: c.redText,
                decorationThickness: 2),
            _Mark.right => const TextStyle()
                .withWeight(FontWeight.w900)
                .copyWith(color: c.greenText, backgroundColor: c.greenSoft),
          },
          semanticsLabel: switch (mark) {
            _Mark.wrong => context.l10n.mistakeWrongSemantics(text),
            _Mark.right => context.l10n.mistakeRightSemantics(text),
            _Mark.plain => null,
          },
        ),
    ]));
  }
}

enum _Mark { plain, wrong, right }

/// A weak spot on Review (V16, V22, R12): the topic and a "new" chip, how
/// often and when, the weak spot's title, its latest mistake inline, and
/// an optional button ("Practice with my ticket"). The card presses 2 pt
/// on tap and opens the weak spot.
class ReviewSpotCard extends StatelessWidget {
  final Topic topic;
  final WeakSpot spot;
  final ErrorEntry? mistake;
  final VoidCallback onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final DateTime? now;

  const ReviewSpotCard({
    super.key,
    required this.topic,
    required this.spot,
    required this.onTap,
    this.mistake,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = weakSpotTitle(spot.errorType, topic, l10n);
    final meta = l10n.reviewSpotMeta(l10n.frequencyTimes(spot.frequency),
        formatRecency(spot.lastSeen, l10n, now: now));
    return PressableCard(
      onTap: onTap,
      haptic: ButtonHaptic.light,
      semanticLabel: '${topic.title(l10n)}. $title. $meta',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: lipCard(c, radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text(topic.title(l10n).toUpperCase(),
                    style: theme.textTheme.labelSmall!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.orangeText, letterSpacing: 1)),
              ),
              if (spot.frequency == 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.orangeSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(l10n.reviewSpotNew,
                      style: theme.textTheme.labelSmall!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.orangeText)),
                ),
            ]),
            const SizedBox(height: 6),
            Text(title,
                style: theme.textTheme.titleMedium!
                    .withWeight(FontWeight.w900)
                    .copyWith(color: c.text)),
            const SizedBox(height: 2),
            Text(meta,
                style: theme.textTheme.labelMedium!
                    .withWeight(FontWeight.w700)
                    .copyWith(color: c.muted)),
            if (mistake != null && InlineMistake.parts(mistake!) != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.page,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InlineMistake(
                  entry: mistake!,
                  style: theme.textTheme.bodyMedium!
                      .withWeight(FontWeight.w700)
                      .copyWith(color: c.text),
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              PressableButton(
                key: actionKey,
                label: actionLabel!,
                tone: ButtonTone.orange,
                height: 50,
                haptic: ButtonHaptic.medium,
                trailingIcon: Directionality.of(context) == TextDirection.rtl
                    ? Icons.arrow_back_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// RV06: the sort sheet. Two options with big targets; the selected one is
/// a navy card. Completes with the chosen order, or null.
Future<ReviewSortOrder?> showReviewSortSheet(
    BuildContext context, ReviewSortOrder current) {
  return showAppSheet<ReviewSortOrder>(
    context: context,
    builder: (context) {
      final c = AppColors.of(context);
      final l10n = context.l10n;
      final theme = Theme.of(context);
      Widget option(ReviewSortOrder order, String line) {
        final selected = order == current;
        return Semantics(
          inMutuallyExclusiveGroup: true,
          checked: selected,
          button: true,
          child: PressableCard(
            key: ValueKey('review_sort_${order.name}'),
            haptic: ButtonHaptic.selection,
            onTap: () => Navigator.of(context).pop(order),
            child: AnimatedContainer(
              duration: AppMotion.orInstant(context, AppMotion.fast),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: lipCard(c,
                  color: selected ? c.navy : c.card,
                  border: selected ? c.navy : c.line,
                  lip: selected ? c.navyDeep : c.lip,
                  radius: 20),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.label(l10n),
                          style: theme.textTheme.titleMedium!
                              .withWeight(FontWeight.w900)
                              .copyWith(color: selected ? c.onNavy : c.text)),
                      Text(line,
                          style: theme.textTheme.bodySmall!.copyWith(
                              color: selected ? c.onNavyMuted : c.muted)),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: c.gold, size: 26),
              ]),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.reviewSortTooltip,
                  style: theme.textTheme.titleLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text)),
            ),
            const SizedBox(height: 14),
            option(ReviewSortOrder.recent, l10n.reviewSortRecentLine),
            const SizedBox(height: 10),
            option(ReviewSortOrder.frequent, l10n.reviewSortFrequentLine),
          ],
        ),
      );
    },
  );
}

/// RV05: no weak spots yet, as a reward: the companion cheers (two hops,
/// then breathing), the text fades in after 150 ms, one way to the Daily
/// Test.
class ReviewEmpty extends StatefulWidget {
  final Avatar hero;
  final VoidCallback onGoToDailyTest;
  const ReviewEmpty(
      {super.key, required this.hero, required this.onGoToDailyTest});

  static const ctaKey = ValueKey('review_empty_cta');

  @override
  State<ReviewEmpty> createState() => _ReviewEmptyState();
}

class _ReviewEmptyState extends State<ReviewEmpty> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shown) return;
    if (AppMotion.reduced(context)) {
      _shown = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CompanionView(
              hero: widget.hero,
              mood: CompanionMood.cheer,
              size: 120,
              hopping: true),
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: AppMotion.orInstant(context, AppMotion.base),
          curve: const Interval(.4, 1),
          child: Column(children: [
            Semantics(
              header: true,
              child: Text(l10n.reviewEmptyTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text)),
            ),
            const SizedBox(height: 6),
            Text(l10n.reviewEmptyBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(color: c.muted)),
          ]),
        ),
        const SizedBox(height: 18),
        PressableButton(
          key: ReviewEmpty.ctaKey,
          label: l10n.reviewGoToDailyTest,
          tone: ButtonTone.navy,
          haptic: ButtonHaptic.light,
          trailingIcon: Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_back_rounded
              : Icons.arrow_forward_rounded,
          onPressed: widget.onGoToDailyTest,
        ),
      ],
    );
  }
}
