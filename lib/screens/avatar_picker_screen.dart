import 'dart:async';

import 'package:flutter/material.dart';

import '../models/avatar.dart';
import '../utils/page_title.dart';
import '../widgets/avatar_carousel.dart';
import '../widgets/brand_scaffold.dart';

/// Shared between this screen's centered avatar and Settings' own small
/// preview row (`settings_screen.dart`) — the only two places this tag is
/// ever used, so a `Hero` flight only ever has exactly one matching pair
/// at a time.
const String avatarHeroTag = 'profile-avatar';

/// Settings' own avatar-picking screen — pushed from its preview row,
/// wrapping [AvatarCarousel] with autosave and the `Hero` flight back to
/// that row. No "Save" button of its own: every settle silently persists
/// via [onAvatarChanged], debounced so a fast multi-swipe writes once
/// after the user actually stops, not on every settle along the way.
class AvatarPickerScreen extends StatefulWidget {
  final Avatar currentAvatar;
  final ValueChanged<Avatar> onAvatarChanged;

  const AvatarPickerScreen({
    super.key,
    required this.currentAvatar,
    required this.onAvatarChanged,
  });

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  static const _debounceDelay = Duration(milliseconds: 500);

  Timer? _debounce;
  Avatar? _pendingAvatar;

  void _onSettled(Avatar avatar) {
    _pendingAvatar = avatar;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      _pendingAvatar = null;
      widget.onAvatarChanged(avatar);
    });
  }

  @override
  void dispose() {
    // Leaving mid-debounce (a swipe followed immediately by tapping back)
    // shouldn't lose the change just because the window hadn't elapsed —
    // flush it now instead of letting the about-to-be-cancelled timer
    // simply never fire.
    final pending = _pendingAvatar;
    if (pending != null) widget.onAvatarChanged(pending);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BrandScaffold(
      title: const PageTitle('Choose your avatar'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Swipe to choose your avatar',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            AvatarCarousel(
              initialAvatar: widget.currentAvatar,
              onSettled: _onSettled,
              centerTileBuilder: (avatar, tile) =>
                  Hero(tag: avatarHeroTag, child: tile),
            ),
          ],
        ),
      ),
    );
  }
}
