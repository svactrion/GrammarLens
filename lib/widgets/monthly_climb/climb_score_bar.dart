import 'package:flutter/material.dart';

import '../../models/medal_tier.dart';
import '../medal_tier_color.dart';
import '../../theme.dart';

/// The month's score against the medal thresholds: a strip of its own inside
/// the mountain card, under the mountain window (design decision D9), so it
/// hides no part of the trail. The trail counts days; this bar counts points,
/// which is what medals are based on.
///
/// Presentation only: the caller passes the score and the thresholds, read
/// from `MonthlyMedalRules`.
class ClimbScoreBar extends StatelessWidget {
  final int score;
  final int maxScore;
  final Map<MedalTier, int> thresholds;

  const ClimbScoreBar({
    super.key,
    required this.score,
    required this.maxScore,
    required this.thresholds,
  });

  static const _trackHeight = 6.0;
  static const _tickHeight = 12.0;

  MedalTier? get _reached {
    MedalTier? reached;
    for (final tier in MedalTier.values) {
      if (score >= thresholds[tier]!) reached = tier;
    }
    return reached;
  }

  /// Read aloud by VoiceOver: the bar has no numbers on screen, so this is
  /// the only way to hear the score.
  String get semanticsLabel {
    final marks = [
      for (final tier in MedalTier.values)
        '${tier.label} at ${thresholds[tier]}'
    ].join(', ');
    final reached = _reached;
    return 'Monthly score: $score of $maxScore points. $marks.'
        '${reached == null ? '' : ' ${reached.label} reached.'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fill = maxScore == 0 ? 0.0 : (score / maxScore).clamp(0.0, 1.0);
    final reached = _reached;
    return Semantics(
      label: semanticsLabel,
      container: true,
      excludeSemantics: true,
      child: ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            double at(MedalTier tier) =>
                width * (thresholds[tier]! / maxScore).clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: _tickHeight,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (_tickHeight - _trackHeight) / 2,
                      height: _trackHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_trackHeight / 2),
                        child: ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: fill,
                              heightFactor: 1,
                              child: ColoredBox(color: scheme.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final tier in MedalTier.values)
                      Positioned(
                        left: at(tier) - 1.5,
                        top: 0,
                        width: 3,
                        height: _tickHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tier.color,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: width,
                  // One line of labelSmall at any of the app's text sizes.
                  height: (theme.textTheme.labelSmall?.fontSize ?? 11) * 1.6,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (final tier in MedalTier.values)
                      Positioned(
                        left: at(tier) - 40,
                        width: 80,
                        top: 0,
                        child: Text(
                          tier.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          // The metal color stays on the tick: as small text
                          // it would be too faint (gold on a light surface).
                          style: theme.textTheme.labelSmall
                              ?.withWeight(reached == tier
                                  ? FontWeight.w800
                                  : FontWeight.w600)
                              .copyWith(
                                  color: reached != null &&
                                          tier.index <= reached.index
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant),
                        ),
                      ),
                  ]),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
