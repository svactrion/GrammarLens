import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/topic.dart';
import '../utils/text_format.dart';
import 'locked_premium_pill.dart';

/// A weak spot's card, shared by Home's "Your weak spots" section and
/// Review's list — previously two separate, drifted copies of the same
/// layout in home_screen.dart and review_screen.dart, which is how they
/// ended up with the same two bugs (docs/build-log.md):
///
/// 1. The topic label printed twice ("Gerund vs. Infinitive · Gerund vs.
///    Infinitive"). Root cause: both copies built the subtitle as
///    `'${topic.title} · ${humanizeSlug(spot.errorType)}'`, but for a
///    Daily Test-sourced weak spot, `spot.errorType` *is* `topic.id.name`
///    (Daily Test has no finer per-mistake classification the way Topic
///    Practice's LLM scoring does — see `ErrorSource`'s doc comment) —
///    and `humanizeSlug` is specifically built (its "vs" → "vs." rule) to
///    turn a topic-id slug back into the exact same string as
///    `topic.title`. So the two halves of that string were never two
///    independent facts for such a record — they were the same fact,
///    printed twice.
/// 2. The card's title was `spot.latestExplanation ?? humanizeSlug(spot.
///    errorType)`: a Topic Practice record (which has a real explanation)
///    showed a truncated mid-sentence fragment of the explanation as the
///    title, while a Daily Test record (no explanation — see
///    `ErrorSource`) showed the topic/error-type name only because that
///    branch happened to be the fallback, not by design.
///
/// Fixed by treating [spot.errorType] as always the most specific name
/// available — true by construction, not just for these two record
/// shapes: Topic Practice's errorType is a finer classification *under*
/// the topic, and Daily Test's errorType is the topic id itself, so
/// `humanizeSlug(spot.errorType)` is never less specific than
/// `topic.title` — and moving the explanation to its own line in the
/// body, never standing in for the title. The topic-name subtitle is
/// shown only when it says something the title doesn't already.
///
/// 1.2.0 look (the brief's weak spot tile, Review's list in the mockup): a
/// list card (radius 22, padding 17) with the topic, when shown, as a small
/// eyebrow in linkAndActive above the title; the title in 17/800 and free
/// to wrap rather than cut off; the explanation as a muted excerpt; and the
/// frequency stat on the info surface. Texts are unchanged.
///
/// [withAction] (Home since 1.2.0 Batch 5, the mockup's Home card): no
/// excerpt and no trailing chevron or tag; the frequency as a muted line,
/// then the card's action as its last line — "Practice with Premium" with
/// a lock when [locked], "Practice this" otherwise. The action is a label
/// of the card's one tap target ([onTap]), not a second button.
class WeakSpotCard extends StatelessWidget {
  final Topic topic;
  final WeakSpot spot;
  final bool locked;
  final VoidCallback onTap;
  final bool withAction;

  /// The brief's list card radius.
  static const _radius = 22.0;

  const WeakSpotCard({
    super.key,
    required this.topic,
    required this.spot,
    this.locked = false,
    required this.onTap,
    this.withAction = false,
  });

  @override
  Widget build(BuildContext context) {
    if (withAction) return _buildWithAction(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;

    final title = humanizeSlug(spot.errorType);
    // Only adds information when it differs from the title — for a Daily
    // Test-sourced weak spot (errorType == topic id) it's identical and
    // would just repeat it (see this class's doc comment).
    final topicSubtitle = topic.title != title ? topic.title : null;
    final explanation = spot.latestExplanation;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topicSubtitle != null) ...[
                      Text(
                        topicSubtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                    ],
                    Text(title, style: theme.textTheme.titleMedium),
                    if (explanation != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        explanation,
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: muted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatFrequencyStat(spot.frequency, spot.lastSeen),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              locked
                  ? const LockedPremiumPill()
                  : Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWithAction(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final link = colorScheme.secondary;
    final title = humanizeSlug(spot.errorType);
    final topicSubtitle = topic.title != title ? topic.title : null;
    final action = locked ? 'Practice with Premium' : 'Practice this';

    return Semantics(
      container: true,
      button: true,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topicSubtitle != null) ...[
                  Text(
                    topicSubtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: link,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  formatFrequencyStat(spot.frequency, spot.lastSeen),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // The brief's link row: at least 44 pt tall.
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Row(
                    children: [
                      if (locked) ...[
                        Icon(Icons.lock_rounded, size: 15, color: link),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          action,
                          style:
                              theme.textTheme.labelLarge?.copyWith(color: link),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: link),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
