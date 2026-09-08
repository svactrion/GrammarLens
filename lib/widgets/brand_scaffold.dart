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
/// the way it did before `NavBarClearance` existed: the common case passes
/// [children] for a `ListView` this widget owns, not a pre-built scroll
/// view of its own. [body] is the deliberate exception, for a single
/// loading/error/empty state that needs centering rather than scrolling —
/// see its own doc comment.
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
    this.children,
    this.body,
  }) : assert(
          (children == null) != (body == null),
          'Provide exactly one of children or body',
        );

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

  /// The screen's own content, laid out in a [ListView] this widget owns —
  /// mutually exclusive with [body]. Use this for ordinary scrollable
  /// content (the common case).
  final List<Widget>? children;

  /// An escape hatch for content the owned [ListView] can't lay out
  /// correctly — a single loading/error/empty state that needs to be
  /// centered in the full available height, not stacked top-down as one
  /// item in a scroll view. Mutually exclusive with [children]; when set,
  /// [controller] and [horizontalPadding] don't apply (the caller owns
  /// this content's layout entirely). Band, neutral body background, and
  /// the local card-theme override still apply either way.
  final Widget? body;

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
        // by shadow or the color step to `surfaceContainerHigh` — measured
        // directly (docs/build-log.md) and neither holds up alone in both
        // themes: the color step is a soft ~1.14-1.20:1 in both, and the
        // 6dp shadow that works in light mode (~1.73:1 against body) is
        // nearly inert in dark mode (~1.06:1). A border is what's added
        // here specifically because it's the one mechanism that doesn't
        // depend on shadow rendering or a subtle tonal step at all — the
        // same role, same visible line, in either theme.
        //
        // `outline`, not `outlineVariant` — tried `outlineVariant` first
        // (the usual divider/border role elsewhere in this app) and
        // measured it directly on-device: ~1.34:1 against body in light
        // mode, and the line was genuinely hard to see, not just a
        // borderline number on paper. `outline` measures ~3.11:1 against
        // body / ~2.72:1 against the card in light mode, ~5.05:1 / ~4.20:1
        // in dark — comfortably legible in both, still an existing role,
        // nothing invented. Not fixed by changing line thickness instead:
        // the problem was contrast, not size.
        // Elevation is kept, deliberately reduced rather than dropped to 0
        // (`elevation: 1`, M3's smallest non-zero step): the border is now
        // the primary, theme-consistent signal, and a heavier shadow would
        // have re-created exactly what this was meant to close — light
        // mode separating by two mechanisms while dark mode only gets one,
        // cards visibly heavier in one theme than the other.
        // Scoped to this subtree only, so screens that haven't migrated
        // onto BrandScaffold yet keep today's `surfaceContainerLow` cards
        // at the app-wide 6dp elevation on their still-orange/near-black
        // scaffold, unchanged.
        data: theme.copyWith(
          cardTheme: theme.cardTheme.copyWith(
            color: colorScheme.surfaceContainerHigh,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outline),
            ),
          ),
        ),
        child: body ??
            ListView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, bottomPadding),
              children: children!,
            ),
      ),
    );
  }
}
