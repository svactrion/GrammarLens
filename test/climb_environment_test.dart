import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_scene.dart';

double _distance(Rect r, Offset p) {
  final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
  final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
  return math.sqrt(dx * dx + dy * dy);
}

/// Batch 3c f: Green Slope's environment items, with the stop markers 4–6
/// objects in the scene (Batch 0 decision 6), clear of the trail, the
/// avatar and every month's markers.
void main() {
  const boxes = {
    'pine': Rect.fromLTRB(-16, -58, 16, 0),
    'shrub': Rect.fromLTRB(-22, -22, 22, 0),
  };
  const markerBox = Rect.fromLTRB(-28, -30, 30, 20);
  final items = ClimbScene.environment;

  test('a pine and a shrub with wildflowers', () {
    expect(items.map((i) => i.kind), ['pine', 'shrub']);
  });

  for (final days in [28, 29, 30, 31]) {
    test('$days-day month: 4–6 objects in the scene', () {
      final count = ClimbRoute(days).markers.length + items.length;
      expect(count, inInclusiveRange(4, 6));
    });

    test('$days-day month: items clear of the trail, the avatar and markers',
        () {
      final route = ClimbRoute(days);
      final metric = route.path.computeMetrics().single;
      for (final item in items) {
        final box = boxes[item.kind]!.shift(item.base);
        expect(
            ClimbScene.onGround(box.bottomLeft + const Offset(3, -2)), isTrue);
        expect(ClimbScene.onGround(box.bottomRight + const Offset(-3, -2)),
            isTrue);
        expect(box.left, greaterThanOrEqualTo(4));
        expect(box.right, lessThanOrEqualTo(316));
        for (var s = 0.0; s <= metric.length; s += 2) {
          final p = metric.getTangentForOffset(s)!.position;
          expect(_distance(box, p), greaterThanOrEqualTo(13 + 8),
              reason: '${item.kind} near the trail at $p');
          expect(
              box.overlaps(
                  const Rect.fromLTRB(-29, -55, 29, 3).shift(p).inflate(2)),
              isFalse,
              reason: '${item.kind} in the avatar\'s space at $p');
        }
        for (final m in route.markers) {
          expect(box.overlaps(markerBox.shift(m.origin).inflate(6)), isFalse,
              reason: '${item.kind} on the day-${m.day} marker');
        }
      }
    });
  }
}
