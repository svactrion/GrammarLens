import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/practice_length.dart';
import '../spacing.dart';

/// "How many questions" step shown before a practice set is generated (see
/// `practice_launch.dart`, which calls this ahead of every topic launch and
/// every Review "Practice this" launch so the two entry points can't drift
/// apart). [initial] — the user's last choice — is pre-selected.
///
/// A single drag gesture across the three options, rather than a list of
/// tappable cards (docs/design-audit.md §2's "Session-length dialog"
/// finding) — the slider's own drag replaces tap-to-select, so choosing and
/// confirming are now two separate steps: drag to preview a length, then
/// tap "Start N questions" to confirm. Dismissing without tapping it (the
/// back gesture, swipe-down, or tapping the scrim) resolves `null`, which
/// the caller treats as "cancelled, don't generate anything" — the same
/// contract the previous dialog had.
Future<PracticeLength?> showPracticeLengthPicker({
  required BuildContext context,
  required PracticeLength initial,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<PracticeLength>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surfaceContainerLowest,
    // A pure black scrim over the orange page reads as a muddy brown
    // (docs/design-audit.md §2) — tinted off the page's own foreground
    // color instead, at a mid opacity.
    barrierColor: colorScheme.onSurface.withValues(alpha: 0.42),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) => _PracticeLengthSheet(initial: initial),
  );
}

class _PracticeLengthSheet extends StatefulWidget {
  final PracticeLength initial;

  const _PracticeLengthSheet({required this.initial});

  @override
  State<_PracticeLengthSheet> createState() => _PracticeLengthSheetState();
}

class _PracticeLengthSheetState extends State<_PracticeLengthSheet> {
  late PracticeLength _selected = widget.initial;

  void _onSliderChanged(double value) {
    final next = PracticeLength.values[value.round()];
    if (next == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          Spacing.md,
          Spacing.xl,
          Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle — purely visual; showModalBottomSheet's own
            // swipe-to-dismiss already works over the whole sheet without
            // needing a gesture wired to this specifically.
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              'How many questions?',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: Spacing.lg),
            _SelectionCard(selected: _selected, reduceMotion: reduceMotion),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 8,
                trackShape: const RoundedRectSliderTrackShape(),
                activeTrackColor: colorScheme.secondary,
                inactiveTrackColor: colorScheme.surfaceContainerHigh,
                thumbColor: colorScheme.secondary,
                activeTickMarkColor: colorScheme.onSecondary,
                inactiveTickMarkColor: colorScheme.outline,
                thumbShape: _DragHandleThumbShape(
                  radius: 22,
                  chevronColor: colorScheme.onSecondary,
                ),
                overlayShape: SliderComponentShape.noOverlay,
                // The selection card above already shows the picked value
                // prominently — a floating value bubble under the thumb
                // while dragging would just repeat it.
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                min: 0,
                max: 2,
                divisions: 2,
                value: _selected.index.toDouble(),
                onChanged: _onSliderChanged,
                semanticFormatterCallback: (value) {
                  final length = PracticeLength.values[value.round()];
                  return '${length.questionCount} questions, ${length.label}';
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final length in PracticeLength.values)
                  Text(
                    '${length.questionCount}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          length == _selected ? FontWeight.w700 : FontWeight.w600,
                      color: length == _selected
                          ? colorScheme.secondary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Drag to set the session length',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text('Start ${_selected.questionCount} questions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big-number "this is what you've picked" card. Its content swaps via
/// [AnimatedSwitcher] rather than in place, so a length change reads as a
/// distinct step rather than text quietly changing underneath the reader.
class _SelectionCard extends StatelessWidget {
  final PracticeLength selected;
  final bool reduceMotion;

  const _SelectionCard({required this.selected, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onCard = colorScheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: AnimatedSwitcher(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
        child: Row(
          key: ValueKey(selected),
          children: [
            Text(
              '${selected.questionCount}',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: onCard,
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected.label,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: onCard,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected.description,
                    style: TextStyle(fontSize: 13, color: onCard),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big, unmissable drag handle — a filled circle with a soft drop shadow
/// and two small chevrons — in place of the plain circle a default Material
/// slider thumb draws. This screen's entire premise is that the choice is
/// made by dragging; a thumb that doesn't visibly invite that would defeat
/// the point.
class _DragHandleThumbShape extends SliderComponentShape {
  final double radius;
  final Color chevronColor;

  const _DragHandleThumbShape({
    required this.radius,
    required this.chevronColor,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final fillColor = sliderTheme.thumbColor!;

    canvas.drawCircle(
      center.translate(0, 2),
      radius,
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, radius, Paint()..color = fillColor);

    final chevronPaint = Paint()
      ..color = chevronColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    _drawChevron(
      canvas,
      center + const Offset(-5, 0),
      pointRight: false,
      paint: chevronPaint,
    );
    _drawChevron(
      canvas,
      center + const Offset(5, 0),
      pointRight: true,
      paint: chevronPaint,
    );
  }
}

void _drawChevron(
  Canvas canvas,
  Offset origin, {
  required bool pointRight,
  required Paint paint,
}) {
  final dir = pointRight ? 1.0 : -1.0;
  final apex = origin + Offset(3 * dir, 0);
  final top = origin + Offset(-2 * dir, -4);
  final bottom = origin + Offset(-2 * dir, 4);
  final path = Path()
    ..moveTo(top.dx, top.dy)
    ..lineTo(apex.dx, apex.dy)
    ..lineTo(bottom.dx, bottom.dy);
  canvas.drawPath(path, paint);
}
