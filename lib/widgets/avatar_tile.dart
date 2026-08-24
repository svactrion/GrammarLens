import 'package:flutter/material.dart';

import '../models/avatar.dart';

/// Shared avatar rendering — an emoji on a fixed, avatar-specific
/// background color, or a generic person icon when none has been picked
/// yet. Used by both Settings' avatar picker and Home's personalized
/// greeting so the two can't visually drift apart (PRD v2 §11). A rounded
/// square rather than a circle — `radius` is kept as the sizing parameter
/// (half the tile's side length) so call sites didn't need to change when
/// this moved off `CircleAvatar`.
class AvatarTile extends StatelessWidget {
  final Avatar? avatar;
  final double radius;
  final bool selected;

  const AvatarTile({
    super.key,
    required this.avatar,
    this.radius = 22,
    this.selected = false,
  });

  // Fixed, theme-independent palette — like a chat app's per-user color,
  // these are decorative identity colors rather than semantic UI colors, so
  // they deliberately don't come from ColorScheme and stay constant across
  // light/dark instead of being recomputed per theme.
  static const Map<Avatar, Color> _backgroundColors = {
    Avatar.fox: Color(0xFFFFB74D),
    Avatar.cat: Color(0xFFBA68C8),
    Avatar.owl: Color(0xFF8D6E63),
    Avatar.panda: Color(0xFF90A4AE),
    Avatar.koala: Color(0xFF78909C),
    Avatar.penguin: Color(0xFF4FC3F7),
    Avatar.lion: Color(0xFFFFA726),
    Avatar.turtle: Color(0xFF81C784),
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chosen = avatar;
    final background = chosen == null
        ? colorScheme.surfaceContainerHighest
        : _backgroundColors[chosen]!;
    final side = radius * 2;
    // Proportional to size rather than a fixed value, so the "slightly
    // rounded" look holds whether this is Home's small greeting tile or a
    // larger one elsewhere later — a squircle-ish rounded square, not a
    // circle and not sharp corners.
    final cornerRadius = radius * 0.6;

    final tile = Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: chosen == null
          ? Icon(
              Icons.person_rounded,
              size: radius,
              color: colorScheme.onSurfaceVariant,
            )
          : Text(chosen.emoji, style: TextStyle(fontSize: radius * 1.1)),
    );

    if (!selected) return tile;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius + 2.5),
        border: Border.all(color: colorScheme.secondary, width: 2.5),
      ),
      child: tile,
    );
  }
}
