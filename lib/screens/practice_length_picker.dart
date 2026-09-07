import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../models/practice_length.dart';
import '../spacing.dart';

/// The largest [PracticeLength.questionCount] — the dial's "full circle"
/// reference. Computed from the enum so it stays correct if a length is
/// ever added or its question count changes, rather than a hand-written
/// ratio constant per option.
final int _maxQuestionCount =
    PracticeLength.values.map((length) => length.questionCount).reduce(math.max);

/// The selection card dial's fill fraction for [length] — its question
/// count over the largest question count across [PracticeLength.values],
/// never a hand-written ratio per option. A top-level function (rather than
/// inlined where the dial uses it) so this specific "derived, not
/// hardcoded" claim has a direct unit test.
@visibleForTesting
double practiceLengthDialRatio(PracticeLength length) =>
    length.questionCount / _maxQuestionCount;

/// The custom thumb's radius (see [_DragHandleThumbShape]) — and, not
/// coincidentally, exactly how far Flutter insets the slider's track from
/// each edge of its own width.
///
/// [BaseSliderTrackShape.getPreferredRect] (the mixin `RoundedRectSliderTrackShape`
/// uses) computes that inset as `max(thumbWidth, overlayWidth) / 2`; the
/// overlay is disabled to zero width below, so the inset collapses to
/// exactly this thumb radius. The length-label row has to divide up that
/// same *inset* track width, not the sheet's full width, to land its
/// labels under the actual stops — previously it didn't, and the two could
/// only ever agree by coincidence at the exact midpoint. Both the thumb
/// shape and the label row read this one constant so they can't drift
/// apart again; see the regression test in practice_length_picker_test.dart.
const double _kSliderThumbRadius = 22;

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

  // Both the Slider itself and the label row below need "how many stops"
  // and "the last stop's index" — computed once from the enum, rather than
  // the slider hardcoding max/divisions separately from whatever the label
  // row assumes.
  static final double _maxStopIndex =
      (PracticeLength.values.length - 1).toDouble();

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
                  radius: _kSliderThumbRadius,
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
                max: _maxStopIndex,
                divisions: PracticeLength.values.length - 1,
                value: _selected.index.toDouble(),
                onChanged: _onSliderChanged,
                semanticFormatterCallback: (value) {
                  final length = PracticeLength.values[value.round()];
                  return '${length.questionCount} questions, ${length.label}';
                },
              ),
            ),
            _LengthLabelRow(selected: _selected),
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

/// The 3/5/10 row under the slider. Each label sits at the exact x position
/// of its slider stop rather than being laid out by `Row`/`MainAxisAlignment`
/// across the row's full width — the slider's own track is inset by
/// [_kSliderThumbRadius] on each side, so a naive full-width row only ever
/// lined up at the midpoint by coincidence (see the regression test in
/// practice_length_picker_test.dart, and this file's diagnosis in the
/// commit that introduced this class).
///
/// [FractionalTranslation] centers each label exactly on its computed point
/// regardless of the label's own text width ("3" and "10" render at
/// different widths) — a `Row` with any `MainAxisAlignment` would still be
/// off by a fraction of that width difference.
class _LengthLabelRow extends StatelessWidget {
  final PracticeLength selected;

  const _LengthLabelRow({required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const values = PracticeLength.values;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth - 2 * _kSliderThumbRadius;
        return SizedBox(
          width: constraints.maxWidth,
          child: Stack(
            children: [
              // Invisible — establishes the Stack's height from the same
              // text style the real labels use, instead of a guessed pixel
              // constant. The digit itself is arbitrary (only the style's
              // line height matters) — picked to not collide with any real
              // question count when a test looks labels up by text.
              Opacity(
                opacity: 0,
                child: Text('0', style: theme.textTheme.bodyMedium),
              ),
              for (var i = 0; i < values.length; i++)
                Positioned(
                  left: _kSliderThumbRadius +
                      trackWidth * i / (values.length - 1),
                  top: 0,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Text(
                      key: ValueKey('lengthLabel_${values[i].name}'),
                      '${values[i].questionCount}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: values[i] == selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: values[i] == selected
                            ? colorScheme.secondary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
      // Card color is fixed regardless of selection — only the dial and
      // text inside change.
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Deliberately outside the text's AnimatedSwitcher below: the
          // dial keeps its own State alive across a selection change so
          // its ring can tween continuously between two ratios (see
          // _LengthDialState.didUpdateWidget) — an AnimatedSwitcher would
          // discard and recreate it on every change instead, which is
          // exactly right for a discrete text swap but wrong for a
          // continuous sweep.
          _LengthDial(
            questionCount: selected.questionCount,
            ratio: practiceLengthDialRatio(selected),
            reduceMotion: reduceMotion,
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: AnimatedSwitcher(
              key: const Key('lengthTextSwitcher'),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey(selected),
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
          ),
        ],
      ),
    );
  }
}

/// The selection card's dial: a ring whose filled fraction is
/// `questionCount / _maxQuestionCount`, with the count itself centered on
/// top. Shows, at a glance, that a longer session is also visually "more
/// full" — no duration is implied or shown; this is purely a question-count
/// ratio.
///
/// Deliberately not rebuilt via a keyed swap ([AnimatedSwitcher]) the way
/// the card's text is — this widget's own State has to survive a selection
/// change for [didUpdateWidget] to tween the ring smoothly between two
/// ratios. The count text still gets the same discrete-swap treatment as
/// before, just scoped to this widget's own internal [AnimatedSwitcher]
/// instead of the whole card.
class _LengthDial extends StatefulWidget {
  final int questionCount;
  final double ratio;
  final bool reduceMotion;

  const _LengthDial({
    required this.questionCount,
    required this.ratio,
    required this.reduceMotion,
  });

  @override
  State<_LengthDial> createState() => _LengthDialState();
}

class _LengthDialState extends State<_LengthDial>
    with SingleTickerProviderStateMixin {
  static const _size = 84.0;
  static const _strokeWidth = 8.0;

  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late Tween<double> _ratioTween;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      // Starts "complete" so the very first frame shows widget.ratio
      // directly rather than animating in from zero on mount.
      value: 1,
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _ratioTween = Tween<double>(begin: widget.ratio, end: widget.ratio);
  }

  @override
  void didUpdateWidget(covariant _LengthDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratio == widget.ratio) return;
    final currentRatio = _ratioTween.evaluate(_curve);
    _ratioTween = Tween<double>(begin: currentRatio, end: widget.ratio);
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trackColor = colorScheme.onSecondaryContainer.withValues(alpha: 0.22);
    final fillColor = colorScheme.secondary;
    final textColor = colorScheme.onSecondaryContainer;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: const Size(_size, _size),
                painter: _DialPainter(
                  ratio: _ratioTween.evaluate(_curve),
                  strokeWidth: _strokeWidth,
                  trackColor: trackColor,
                  fillColor: fillColor,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            key: const Key('lengthNumberSwitcher'),
            duration: widget.reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: Text(
              '${widget.questionCount}',
              key: ValueKey(widget.questionCount),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double ratio;
  final double strokeWidth;
  final Color trackColor;
  final Color fillColor;

  const _DialPainter({
    required this.ratio,
    required this.strokeWidth,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Starts at 12 o'clock (-pi/2 in Canvas's 0-at-3-o'clock convention)
    // and sweeps clockwise (positive angle, since Canvas's y axis points
    // down) — a positive sweep is required for drawArc regardless, so
    // this only needs the start angle to land on 12 o'clock.
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      2 * math.pi * ratio.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fillColor != fillColor;
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
