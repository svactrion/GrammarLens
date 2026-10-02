import 'package:flutter/material.dart';

import '../models/medal_tier.dart';
import 'medal_tier_color.dart';

/// A monthly medal's look: the tier's metal colour as a ring and a tint
/// around the landscape mark, with a lock badge while not earned. Sized by
/// its parent (a square). Shared by Profile's collection and the month
/// transition card (Batch 6, M8), so the medal is drawn in one place and
/// Batch 5's themed medal changes both.
class MedalBadge extends StatelessWidget {
  final MedalTier tier;
  final bool earned;

  /// The landscape mark's size.
  final double iconSize;

  const MedalBadge({
    super.key,
    required this.tier,
    this.earned = true,
    this.iconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = earned ? tier.color : tier.color.withValues(alpha: 0.42);
    final fill = Color.alphaBlend(
      tint.withValues(alpha: earned ? 0.20 : 0.10),
      scheme.surfaceContainerHigh,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: tint, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.landscape_rounded, color: tint, size: iconSize),
          if (!earned)
            Align(
              alignment: const Alignment(0.72, 0.72),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
