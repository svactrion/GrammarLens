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

  // Enlarged again, now that the colored selection ring is gone
  // (docs/design-audit.md's avatar section) — the ring used to be a
  // second, tighter constraint alongside neighbor-peek visibility ("ring
  // strictly narrower than its own page"), and that's what actually
  // capped the previous radius (64) well below what peek visibility alone
  // allowed, though the reasoning written down at the time didn't
  // separate the two clearly.
  //
  // Measured directly against the real widget tree (not hand-derived),
  // sweeping radius from 56 to 88 at viewportFraction 0.4/0.45/0.5/0.55,
  // at both 320pt and 375pt: the neighbor's own visible fraction turns
  // out to depend on `viewportFraction` alone, not on `radius` at all —
  // exactly 50% at vf 0.5, regardless of radius, at either width. So
  // `viewportFraction` stays exactly 0.5, unchanged: it's still the
  // largest value satisfying "at least half visible" (above 0.5 the
  // fraction drops below half; below 0.5 it's comfortably more than
  // half). The actual remaining limit on `_centerRadius` is the settled
  // tile's own diameter fitting inside its own page slot
  // (`viewportFraction * screenWidth`) at the narrowest supported width
  // (320pt, iPhone SE) — `2 * radius <= 0.5 * 320` gives radius <= 80.
  // 80 is exactly that boundary: the tile fills its own page slot at
  // 320pt with no overflow, and has slack to spare at 375pt.
  static const double _centerRadius = 80;
  static const double _viewportFraction = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // BrandScaffold's own responsive horizontal padding formula
    // (`body:` bypasses it — see that widget's doc comment — so this
    // screen owns its own padding, matching that default rather than
    // inventing a different one).
    final hPad = (width * 0.045).clamp(16.0, 28.0);

    return BrandScaffold(
      title: const PageTitle('Choose your avatar'),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // No card/box around this — it's a single line of text
                  // with nothing to group visually or tap as a unit, so
                  // giving it a container would be exactly the "readability
                  // only" wrap docs/design-audit.md already argues against
                  // (Settings' Profile/Data section, 2026-09-10). Solved
                  // with typography alone: a title-weight role straight off
                  // the theme, not a new style or a new color value.
                  Text(
                    'Pick your study buddy',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 32),
                  AvatarCarousel(
                    initialAvatar: widget.currentAvatar,
                    onSettled: _onSettled,
                    centerRadius: _centerRadius,
                    viewportFraction: _viewportFraction,
                    centerTileBuilder: (avatar, tile) =>
                        Hero(tag: avatarHeroTag, child: tile),
                  ),
                ],
              ),
            ),
          ),
          // The only way to leave used to be the app bar's back chevron —
          // no completion affordance at all. Deliberately just a pop, not
          // a second write: the carousel's own autosave (on settle,
          // debounced) already persisted whatever's selected by the time
          // this is tapped, or AvatarPickerScreen's own dispose() flushes
          // it if the debounce hadn't fired yet (see that method) — the
          // exact same path the back button already goes through. So back
          // and Done are already equivalent by construction; this button
          // adds a second obvious way to trigger the same pop, not a
          // second way to save.
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
