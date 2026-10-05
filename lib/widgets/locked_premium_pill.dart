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
///
/// 1.2.0 look (the brief's PREMIUM tag): no fill and no outline — the lock,
/// the label in 11/800 and the chevron, all in linkAndActive (≥ 9.2:1 on
/// the card in both themes). The label's text is unchanged.
class LockedPremiumPill extends StatelessWidget {
  const LockedPremiumPill({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = theme.colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 12, color: link),
          const SizedBox(width: 4),
          Text(
            'Premium',
            style: theme.textTheme.labelSmall?.copyWith(
              color: link,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 14, color: link),
        ],
      ),
    );
  }
}
