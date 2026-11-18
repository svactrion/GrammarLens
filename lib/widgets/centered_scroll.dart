import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SPEC v12 (V18, V20): a loading screen's content centred vertically in
/// the space it is given (on the device V20 sat at the top with the lower
/// half empty); it scrolls only when it does not fit (a small phone, a
/// large text size).
class CenteredScroll extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const CenteredScroll(
      {super.key, required this.child, this.padding = EdgeInsets.zero});

  /// The content's own box (tests read where it sits).
  static const contentKey = ValueKey('centered_scroll_content');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight: math.max(0.0, box.maxHeight - padding.vertical)),
          child: Center(
            child: KeyedSubtree(key: contentKey, child: child),
          ),
        ),
      ),
    );
  }
}
