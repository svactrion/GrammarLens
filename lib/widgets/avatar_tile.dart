import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../theme.dart';

/// Shared avatar rendering — one of the bundled illustrations
/// (`assets/avatars/`), or a generic person icon when none has been picked
/// yet (or a stored id this build doesn't recognize — see
/// `Avatar.fromJson`). Used wherever an avatar is just displayed, not
/// picked from: Home's personalized greeting and Settings' own preview
/// row (`avatar_picker_screen.dart` owns the actual picking UI), and every
/// page of `AvatarCarousel`'s `PageView`. A rounded square rather than a
/// circle — `radius` is kept as the sizing parameter (half the tile's side
/// length) so call sites didn't need to change when this moved off
/// `CircleAvatar`, long before illustrations replaced the old
/// emoji-on-flat-color rendering.
///
/// Deliberately has no notion of "selected" any more. It used to (a
/// `selected` flag drew an extra border+padding wrapper around the same
/// box), and that wrapper is exactly what caused a real bug: the wrapper
/// added to the tile's own footprint only while selected, so Settings'
/// avatar grid (a `Wrap`) recomputed its line breaks and visibly reflowed
/// everything below it the moment the last tile in a row was tapped. The
/// fix wasn't a smaller border — it's that a *display* widget has no
/// business owning selection chrome at all. `AvatarCarousel` used to draw
/// selection as a colored ring behind its `PageView`, which has since been
/// removed entirely (docs/design-audit.md's avatar section) in favor of
/// the center page's own scale/opacity — this widget was never involved in
/// that ring either way, so nothing here changed when it was.
///
/// Real avatars (not the placeholder) get a soft ground-shadow ellipse
/// painted behind the illustration — presence on a transparent background,
/// not a colored circle or a drop shadow hugging the silhouette. The
/// placeholder keeps its own filled box instead: it already reads as a
/// solid UI element (a bordered icon tile), not a floating illustration,
/// so grounding it the same way would be redundant, not consistent.
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
          : Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: radius * 0.12,
                  child: _AvatarGroundShadow(radius: radius),
                ),
                // Explicit width/height, not left to Stack's loose sizing
                // of a non-positioned child: without them, RenderImage
                // falls back to Size.zero for any frame before the asset
                // has actually decoded (loose constraints + no natural
                // size yet), which the tight SizedBox around a bare
                // Image.asset never exposed before this became a Stack.
                Image.asset(
                  avatar!.assetPath,
                  width: side,
                  height: side,
                  fit: BoxFit.contain,
                ),
              ],
            ),
    );
  }
}

/// The soft elliptical "grounding" mark under a real avatar — see
/// [avatarGroundShadowColor]/[avatarGroundShadowOpacity] in `theme.dart`
/// for why its color and opacity are theme-dependent, not one value
/// reused everywhere. Sized and blurred as a fraction of [radius], so it
/// scales with the tile it sits under (Home's 30, Settings' 26, the
/// carousel's 56/64) without a separate constant per call site.
///
/// Positioned at a fixed fraction of the tile's own height rather than
/// measured per illustration: the bundled avatars share a consistent
/// composition (a centered character with headroom above and below), so
/// one general-purpose placement reads correctly across the set without
/// pixel-tuning each of the twelve individually.
class _AvatarGroundShadow extends StatelessWidget {
  final double radius;

  const _AvatarGroundShadow({required this.radius});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final width = radius * 1.3;
    final height = radius * 0.32;

    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: radius * 0.16,
        sigmaY: radius * 0.16,
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: avatarGroundShadowColor(brightness)
              .withValues(alpha: avatarGroundShadowOpacity(brightness)),
          borderRadius:
              BorderRadius.all(Radius.elliptical(width / 2, height / 2)),
        ),
      ),
    );
  }
}
