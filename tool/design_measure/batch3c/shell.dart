// The Batch 3c card shell around a candidate scene. Measuring code only.
import 'package:flutter/material.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';

import 'geometry.dart';
import 'painter.dart';

/// The snail: the one side-facing avatar (Batch 3b R3); its art faces left.
final snail = Avatar.values[1];

class Framing {
  final String id;
  final double unitsTall;
  const Framing(this.id, this.unitsTall);
  double get scale => 350 / unitsTall;
  double sceneLeft(double cardW) => (cardW - sceneW * scale) / 2;
  double top(Offset pawn) => (pawn.dy * scale - 350 * .72)
      .clamp(0.0, sceneH * scale - 350 < 0 ? 0.0 : sceneH * scale - 350)
      .toDouble();
}

/// F1, today's framing (D5); and one showing the whole mountain.
const f1 = Framing('F1 (today, 480 units)', 480);
const whole = Framing('whole mountain (740 units)', 740);

/// Trail-sign plaque: a flat board with pointed ends.
class PlaqueBorder extends ShapeBorder {
  final BorderSide side;
  const PlaqueBorder(this.side);
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  Path _path(Rect r) {
    final p = r.height * .38; // how far the points reach in
    return Path()
      ..moveTo(r.left + p, r.top)
      ..lineTo(r.right - p, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.right - p, r.bottom)
      ..lineTo(r.left + p, r.bottom)
      ..lineTo(r.left, r.center.dy)
      ..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      canvas.drawPath(_path(rect), side.toPaint());
  @override
  ShapeBorder scale(double t) => PlaqueBorder(side.scale(t));
}

class MountainCard extends StatelessWidget {
  final Candidate c;
  final int days, day;
  final double cardW;
  final Framing framing;
  final String month; // shown without the year (decision c)
  final int year, monthNumber;
  const MountainCard(
      {super.key,
      required this.c,
      required this.days,
      required this.day,
      required this.cardW,
      required this.framing,
      required this.month,
      required this.year,
      required this.monthNumber});

  static const plaqueKey = ValueKey('plaque');
  static const monthKey = ValueKey('month');
  static const counterKey = ValueKey('counter');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = ClimbThemes.greenSlope.paletteFor(theme.brightness);
    final s = framing.scale;
    final pawn = c.stepAt(day, days);
    final top = framing.top(pawn);
    final left = framing.sceneLeft(cardW);
    final plaqueStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final plaqueText = TextPainter(
        text: TextSpan(text: 'Mountain of Learning', style: plaqueStyle),
        textDirection: TextDirection.ltr)
      ..layout();
    final plaqueH = plaqueText.height + 12;
    final labelStyle = theme.textTheme.labelLarge
        ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700);
    final score = day * 7; // about 70 % correct
    return SizedBox(
      width: cardW,
      child: Stack(clipBehavior: Clip.none, children: [
        Padding(
          padding: EdgeInsets.only(top: plaqueH / 2),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(20)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: cardW,
                  height: 350,
                  child: ColoredBox(
                    color: palette.sky,
                    child: Stack(children: [
                      Positioned(
                        left: left,
                        top: -top,
                        width: sceneW * s,
                        height: sceneH * s,
                        child: CustomPaint(
                            painter: CandidatePainter(c, days, day, palette)),
                      ),
                      Positioned(
                        left: left + (pawn.dx - 29) * s,
                        top: -top + (pawn.dy - 55) * s,
                        // Never mirrored (D4, confirmed by Batch 3c K2).
                        child: AvatarTile(avatar: snail, radius: 29 * s),
                      ),
                      // Month (no year) and steps, inside the frame, below
                      // the plaque.
                      Positioned(
                        left: 14,
                        right: 14,
                        top: plaqueH / 2 + 6,
                        child: Row(children: [
                          Text(month, key: monthKey, style: labelStyle),
                          const Spacer(),
                          Text('$day / $days',
                              key: counterKey, style: labelStyle),
                        ]),
                      ),
                    ]),
                  ),
                ),
                ClimbScoreBar(
                  score: score,
                  maxScore: MonthlyMedalRules.maxScore(year, monthNumber),
                  thresholds: {
                    for (final tier in MedalTier.values)
                      tier: MonthlyMedalRules.threshold(year, monthNumber, tier)
                  },
                ),
              ]),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: DecoratedBox(
              key: plaqueKey,
              decoration: ShapeDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: PlaqueBorder(BorderSide(color: scheme.outline))),
              child: SizedBox(
                height: plaqueH,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: plaqueH * .38 + 12),
                  child: Center(
                      widthFactor: 1,
                      child: Text('Mountain of Learning', style: plaqueStyle)),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
