import 'package:flutter/material.dart';

import '../models/avatar.dart';

/// Shared avatar rendering — an emoji on a fixed, avatar-specific
/// background color, or a generic person icon when none has been picked
/// yet. Used by both Settings' avatar picker and Home's personalized
/// greeting so the two can't visually drift apart (PRD v2 §11).
class AvatarCircle extends StatelessWidget {
  final Avatar? avatar;
  final double radius;
  final bool selected;

  const AvatarCircle({
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

    final circle = CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: chosen == null
          ? Icon(
              Icons.person_rounded,
              size: radius,
              color: colorScheme.onSurfaceVariant,
            )
          : Text(chosen.emoji, style: TextStyle(fontSize: radius * 1.1)),
    );

    if (!selected) return circle;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colorScheme.secondary, width: 2.5),
      ),
      child: circle,
    );
  }
}
