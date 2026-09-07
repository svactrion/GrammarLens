import 'package:flutter/material.dart';

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
    return SegmentedButton<T>(
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
    );
  }
}
