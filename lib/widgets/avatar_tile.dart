import 'package:flutter/material.dart';

import '../models/avatar.dart';

/// Shared avatar rendering — one of the bundled illustrations
/// (`assets/avatars/`), or a generic person icon when none has been picked
/// yet (or a stored id this build doesn't recognize — see
/// `Avatar.fromJson`). Used wherever an avatar is just displayed, not
/// picked from: Home's personalized greeting and Settings' own preview
/// row (`avatar_picker_screen.dart` owns the actual picking UI). A rounded
/// square rather than a circle — `radius` is kept as the sizing parameter
/// (half the tile's side length) so call sites didn't need to change when
/// this moved off `CircleAvatar`, long before illustrations replaced the
/// old emoji-on-flat-color rendering.
///
/// Deliberately has no notion of "selected" any more. It used to (a
/// `selected` flag drew an extra border+padding wrapper around the same
/// box), and that wrapper is exactly what caused a real bug: the wrapper
/// added to the tile's own footprint only while selected, so Settings'
/// avatar grid (a `Wrap`) recomputed its line breaks and visibly reflowed
/// everything below it the moment the last tile in a row was tapped. The
/// fix wasn't a smaller border — it's that a *display* widget has no
/// business owning selection chrome at all. The avatar carousel
/// (`avatar_carousel.dart`) is the only place selection is drawn now, as
/// its own ring layer behind the carousel's `PageView`, never as part of
/// this widget — so the geometry bug this class used to own has no
/// remaining surface here to reintroduce.
class AvatarTile extends StatelessWidget {
  final Avatar? avatar;
  final double radius;

  const AvatarTile({super.key, required this.avatar, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final side = radius * 2;
    // Proportional to size rather than a fixed value, so the "slightly
    // rounded" look holds whether this is Home's small greeting tile or a
    // larger one elsewhere later — a squircle-ish rounded square, not a
    // circle and not sharp corners.
    final cornerRadius = radius * 0.6;

    return SizedBox(
      width: side,
      height: side,
      child: avatar == null
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(cornerRadius),
              ),
              child: Center(
                child: Icon(
                  Icons.person_rounded,
                  size: radius,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : Image.asset(avatar!.assetPath, fit: BoxFit.contain),
    );
  }
}
