import 'package:flutter/material.dart';

/// A 40x40 bordered circle icon button — the Back (top-left) and Close
/// (top-right) affordances on a question screen's app bar.
///
/// When [visible] is false, this renders an empty box of the exact same
/// footprint instead of nothing at all. That matters specifically for
/// Back on a question screen's first question: omitting the widget
/// entirely (rather than hiding it in place) would shrink the app bar's
/// leading slot, shifting the centered title sideways the moment a second
/// question makes Back appear — see [QuestionAppBar]'s own doc comment
/// and the regression test in question_app_bar_test.dart.
class HeaderCircleIconButton extends StatelessWidget {
  static const double size = 40;

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color color;
  final bool visible;

  const HeaderCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.color,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color),
        style: IconButton.styleFrom(
          shape: CircleBorder(
            side: BorderSide(color: color.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}

/// The app bar shared by PracticeScreen's and DailyTestScreen's question
/// flow: Back (top-left) and Close (top-right) as identical 40x40 bordered
/// circles, the topic/screen name centered between them, and a progress
/// bar + "N / total" counter sharing one row underneath.
///
/// Back and Close both live in the app bar now — previously Back sat in
/// the bottom footer instead, shown only when [showBack] was true and
/// otherwise omitted outright. That meant the app bar's leading slot
/// (present when Back showed, absent when it didn't) had a different
/// width on question 1 than on question 2+, and since the title is
/// centered *within* that slot, its on-screen center shifted sideways
/// between questions purely because of whether Back happened to exist —
/// never intentional, easy to miss when Back and the title lived in
/// different widgets entirely. [HeaderCircleIconButton]'s `visible` flag
/// fixes this at the root: Back is always present as a widget, at a
/// constant size, whether or not [showBack] currently allows using it.
class QuestionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final int currentIndex;
  final int total;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onClose;

  const QuestionAppBar({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.total,
    required this.showBack,
    required this.onBack,
    required this.onClose,
  });

  static const double _bottomHeight = 28;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _bottomHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return AppBar(
      // Same call BrandScaffold's own built-in app bar makes, for the same
      // reason (docs/design-audit.md: a scroll-triggered shadow would add
      // a second, inconsistent edge signal on top of the band's already-
      // permanent color-cut boundary) — this app bar is custom, so it has
      // to make that call for itself rather than inheriting it.
      scrolledUnderElevation: 0,
      leading: Center(
        child: HeaderCircleIconButton(
          icon: Icons.arrow_back_rounded,
          onPressed: onBack,
          tooltip: 'Previous question',
          color: appBarFg,
          visible: showBack,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleLarge
            ?.copyWith(color: appBarFg, fontWeight: FontWeight.w600),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: HeaderCircleIconButton(
            icon: Icons.close_rounded,
            onPressed: onClose,
            tooltip: 'Leave',
            color: appBarFg,
          ),
        ),
      ],
      // The progress bar this used to share a row with is gone
      // (docs/design-audit.md, Batch 0 item 7): it and this counter told
      // the same story, and for the small, fixed counts this app actually
      // uses (3/5/10 questions), an exact "N / total" is more informative
      // than an approximate fill anyway. Losing that row is also what
      // shortens the header — this widget's own audit-flagged complaint.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_bottomHeight),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: Text(
              '${currentIndex + 1} / $total',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700, color: appBarFg),
            ),
          ),
        ),
      ),
    );
  }
}
