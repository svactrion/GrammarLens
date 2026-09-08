import 'package:flutter/material.dart';

import 'floating_nav_shell.dart';

/// The D1 hybrid-theme shell (docs/design-audit.md §5): an orange header
/// band in light mode / neutral band in dark mode (see [ColorScheme]'s
/// `bandBackground`/`bandForeground` extension in `theme.dart` — this
/// widget reads those, never its own color), over a neutral
/// `surfaceContainerLow` body in both themes. Every screen except Welcome
/// (D1's one deliberate exception, staying full orange) migrates onto this
/// widget one batch at a time rather than all at once.
///
/// Also the single place that solves scroll behavior, safe-area, and
/// bottom-nav clearance for a D1 screen, so docs/design-audit.md S4 (the
/// nav bar overlapping scrollable content) can't reappear screen by screen
/// the way it did before `NavBarClearance` existed: every caller passes
/// [children] for a `ListView`, not a pre-built scroll view of its own.
class BrandScaffold extends StatelessWidget {
  const BrandScaffold({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bandBottom,
    this.isTabRoot = false,
    this.horizontalPadding,
    this.controller,
    required this.children,
  });

  /// The band's title widget — a plain [Text] on most screens (often via
  /// `PageTitle`), but left as a [Widget] since Home's brand wordmark
  /// needs its own explicit style.
  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;

  /// Extra band content below the title — e.g. a results screen's score
  /// (Batch 4). Null on every screen that doesn't need it, Home included.
  final PreferredSizeWidget? bandBottom;

  /// True only for the screens living inside `FloatingNavShell` (Home,
  /// later Review/Settings) — reserves [NavBarClearance]'s measured bottom
  /// padding so content can scroll fully clear of the floating nav bar.
  /// False (the default) for every pushed screen, which has no nav bar to
  /// clear and would otherwise reserve dead space for one that isn't there.
  final bool isTabRoot;

  /// Overrides the default responsive horizontal padding
  /// (`(width * 0.045).clamp(16, 28)`, Home's existing formula) — null uses
  /// that default.
  final double? horizontalPadding;

  /// Optional — lets a caller observe/drive scroll position (e.g. a
  /// "back to top" affordance later). Null lets the [ListView] manage its
  /// own.
  final ScrollController? controller;

  /// The screen's own content, laid out in a [ListView] this widget owns.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = horizontalPadding ?? (width * 0.045).clamp(16.0, 28.0);
    final bottomPadding = isTabRoot
        ? NavBarClearance.of(context)
        : MediaQuery.paddingOf(context).bottom + 16;

    return Scaffold(
      // Overrides the app-wide default (still the band color, for every
      // screen not yet migrated) with D1's neutral body — the app bar
      // below is left to inherit `bandBackground`/`bandForeground` from
      // the theme rather than repeating that expression here, since
      // they're already identical by construction (see theme.dart).
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: title,
        leading: leading,
        actions: actions,
        bottom: bandBottom,
        // Decided once here, not per screen (docs/design-audit.md: Daily
        // Test results showed "an opaque orange app bar with a hard edge
        // appears on scroll but is absent at scroll-top" — content
        // scrolling under the band must look the same at rest and mid-
        // scroll, not gain a new edge). The band already has a permanent
        // separation from the body via bandBackground/bandForeground alone
        // (a hard, un-blurred color cut, not a gradient — visible at every
        // scroll position because it's the app bar's own bottom edge, not
        // scroll-triggered) — the default Material scrolled-under shadow
        // would only add a second, redundant edge signal on top of that,
        // so it's turned off explicitly rather than left to the inherited
        // default.
        scrolledUnderElevation: 0,
      ),
      body: Theme(
        // A card sitting directly on this body would be the same color as
        // the body itself (both `surfaceContainerLow`) and separate only
        // by shadow — weak in light mode, and shadow barely reads at all
        // in dark mode. Scoped to this subtree only, so screens that
        // haven't migrated onto BrandScaffold yet keep today's
        // `surfaceContainerLow` cards on their still-orange/near-black
        // scaffold, unchanged.
        data: theme.copyWith(
          cardTheme: theme.cardTheme.copyWith(
            color: colorScheme.surfaceContainerHigh,
          ),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, bottomPadding),
          children: children,
        ),
      ),
    );
  }
}
