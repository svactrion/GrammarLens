import 'package:flutter/material.dart';

import '../utils/content_width.dart';
import 'floating_nav_shell.dart';

/// The screen shell every screen but Welcome uses: an app bar and a body,
/// both the page color (`surfaceContainerLow`, pageBackground), in both
/// themes. Until the 1.2.0 redesign the app bar was D1's header band
/// (docs/design-audit.md §5): orange in light mode, neutral in dark. The
/// band is gone; the app bar takes its colors from `appBarTheme`
/// (`theme.dart`), never its own. Welcome sets its own background.
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

  /// The app bar's title widget — a plain [Text] on most screens (often via
  /// `PageTitle`), but left as a [Widget] since Home's brand wordmark
  /// needs its own explicit style. Mutually exclusive with [appBar],
  /// enforced the same way as [children]/[body] — see that field's doc
  /// comment for why this is an assertion, not just a convention.
  final Widget? title;

  /// A fully custom app bar, replacing the one this widget would otherwise
  /// build from [title]/[leading]/[actions]/[bandBottom] (all ignored when
  /// this is set) — e.g. a zero-height app bar for a screen whose header is
  /// in the page (the question screens, Topic Practice). The custom app bar
  /// owns its own
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

  /// Extra app bar content below the title — e.g. a results screen's score
  /// (Batch 4). Null on every screen that doesn't need it, Home included.
  final PreferredSizeWidget? bandBottom;

  /// True only for the screens living inside `FloatingNavShell` (Home,
  /// later Review/Settings) — reserves [NavBarClearance]'s measured bottom
  /// padding so content can scroll fully clear of the floating nav bar.
  /// False (the default) for every pushed screen, which has no nav bar to
  /// clear and would otherwise reserve dead space for one that isn't there.
  final bool isTabRoot;

  /// Overrides the default responsive horizontal padding
  /// (`ContentWidth.basePadding`: 14 pt below 360 pt wide, 18 above) — null uses
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
  /// this content's layout entirely). The app bar and the page background
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
    final size = MediaQuery.sizeOf(context);
    // P1: on an iPad the list is held to the centred content column
    // (`ContentWidth`); on an iPhone this is the padding unchanged.
    final hPad = ContentWidth.sidePadding(
        size, horizontalPadding ?? ContentWidth.basePadding(size.width));
    final bottomPadding = bottomBar != null
        ? 16.0
        : isTabRoot
            ? NavBarClearance.of(context)
            : MediaQuery.paddingOf(context).bottom + 16;

    final PreferredSizeWidget bar = appBar ??
        AppBar(
          title: title,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
          bottom: bandBottom,
          // Decided once here, not per screen (docs/design-audit.md: Daily
          // Test results showed "an opaque orange app bar with a hard edge
          // appears on scroll but is absent at scroll-top" — content
          // scrolling under the app bar must look the same at rest and
          // mid-scroll, not gain a new edge). The app bar is the page
          // color, so content simply passes under it; the default Material
          // scrolled-under shadow would add an edge that is absent at
          // scroll-top, so it's turned off explicitly rather than left to
          // the inherited default. A custom [appBar] (see its own doc
          // comment) makes this same call for itself.
          scrolledUnderElevation: 0,
        );
    // P1: on an iPad the app bar stays full width and its content (back,
    // title, actions, [bandBottom]) moves in to the content column. Not
    // wrapped at all on an iPhone, so nothing there changes.
    final bandInset = ContentWidth.insetOf(context,
        edge: ContentWidth.basePadding(size.width));
    final PreferredSizeWidget band = bandInset == 0
        ? bar
        : PreferredSize(
            preferredSize: bar.preferredSize,
            child: ColoredBox(
              color: theme.appBarTheme.backgroundColor ??
                  colorScheme.surfaceContainerLow,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: bandInset),
                child: bar,
              ),
            ),
          );

    return Scaffold(
      // The page color; the app bar inherits the same color from
      // `appBarTheme` rather than repeating it here.
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: band,
      // No local card-theme override: the card treatment is the app-wide
      // default — see `theme.dart`'s `cardTheme` for the current values
      // and the reasoning behind them.
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
