import 'dart:math' as math;
import 'dart:ui';

/// The mountain's shapes in scene units (320 × 740), shared by every theme
/// (1.1.0 design decision e, Batch 3c): a theme only chooses their colors,
/// or covers a layer with an image. Candidate 1 of the Batch 3c-A study,
/// "layered ridges" (`docs/design/batch3c/report.md`).
abstract final class ClimbScene {
  /// The summit's peak vertex; the trail ends just below it.
  static const peak = Offset(160, 72);

  /// A concave silhouette, wide and spread at the foot, steep toward the
  /// summit: half-width 22 + 240 · t^1.25, t running 0 at the peak to 1 at
  /// y = 760 (below the scene, so the foot never shows an edge).
  static final List<Offset> body =
      _concave(peak: peak, baseY: 760, top: 22, spread: 240, power: 1.25);

  /// Rounded hills in front of the foot, drawn over the body.
  static const foothills = [
    Rect.fromLTRB(-280, 650, 90, 830),
    Rect.fromLTRB(250, 670, 600, 840),
  ];

  static final Path _bodyPath = Path()..addPolygon(body, true);

  /// On the ground: the mountain or a foothill. Stop markers and
  /// environment items stand only on the ground.
  static bool onGround(Offset p) =>
      _bodyPath.contains(p) ||
      foothills.any((r) {
        final dx = (p.dx - r.center.dx) / (r.width / 2),
            dy = (p.dy - r.center.dy) / (r.height / 2);
        return dx * dx + dy * dy <= 1;
      });

  static List<Offset> _concave(
      {required Offset peak,
      required double baseY,
      required double top,
      required double spread,
      required double power}) {
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i <= 60; i++) {
      final t = i / 60;
      final y = peak.dy + (baseY - peak.dy) * t;
      // The half-width ramps up to [top] over the first eighth, so the
      // peak is a point, not a flat top.
      final d =
          t == 0 ? 0.0 : top * math.min(1, t * 8) + spread * math.pow(t, power);
      left.add(Offset(peak.dx - d, y));
      right.add(Offset(peak.dx + d, y));
    }
    return [...left.reversed, ...right.skip(1)];
  }
}
