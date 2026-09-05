import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

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
    return context.dependOnInheritedWidgetOfExactType<NavBarClearance>()
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

/// The floating, frosted-glass bottom nav bar (see docs/roadmap.md's "Home
/// + nav bar revision round"s for how this look was arrived at) as a
/// `Stack`, not `Scaffold.bottomNavigationBar` — that slot wraps its child
/// in an opaque `Material` spanning the full screen width regardless of
/// what's inside it, which painted a solid strip behind the pill's rounded
/// corners on every screen (see roadmap "Nav bar revision round 2"). A
/// `Stack` with the bar as a `Positioned` overlay has no such slot: nothing
/// paints outside the pill's own bounds, and [body] genuinely continues
/// underneath it, Instagram-style.
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

  /// Typically an `IndexedStack` of the app's tab screens.
  final Widget body;
  final List<NavShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChange;

  @override
  State<FloatingNavShell> createState() => _FloatingNavShellState();
}

class _FloatingNavShellState extends State<FloatingNavShell> {
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
    final isDark = theme.brightness == Brightness.dark;
    // Same contrast-checked color the app bar uses for content sitting
    // directly on the orange (light) / near-black (dark) scaffold — see
    // theme.dart's `appBarFg` for the reasoning.
    final unselectedColor =
        theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    return NavBarClearance(
      value: _clearance,
      child: Stack(
        children: [
          widget.body,
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              key: _barKey,
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        // Frosted glass: a translucent surface tint over
                        // the blur, not a solid fill — content scrolling
                        // behind the pill should still read through it,
                        // softened.
                        color: colorScheme.surfaceContainerLow
                            .withValues(alpha: isDark ? 0.55 : 0.68),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _FloatingNavBar(
                        tabs: widget.tabs,
                        selectedIndex: widget.selectedIndex,
                        onTabChange: widget.onTabChange,
                        unselectedColor: unselectedColor,
                        activeColor: colorScheme.secondary,
                        labelStyle: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
              Icon(active ? data.activeIcon : data.icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: labelStyle?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
