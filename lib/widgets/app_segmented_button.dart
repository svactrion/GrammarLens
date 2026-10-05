import 'package:flutter/material.dart';
import '../theme.dart';

/// A thin, opinionated wrapper around [SegmentedButton] — used everywhere
/// in this app instead of the raw widget, so every segmented control
/// shares the same sizing behavior: each segment is always an equal slice
/// of the available width, regardless of which one is selected.
///
/// Root cause this works around: `SegmentedButton`'s Material defaults
/// size every segment to the *content* width of the widest one, and the
/// selected segment's content is wider than an unselected one by exactly
/// one checkmark icon (`showSelectedIcon` defaults to true). Since "widest"
/// depends on which segment currently carries that icon, the control's
/// total width silently changed with the selection — measured directly in
/// the regression test this class exists to satisfy (see
/// settings_screen_test.dart's "the control is the same width..." test,
/// and the commit that introduced this file for the actual numbers).
///
/// [SegmentedButton.expandedInsets] (set here to [EdgeInsets.zero]) is what
/// actually fixes the sizing: a non-null value switches the control into a
/// mode where every segment is exactly `availableWidth / segmentCount`,
/// computed purely from the available width — never from any segment's
/// content. [showSelectedIcon] is turned off on top of that, since it was
/// the actual source of the content asymmetry and the filled background
/// already marks the selection without it.
///
/// Neither of these is expressible through a shared [ButtonStyle] or
/// [SegmentedButtonThemeData] — both are constructor parameters, not style
/// properties — which is why this app uses a wrapper widget rather than a
/// shared style object.
///
/// 1.2.0 look (the brief's Profile controls): the segments sit in a subtle
/// tile (radius 14, 4 pt inset) with no outline; the selected segment is
/// the info surface with its label in 800, the others transparent with a
/// textSecondary label in 700 — weight, not only color, marks the choice.
/// Each segment is at least 44 pt tall.
class AppSegmentedButton<T> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final void Function(Set<T>) onSelectionChanged;

  const AppSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = theme.textTheme.labelMedium;
    bool isSelected(Set<WidgetState> states) =>
        states.contains(WidgetState.selected);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SegmentedButton<T>(
          segments: segments,
          selected: selected,
          onSelectionChanged: onSelectionChanged,
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
            side: const WidgetStatePropertyAll(BorderSide.none),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                isSelected(states)
                    ? colorScheme.secondaryContainer
                    : Colors.transparent),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                isSelected(states)
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant),
            iconColor: WidgetStateProperty.resolveWith((states) =>
                isSelected(states)
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant),
            textStyle: WidgetStateProperty.resolveWith((states) =>
                label?.withWeight(
                    isSelected(states) ? FontWeight.w800 : FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
