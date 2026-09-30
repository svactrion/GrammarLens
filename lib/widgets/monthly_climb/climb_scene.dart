import 'dart:math' as math;
import 'dart:ui';

import '../../models/climb_theme.dart';

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

  /// Two lighter ridges behind the mountain, far first (decision e). They
  /// reach past the scene's sides for the wider framings.
  static const farRidge = [
    Offset(-260, 760),
    Offset(-260, 430),
    Offset(-150, 350),
    Offset(-70, 390),
    Offset(10, 300),
    Offset(80, 360),
    Offset(130, 330),
    Offset(200, 380),
    Offset(262, 290),
    Offset(330, 350),
    Offset(420, 300),
    Offset(580, 420),
    Offset(580, 760),
  ];
  static const midRidge = [
    Offset(-260, 760),
    Offset(-260, 540),
    Offset(-160, 470),
    Offset(-60, 520),
    Offset(20, 440),
    Offset(90, 500),
    Offset(230, 500),
    Offset(310, 420),
    Offset(390, 480),
    Offset(480, 450),
    Offset(580, 530),
    Offset(580, 760),
  ];

  /// The shadowed right face: from the peak down a jagged ridge line, then
  /// back up the silhouette's right flank. The rest of [body] is the lit
  /// face.
  static final List<Offset> shadowFace = [
    peak,
    const Offset(170, 150),
    const Offset(156, 238),
    const Offset(184, 330),
    const Offset(166, 440),
    const Offset(198, 560),
    const Offset(186, 760),
    ...body.where((p) => p.dx > peak.dx).toList().reversed,
  ];

  /// A pale rock cap just under the peak.
  static const cap = [
    Offset(160, 72),
    Offset(146, 98),
    Offset(150, 110),
    Offset(158, 104),
    Offset(166, 116),
    Offset(174, 102),
    Offset(180, 108),
    Offset(172, 88),
  ];

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

/// The scene's layer colors, derived from a theme's palette by one rule, so
/// light and dark (and, in Batch 4, other themes) get their tones the same
/// way (`docs/design/batch3c/report.md`, "Dark mode"). Flat colors only.
class ClimbSceneTones {
  final Color sky, farRidge, midRidge, litFace, shadowFace, cap, foothill;
  final Color pine, trunk, shrub, flower, flowerCenter;

  const ClimbSceneTones._(
      {required this.sky,
      required this.farRidge,
      required this.midRidge,
      required this.litFace,
      required this.shadowFace,
      required this.cap,
      required this.foothill,
      required this.pine,
      required this.trunk,
      required this.shrub,
      required this.flower,
      required this.flowerCenter});

  /// Farther layers lean toward the sky (haze), so in dark mode they get
  /// darker, as distance does against a night sky; the shadow face is the
  /// palette's ridge; ground in front leans toward the ridge; trees lean
  /// toward whichever of ink and sky is darker.
  factory ClimbSceneTones.of(ClimbPalette p) {
    final dark =
        p.ink.computeLuminance() < p.sky.computeLuminance() ? p.ink : p.sky;
    return ClimbSceneTones._(
      sky: p.sky,
      farRidge: Color.lerp(p.mountain, p.sky, .58)!,
      midRidge: Color.lerp(p.mountain, p.sky, .32)!,
      litFace: p.mountain,
      shadowFace: p.ridge,
      cap: p.stone,
      foothill: Color.lerp(p.mountain, p.ridge, .28)!,
      pine: Color.lerp(p.ridge, dark, .38)!,
      trunk: Color.lerp(p.ridge, dark, .7)!,
      shrub: Color.lerp(p.mountain, p.ridge, .78)!,
      flower: p.accent,
      flowerCenter: p.stone,
    );
  }
}
