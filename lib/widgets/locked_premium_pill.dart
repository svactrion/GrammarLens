import 'package:flutter/material.dart';

/// The trailing "this needs Premium" affordance on a locked card (Home's
/// Topic Practice card, a locked weak-spot row) — same slot both card types
/// already used for a plain forward chevron (docs/design-audit.md, Batch 0
/// item 3).
///
/// Replaces two things at once, not just adds a badge: the small lock glyph
/// that used to sit next to the title (too quiet to read as the real
/// signal — the audit's own complaint), and the plain chevron in the
/// trailing slot. That chevron mattered: today, tapping anywhere on a
/// locked card already opens `PremiumScreen` (the whole `Card` is one
/// `InkWell`), and the chevron was the only visible "this leads somewhere"
/// cue for that. Dropping it for a lock-only badge would have made a real
/// conversion path look inert. This pill carries both parts together — the
/// lock + "Premium" label saying what's locked, and a chevron built into
/// the pill itself (not a separate icon beside it) preserving the
/// tap-forward signal — so removing the old chevron doesn't remove what it
/// was for.
class LockedPremiumPill extends StatelessWidget {
  const LockedPremiumPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final muted = colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 12, color: muted),
          const SizedBox(width: 4),
          Text(
            'Premium',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 14, color: muted),
        ],
      ),
    );
  }
}
