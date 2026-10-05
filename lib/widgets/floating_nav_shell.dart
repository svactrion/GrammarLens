import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../theme.dart';
import '../utils/content_width.dart';

/// How much bottom padding a scrollable tab screen needs to reserve so its
/// last item can be scrolled fully clear of [FloatingNavShell]'s bar,
/// rather than stopping stuck behind/under it.
///
/// Previously every tab screen (Home, Review, Settings) padded its own
/// scroll view by a fixed guessed constant (`navBarClearance = 110`,
/// `lib/utils/layout_constants.dart`, now removed) that didn't actually
/// match the bar's real rendered footprint — visual chrome height plus the
/// device's own bottom safe-area inset, which varies by device — closely
/// enough. On some devices the guess fell short and scrollable content
/// stayed clipped even at max scroll (docs/design-audit.md S4: Settings'
/// Save button and "Data" heading, Home's Premium row). Fixed by measuring
/// the bar's actual laid-out height every frame it could change (see
/// [FloatingNavShell]) instead of guessing it, and publishing that one
/// number down through this `InheritedWidget` — a single source every tab
/// screen reads, instead of N screen-specific guesses that could drift out
/// of sync with the bar or with each other.
class NavBarClearance extends InheritedWidget {
  const NavBarClearance({
    super.key,
    required this.value,
    required super.child,
  });

  final double value;

  /// Falls back to [fallback] only before the bar has ever been laid out
  /// (the very first frame) or when read outside a [FloatingNavShell] (a
  /// screen pumped in isolation under test, say) — real usage inside the
  /// app always has a [FloatingNavShell] ancestor by the second frame.
  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<NavBarClearance>()
            ?.value ??
        fallback;
  }

  /// The old hardcoded guess, kept only as that pre-measurement fallback —
  /// no longer trusted as the real answer anywhere.
  static const fallback = 110.0;

  @override
  bool updateShouldNotify(NavBarClearance oldWidget) =>
      value != oldWidget.value;
}

/// One bottom-nav tab's icon/label pair.
class NavShellTab {
  const NavShellTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The floating bottom nav bar as a
/// `Stack`, not `Scaffold.bottomNavigationBar` — that slot wraps its child
/// in an opaque `Material` spanning the full screen width regardless of
/// what's inside it, which painted a solid strip behind the pill's rounded
/// corners on every screen (see roadmap "Nav bar revision round 2"). A
/// `Stack` with the bar as a `Positioned` overlay has no such slot: nothing
/// paints outside the pill's own bounds, and [body] genuinely continues
/// underneath it, Instagram-style.
///
/// 1.2.0 (owner decision Q17): a solid bar — `AppPalette.navSurface`, a
/// 1 pt `navBorder` edge, the brief's nav shadow and radius 29 — replaces
/// the frosted glass (a translucent tint over a blur, from the roadmap's
/// "Home + nav bar revision round"s). Unselected items are textPrimary
/// (Q6), the selected item linkAndActive.
///
/// The shell is its own root [Scaffold], with `resizeToAvoidBottomInset`
/// off (1.2.0 Batch 8, owner: the bar rose with the keyboard while editing
/// the name on Profile). Before, app.dart's Scaffold around the shell
/// resized for the keyboard, shrinking this `Stack` by the keyboard's
/// height, and the bar, pinned to the Stack's bottom, rode up above the
/// keyboard. Now the Stack keeps the screen's height, so the bar stays where
/// it is and the keyboard covers it. The keyboard inset still reaches the
/// tab screens: their own Scaffolds (`BrandScaffold`) resize their content,
/// so a focused field and its buttons stay in view on every tab.
///
/// Also the single source of [NavBarClearance] (see its own doc comment):
/// measures the bar's real rendered height via a `GlobalKey` after every
/// frame that could change it (a font-scale change, say) instead of
/// guessing, and republishes it whenever it actually changes.
class FloatingNavShell extends StatefulWidget {
  const FloatingNavShell({
    super.key,
    required this.body,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChange,
  });

  /// The bar itself (its decorated box), for tests that measure it.
  static const barKey = ValueKey('floating_nav_bar');

  /// The app's tab screens (`TabSlideSwitcher`).
  final Widget body;
  final List<NavShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  @override
  State<FloatingNavShell> createState() => _FloatingNavShellState();
}

class _FloatingNavShellState extends State<FloatingNavShell> {
  /// The bar's corner radius (the brief: 29).
  static const _radius = 29.0;

  final _barKey = GlobalKey();
  double _clearance = NavBarClearance.fallback;

  void _measure() {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    // A little breathing room past the bar's own top edge — the point is
    // content can scroll clearly past the bar, not stop flush against it.
    final next = box.size.height + 16;
    if ((next - _clearance).abs() > 0.5) {
      setState(() => _clearance = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Runs after every build, not just the first — a font-scale or
    // safe-area change (rotation, a different device) can change the bar's
    // real height at any point, and this keeps `_clearance` honest instead
    // of only ever measuring once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);

    // P2: on an iPad the pill itself spans the content column; on an
    // iPhone it keeps its 16 pt from each edge.
    final side = 16 + ContentWidth.insetOf(context, edge: 16);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: NavBarClearance(
        value: _clearance,
        child: Stack(
          children: [
            widget.body,
            Positioned(
              left: side,
              right: side,
              bottom: 0,
              child: SafeArea(
                key: _barKey,
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    key: FloatingNavShell.barKey,
                    decoration: BoxDecoration(
                      color: palette.navSurface,
                      borderRadius: BorderRadius.circular(_radius),
                      border: Border.all(color: palette.navBorder),
                      boxShadow: palette.navShadow,
                    ),
                    child: _FloatingNavBar(
                      tabs: widget.tabs,
                      selectedIndex: widget.selectedIndex,
                      onTabChange: widget.onTabChange,
                      unselectedColor: colorScheme.onSurface,
                      activeColor: colorScheme.secondary,
                      labelStyle: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A plain custom row rather than a package widget (this replaced
// `google_nav_bar`'s `GNav`, see docs/roadmap.md "Nav bar revision round
// 3") gives full control over the active-tab treatment: icon swaps
// outline → filled and icon/label recolor to the accent — no background
// shape at all.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChange,
    required this.unselectedColor,
    required this.activeColor,
    required this.labelStyle,
  });

  final List<NavShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  final Color unselectedColor;
  final Color activeColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _NavTab(
              data: tabs[i],
              active: i == selectedIndex,
              unselectedColor: unselectedColor,
              activeColor: activeColor,
              labelStyle: labelStyle,
              onTap: () {
                if (i != selectedIndex) HapticFeedback.selectionClick();
                onTabChange(i);
              },
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.data,
    required this.active,
    required this.unselectedColor,
    required this.activeColor,
    required this.labelStyle,
    required this.onTap,
  });

  final NavShellTab data;
  final bool active;
  final Color unselectedColor;
  final Color activeColor;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : unselectedColor;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? data.activeIcon : data.icon,
                  size: 24, color: color),
              const SizedBox(height: 5),
              // The brief's 11/600 label, 800 when selected: weight as well
              // as color marks the selected tab.
              Text(
                data.label,
                style: labelStyle
                    ?.withWeight(active ? FontWeight.w800 : FontWeight.w600)
                    .copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
