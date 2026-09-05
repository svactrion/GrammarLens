import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/topic.dart';
import '../utils/text_format.dart';

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
class WeakSpotCard extends StatelessWidget {
  final Topic topic;
  final WeakSpot spot;
  final bool locked;
  final VoidCallback onTap;

  const WeakSpotCard({
    super.key,
    required this.topic,
    required this.spot,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_rounded, size: 16, color: muted),
                        ],
                      ],
                    ),
                    if (topicSubtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        topicSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                    if (explanation != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        explanation,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatFrequencyStat(spot.frequency, spot.lastSeen),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
