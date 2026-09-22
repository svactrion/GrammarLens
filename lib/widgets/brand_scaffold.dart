import 'package:flutter/material.dart';

import 'floating_nav_shell.dart';

/// The D1 hybrid-theme shell (docs/design-audit.md §5, closed): an orange
/// header band in light mode / neutral band in dark mode (see
/// [ColorScheme]'s `bandBackground`/`bandForeground` extension in
/// `theme.dart` — this widget reads those, never its own color), over a
/// neutral `surfaceContainerLow` body in both themes. Every screen uses
/// this widget now except Welcome — D1's one deliberate exception, staying
/// full orange.
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
    this.title,
    this.appBar,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.bandBottom,
    this.isTabRoot = false,
    this.horizontalPadding,
    this.controller,
    this.children,
    this.body,
    this.bottomBar,
  })  : assert(
          (children == null) != (body == null),
          'Provide exactly one of children or body',
        ),
        assert(
          (title == null) != (appBar == null),
          'Provide exactly one of title or appBar',
        );

  /// The band's title widget — a plain [Text] on most screens (often via
  /// `PageTitle`), but left as a [Widget] since Home's brand wordmark
  /// needs its own explicit style. Mutually exclusive with [appBar],
  /// enforced the same way as [children]/[body] — see that field's doc
  /// comment for why this is an assertion, not just a convention.
  final Widget? title;

  /// A fully custom app bar, replacing the one this widget would otherwise
  /// build from [title]/[leading]/[actions]/[bandBottom] (all ignored when
  /// this is set) — the question screens' `QuestionAppBar` is the reason
  /// this exists: its own Back/Close/progress-row layout has nothing in
  /// common with a plain title bar. The custom app bar owns its own
  /// `scrolledUnderElevation`/colors; this widget still supplies the
  /// neutral body around it either way.
  final PreferredSizeWidget? appBar;

  final Widget? leading;

  /// Passed straight through to the built-in app bar's own field of the
  /// same name — e.g. Premium sets this false to suppress the automatic
  /// back chevron a pushed route would otherwise get, since Close already
  /// covers dismissal there. Ignored when [appBar] is set.
  final bool automaticallyImplyLeading;

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
  /// mutually exclusive with [body]: passing both, or neither, fails an
  /// assertion at construction rather than silently picking one or
  /// rendering nothing, since a caller getting this wrong should find out
  /// immediately, not from a screen that quietly looks incomplete. Use
  /// this for ordinary scrollable content (the common case).
  final List<Widget>? children;

  /// An escape hatch for content the owned [ListView] can't lay out
  /// correctly — a single loading/error/empty state that needs to be
  /// centered in the full available height, not stacked top-down as one
  /// item in a scroll view. Mutually exclusive with [children] — see its
  /// doc comment for the enforced-not-just-documented reasoning; when set,
  /// [controller] and [horizontalPadding] don't apply (the caller owns
  /// this content's layout entirely). The band and neutral body background
  /// still apply either way.
  final Widget? body;

  /// A fixed area under the content, always in view (a results screen's one
  /// primary button). It goes in the Scaffold's own bottom slot rather than at
  /// the end of a [body] column, so a SnackBar floats above it instead of
  /// covering it, and it is expected to look after the bottom safe area itself
  /// (the content above then only reserves its own small gap).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = horizontalPadding ?? (width * 0.045).clamp(16.0, 28.0);
    final bottomPadding = bottomBar != null
        ? 16.0
        : isTabRoot
            ? NavBarClearance.of(context)
            : MediaQuery.paddingOf(context).bottom + 16;

    return Scaffold(
      // The app bar below is left to inherit `bandBackground`/
      // `bandForeground` from the theme rather than repeating that
      // expression here, since they're already identical by construction
      // (see theme.dart's `BandColors` extension).
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: appBar ??
          AppBar(
            title: title,
            leading: leading,
            automaticallyImplyLeading: automaticallyImplyLeading,
            actions: actions,
            bottom: bandBottom,
            // Decided once here, not per screen (docs/design-audit.md: Daily
            // Test results showed "an opaque orange app bar with a hard edge
            // appears on scroll but is absent at scroll-top" — content
            // scrolling under the band must look the same at rest and mid-
            // scroll, not gain a new edge). The band already has a permanent
            // separation from the body via bandBackground/bandForeground
            // alone (a hard, un-blurred color cut, not a gradient — visible
            // at every scroll position because it's the app bar's own
            // bottom edge, not scroll-triggered) — the default Material
            // scrolled-under shadow would only add a second, redundant edge
            // signal on top of that, so it's turned off explicitly rather
            // than left to the inherited default. A custom [appBar] (see
            // its own doc comment) makes this same call for itself.
            scrolledUnderElevation: 0,
          ),
      // No local card-theme override here anymore (docs/design-audit.md §5
      // D1, closed): every screen is on this neutral body now, so the
      // card treatment that used to be scoped to this widget's own subtree
      // while migration was in progress is simply the app-wide default —
      // see `theme.dart`'s `cardTheme` for the current values and the
      // reasoning behind them.
      bottomNavigationBar: bottomBar,
      body: body ??
          ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, bottomPadding),
            children: children!,
          ),
    );
  }
}
