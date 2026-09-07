import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's brand mark: a handled magnifying glass ("loupe"), drawn with
/// [CustomPainter] instead of shipped as an image asset — no new
/// dependency, and this is meant to become the single source the app icon
/// is generated from later too.
///
/// Defined in a fixed 100x100 logical coordinate space and scaled to
/// whatever [size] is requested, so it stays crisp at any resolution and
/// only ever needs updating in one place.
class BrandMark extends StatelessWidget {
  final double size;

  const BrandMark({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final rim = Theme.of(context).colorScheme.secondary;
    return CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(rim: rim),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  final Color rim;

  _BrandMarkPainter({required this.rim});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    // 1. Handle.
    canvas.drawLine(
      const Offset(62, 62),
      const Offset(86, 86),
      Paint()
        ..color = rim
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );

    const glassCenter = Offset(43, 43);
    const glassRadius = 24.0;

    // 2. Glass fill.
    canvas.drawCircle(
      glassCenter,
      glassRadius,
      Paint()
        ..color = brandMarkGlass
        ..style = PaintingStyle.fill,
    );

    // 3. Glass rim.
    canvas.drawCircle(
      glassCenter,
      glassRadius,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );

    // 4. Glint — an SVG-style point-to-point arc (start, end, radius,
    // large-arc flag, sweep direction), which is exactly what
    // Path.arcToPoint takes.
    final glintPath = Path()
      ..moveTo(32, 37)
      ..arcToPoint(
        const Offset(41, 29),
        radius: const Radius.circular(13),
        largeArc: false,
        clockwise: true,
      );
    canvas.drawPath(
      glintPath,
      Paint()
        ..color = brandMarkGlint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.rim != rim;
}
