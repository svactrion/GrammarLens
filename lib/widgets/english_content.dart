import 'package:flutter/widgets.dart';

/// English content inside the interface (1.4.0 B3;
/// docs/1.4.0-b3-batch0-report.md §3.3, §8 Q7): the questions, the answer
/// boxes, the learner's answer, the correction and the AI feedback stay
/// English in every interface language (1.4.0 D2), so they read left to
/// right with a left-aligned caret even when the interface around them is
/// right to left (Arabic). The chrome around them (titles, labels,
/// buttons) follows the interface direction.
///
/// Wraps only the English text itself, never a label or a button beside
/// it. Text inside defaults to `TextAlign.start`, which is left here.
class EnglishContent extends StatelessWidget {
  final Widget child;

  const EnglishContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: child);
}
