import 'package:flutter/material.dart';
import '../theme.dart';

/// A 44 × 44 icon tile, the Back (top-left) and Close (top-right) controls
/// of a question screen's header (Question V2, the additional screens
/// package): the card surface, radius 13, the icon in textPrimary.
///
/// [onPressed] null draws it disabled at 40 % opacity in the same place:
/// Back on the first question keeps its slot, so the title never shifts
/// sideways between question 1 and question 2 (the reason the earlier
/// 40 × 40 button had a `visible` flag), and it now also says why it
/// cannot be used. Assistive technology reads it as a disabled button.
class HeaderIconButton extends StatelessWidget {
  static const double size = 44;

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(13),
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: tooltip,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
              disabledForegroundColor: colorScheme.onSurface,
            ),
            icon: Icon(icon, size: 21, color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// The header of PracticeScreen's and DailyTestScreen's question flow
/// (Question V2): Back to the previous question on the left, the title
/// (17 / 900) with an optional [subtitle] under it, and Close on the right,
/// over a 1 px `border` line. It sits in the page, not in an app bar, so a
/// long title wraps onto more lines instead of being cut off; the question
/// counter is in the question card.
///
/// Back never leaves the session: [onBack] null (the first question, or
/// while answers are being submitted) shows it disabled in place. Close is
/// always the way out, through the screen's own confirmation.
class QuestionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback onClose;
  final String closeTooltip;

  const QuestionHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    required this.onClose,
    this.closeTooltip = 'Leave',
  });

  static const backKey = ValueKey('question_header_back');
  static const closeKey = ValueKey('question_header_close');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Row(
          children: [
            HeaderIconButton(
              key: backKey,
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
              tooltip: 'Previous question',
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Semantics(
                header: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.withWeight(FontWeight.w900)
                          .copyWith(color: colorScheme.onSurface, height: 1.25),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.labelSmall
                            ?.withWeight(FontWeight.w400)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            HeaderIconButton(
              key: closeKey,
              icon: Icons.close_rounded,
              onPressed: onClose,
              tooltip: closeTooltip,
            ),
          ],
        ),
      ),
    );
  }
}
