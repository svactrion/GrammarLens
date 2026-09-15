import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/avatar.dart';
import '../theme.dart';
import 'avatar_tile.dart';

/// The avatar-picking carousel — this batch's replacement for the old
/// tap-a-grid-tile picker, whose "selected" state changed a tile's own
/// layout footprint and broke the grid every time the last tile in a row
/// was tapped (see `avatar_tile.dart`'s doc comment for the full story).
/// Drag until the avatar you want is centered; there is no separate
/// "confirm" affordance — whichever avatar is centered once the page
/// settles *is* the selection, reported via [onSettled].
///
/// Used inline by both `OnboardingScreen` (embedded above the name field)
/// and `AvatarPickerScreen` (Settings' own pushed screen) — one widget, so
/// the swipe/settle/haptic/ring behavior can't drift between the two.
///
/// Selection is drawn as a single ring layer *behind* the `PageView`,
/// recolored (never resized) as the settled avatar changes — the one
/// place this carousel changes appearance based on selection, and it
/// never touches any page's own layout size. That's the actual fix this
/// batch is about: selection state changes what's painted inside a slot
/// that was already reserved for it, never the slot's own footprint.
class AvatarCarousel extends StatefulWidget {
  /// The avatar centered when this widget first mounts — never null
  /// (PRD v2 §11's "no empty state" rule now extends here too): a caller
  /// with no current avatar picks a random one before constructing this,
  /// rather than this widget inventing its own empty state.
  final Avatar initialAvatar;

  /// Called every time the *settled* (not mid-drag) centered avatar
  /// changes. Never called for [initialAvatar] itself on mount — only for
  /// an actual change the user made by dragging.
  final ValueChanged<Avatar> onSettled;

  /// Optional hook wrapping only the settled page's own tile — this is
  /// how `AvatarPickerScreen` wraps it in a `Hero` for the flight back to
  /// Settings' preview row, without this widget needing to know Hero
  /// exists at all. Null (the default, used by `OnboardingScreen`, which
  /// has no push/pop boundary for a Hero to animate across) renders the
  /// tile as-is.
  final Widget Function(Avatar avatar, Widget tile)? centerTileBuilder;

  /// The center avatar's own tile radius. Defaults to the one size this
  /// carousel has ever shipped with — `OnboardingScreen`'s embedded use
  /// doesn't override this, so it's completely unaffected by
  /// `AvatarPickerScreen` (Settings' full-screen picker) passing a larger
  /// value for its own, roomier layout.
  final double centerRadius;

  /// [PageController.viewportFraction] — tuned together with
  /// [centerRadius], never independently: a bigger avatar needs a wider
  /// page slot to keep neighbors peeking in from the edges rather than
  /// crowding them out. Same default-preserves-onboarding reasoning as
  /// [centerRadius].
  final double viewportFraction;

  const AvatarCarousel({
    super.key,
    required this.initialAvatar,
    required this.onSettled,
    this.centerTileBuilder,
    this.centerRadius = 56,
    this.viewportFraction = 0.45,
  });

  @override
  State<AvatarCarousel> createState() => _AvatarCarouselState();
}

class _AvatarCarouselState extends State<AvatarCarousel>
    with SingleTickerProviderStateMixin {
  // Neighbors are scaled down from widget.centerRadius via Transform.scale
  // in the item builder below, never by asking AvatarTile for a smaller
  // radius — a paint-time transform doesn't clip a page to its own layout
  // bounds by default, which is exactly what lets a scaled-down neighbor
  // spill past its slot's edge into view.
  static const double _neighborScale = 0.8;
  static const double _neighborOpacity = 0.5;
  static const double _ringPadding = 14;
  static const Duration _ringDuration = Duration(milliseconds: 250);
  static const Duration _popDuration = Duration(milliseconds: 180);

  late final PageController _pageController;
  late int _settledIndex;
  late final AnimationController _popController;
  late final Animation<double> _popAnimation;

  @override
  void initState() {
    super.initState();
    _settledIndex = widget.initialAvatar.index - 1;
    _pageController = PageController(
      viewportFraction: widget.viewportFraction,
      initialPage: _settledIndex,
    );
    _popController = AnimationController(vsync: this, duration: _popDuration);
    _popAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 1),
    ]).animate(_popController);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _popController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollEndNotification) return false;
    final page = _pageController.page;
    if (page == null) return false;
    final settled = page.round().clamp(0, Avatar.count - 1);
    if (settled == _settledIndex) return false;

    setState(() => _settledIndex = settled);
    HapticFeedback.selectionClick();
    _popController.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _popDuration;
    _popController.forward(from: 0);
    widget.onSettled(Avatar.values[settled]);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final ringColor = avatarRingColor(Avatar.values[_settledIndex]);
    final ringDiameter = widget.centerRadius * 2 + _ringPadding * 2;

    return SizedBox(
      width: double.infinity,
      height: ringDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            // Findable by test: avatar_carousel_test.dart asserts this
            // box's own size never changes across a settle that recolors
            // it — the actual regression test for the bug this batch
            // fixes (a selection change must only ever repaint a slot
            // already sized for it, never resize it).
            key: const Key('avatarSelectionRing'),
            duration: reduceMotion ? Duration.zero : _ringDuration,
            width: ringDiameter,
            height: ringDiameter,
            decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
          ),
          NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: PageView.builder(
              controller: _pageController,
              itemCount: Avatar.count,
              itemBuilder: (context, index) => _CarouselPage(
                avatar: Avatar.values[index],
                pageController: _pageController,
                popAnimation: _popAnimation,
                index: index,
                settledIndex: _settledIndex,
                radius: widget.centerRadius,
                neighborScale: _neighborScale,
                neighborOpacity: _neighborOpacity,
                centerTileBuilder: widget.centerTileBuilder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One carousel page — its scale/opacity track [pageController]'s
/// fractional position continuously (so dragging feels smooth, not a
/// binary snap), and only the page that's *both* the current build's
/// [settledIndex] *and* being rebuilt while [popAnimation] is running
/// gets the extra momentary pop on top of that. Split out from the
/// builder above only so [Listenable.merge] has one clear place to
/// rebuild from — [pageController] (continuous drag) and [popAnimation]
/// (the brief post-settle bump) are two independent listenables, and this
/// widget needs both.
class _CarouselPage extends StatelessWidget {
  final Avatar avatar;
  final PageController pageController;
  final Animation<double> popAnimation;
  final int index;
  final int settledIndex;
  final double radius;
  final double neighborScale;
  final double neighborOpacity;
  final Widget Function(Avatar avatar, Widget tile)? centerTileBuilder;

  const _CarouselPage({
    required this.avatar,
    required this.pageController,
    required this.popAnimation,
    required this.index,
    required this.settledIndex,
    required this.radius,
    required this.neighborScale,
    required this.neighborOpacity,
    this.centerTileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pageController, popAnimation]),
      builder: (context, _) {
        final page = pageController.hasClients
            ? (pageController.page ?? settledIndex.toDouble())
            : settledIndex.toDouble();
        final distance = (page - index).abs().clamp(0.0, 1.0);
        final scale = 1.0 - distance * (1 - neighborScale);
        final opacity = 1.0 - distance * (1 - neighborOpacity);
        final isSettled = index == settledIndex;
        final pop = isSettled ? popAnimation.value : 1.0;
        Widget tile = AvatarTile(avatar: avatar, radius: radius);
        if (isSettled && centerTileBuilder != null) {
          tile = centerTileBuilder!(avatar, tile);
        }

        return Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale * pop,
              child: Semantics(
                label: avatar.semanticLabel,
                container: true,
                child: tile,
              ),
            ),
          ),
        );
      },
    );
  }
}
