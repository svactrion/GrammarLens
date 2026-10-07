// Batch 3c-A candidates: scene geometry. Measuring code only.
import 'dart:math' as math;
import 'dart:ui';

const sceneW = 320.0, sceneH = 740.0;

/// Straight legs joined by circular arcs (fillets); a leg too short for its
/// arc caps the arc's tangent at 45 % of the shorter leg.
Path filletPolyline(List<Offset> pts, List<double> radii) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  Offset unit(Offset o) => o / o.distance;
  for (var i = 1; i < pts.length - 1; i++) {
    final a = pts[i - 1], c = pts[i], b = pts[i + 1];
    final u = unit(c - a), v = unit(b - c);
    final turn =
        math.acos((u.dx * v.dx + u.dy * v.dy).clamp(-1.0, 1.0).toDouble());
    var r = radii[i - 1];
    var t = r * math.tan(turn / 2);
    final cap = .45 * math.min((c - a).distance, (b - c).distance);
    if (t > cap) {
      t = cap;
      r = t / math.tan(turn / 2);
    }
    final entry = c - u * t, exit = c + v * t;
    path.lineTo(entry.dx, entry.dy);
    final cross = u.dx * v.dy - u.dy * v.dx;
    path.arcToPoint(exit, radius: Radius.circular(r), clockwise: cross > 0);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

/// A concave silhouette: half-width d(y) = top + spread × t^power, where t
/// runs 0 at the peak to 1 at [baseY]. Wide and spread at the foot, steep
/// near the summit.
List<Offset> concaveSilhouette(
    {required Offset peak,
    required double baseY,
    required double top,
    required double spread,
    required double power,
    double lean = 0}) {
  final left = <Offset>[], right = <Offset>[];
  for (var i = 0; i <= 60; i++) {
    final t = i / 60;
    final y = peak.dy + (baseY - peak.dy) * t;
    final d =
        t == 0 ? 0.0 : top * math.min(1, t * 8) + spread * math.pow(t, power);
    left.add(Offset(peak.dx - d * (1 - lean), y));
    right.add(Offset(peak.dx + d * (1 + lean), y));
  }
  return [...left.reversed, ...right.skip(1)];
}

/// The silhouette's right flank from its foot up to just below the peak.
List<Offset> rightFlankUp(List<Offset> silhouette, Offset peak) =>
    silhouette.where((p) => p.dx > peak.dx).toList().reversed.toList();

class Candidate {
  final String id, title;

  /// The mountain body: the trail and markers must stay on it.
  final List<Offset> body;

  /// Back to front, each with a tone key.
  final List<(String, List<Offset>)> backLayers;
  final List<(String, List<Offset>)> faces; // on top of the body
  final List<(String, Rect)> foothills; // ellipses in front of the body
  final List<Offset> corners;
  final List<double> fillets;
  late final Path trail = filletPolyline(corners, fillets);
  late final PathMetric metric = trail.computeMetrics().single;
  late final Path bodyPath = Path()..addPolygon(body, true);
  Candidate(
      {required this.id,
      required this.title,
      required this.body,
      required this.backLayers,
      required this.faces,
      required this.foothills,
      required this.corners,
      required this.fillets});

  Offset get summit => corners.last;
  Offset stepAt(int day, int days) =>
      metric.getTangentForOffset(metric.length * day / days)!.position;
  Tangent tangentAt(double s) => metric.getTangentForOffset(s)!;

  /// On the body or on a foothill (both are ground).
  bool onGround(Offset p) =>
      bodyPath.contains(p) ||
      foothills.any((f) {
        final r = f.$2;
        final dx = (p.dx - r.center.dx) / (r.width / 2),
            dy = (p.dy - r.center.dy) / (r.height / 2);
        return dx * dx + dy * dy <= 1;
      });
}

/// Candidate 1 — layered ridges.
final c1 = () {
  const peak = Offset(160, 72);
  final body = concaveSilhouette(
      peak: peak, baseY: 760, top: 22, spread: 240, power: 1.25);
  return Candidate(
    id: 'c1',
    title: 'Candidate 1 — layered ridges',
    body: body,
    backLayers: [
      (
        'far',
        const [
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
          Offset(580, 760)
        ]
      ),
      (
        'mid',
        const [
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
          Offset(580, 760)
        ]
      ),
    ],
    faces: [
      // The shadowed right face, split from the lit one along a ridge line.
      (
        'shadow',
        [
          peak,
          const Offset(170, 150),
          const Offset(156, 238),
          const Offset(184, 330),
          const Offset(166, 440),
          const Offset(198, 560),
          const Offset(186, 760),
          ...rightFlankUp(body, peak),
        ]
      ),
      (
        'cap',
        const [
          Offset(160, 72),
          Offset(146, 98),
          Offset(150, 110),
          Offset(158, 104),
          Offset(166, 116),
          Offset(174, 102),
          Offset(180, 108),
          Offset(172, 88)
        ]
      ),
    ],
    foothills: const [
      ('hill', Rect.fromLTRB(-280, 650, 90, 830)),
      ('hill', Rect.fromLTRB(250, 670, 600, 840)),
    ],
    corners: const [
      Offset(22, 716),
      Offset(276, 660),
      Offset(70, 540),
      Offset(236, 400),
      Offset(110, 250),
      Offset(160, 86),
    ],
    fillets: const [80, 70, 58, 46],
  );
}();

/// Candidate 2 — one big peak over a wide plain.
final c2 = () {
  const peak = Offset(162, 66);
  final body = concaveSilhouette(
      peak: peak, baseY: 690, top: 32, spread: 250, power: 1.1);
  return Candidate(
    id: 'c2',
    title: 'Candidate 2 — one big peak, wide plain',
    body: body,
    backLayers: [
      (
        'far',
        const [
          Offset(-260, 760),
          Offset(-260, 610),
          Offset(-160, 560),
          Offset(-90, 590),
          Offset(-20, 545),
          Offset(60, 600),
          Offset(250, 600),
          Offset(330, 540),
          Offset(410, 575),
          Offset(480, 548),
          Offset(580, 600),
          Offset(580, 760)
        ]
      ),
    ],
    faces: [
      (
        'shadow',
        [
          peak,
          const Offset(152, 160),
          const Offset(170, 252),
          const Offset(150, 362),
          const Offset(178, 470),
          const Offset(160, 590),
          const Offset(186, 690),
          ...rightFlankUp(body, peak),
        ]
      ),
      // A crease on the lit face: one flat darker facet.
      (
        'crease',
        const [
          Offset(120, 200),
          Offset(96, 310),
          Offset(70, 420),
          Offset(104, 360),
          Offset(126, 262)
        ]
      ),
      (
        'cap',
        const [
          Offset(162, 66),
          Offset(148, 92),
          Offset(154, 102),
          Offset(162, 96),
          Offset(170, 108),
          Offset(178, 94),
          Offset(184, 100),
          Offset(174, 82)
        ]
      ),
    ],
    // The plain: one wide, very flat foothill across the whole foot.
    foothills: const [
      ('plain', Rect.fromLTRB(-420, 650, 740, 900)),
    ],
    corners: const [
      Offset(16, 720),
      Offset(300, 690),
      Offset(80, 560),
      Offset(250, 420),
      Offset(120, 280),
      Offset(190, 150),
      Offset(162, 82),
    ],
    fillets: const [80, 70, 56, 40, 26],
  );
}();

final candidates = [c1, c2];
