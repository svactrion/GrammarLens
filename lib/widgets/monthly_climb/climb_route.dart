import 'dart:ui';

/// Logical scene coordinates. Painting and movement use the same cubic Path.
class ClimbRoute {
  static const sceneSize = Size(320, 740);
  final int days;
  late final Path path;
  late final List<PathMetric> _segments;
  late final List<int> _stops;

  ClimbRoute(this.days) {
    if (days < 28 || days > 31) {
      throw ArgumentError.value(days, 'days', 'Expected 28–31');
    }
    _stops = [0, 7, 14, 21, 28, if (days > 28) days];
    final xs = [
      88.0,
      239.0,
      91.0,
      209.0,
      days == 28 ? 160.0 : 128.0,
      if (days > 28) 160.0
    ];
    path = Path()..moveTo(xs.first, _y(0));
    _segments = [];
    for (var i = 1; i < _stops.length; i++) {
      final from = Offset(xs[i - 1], _y(_stops[i - 1].toDouble()));
      final to = Offset(xs[i], _y(_stops[i].toDouble()));
      final middle = (from.dy + to.dy) / 2;
      final segment = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, middle, to.dx, middle, to.dx, to.dy);
      _segments.add(segment.computeMetrics().single);
      path.cubicTo(from.dx, middle, to.dx, middle, to.dx, to.dy);
    }
  }

  double _y(double day) => 690 - 570 * day / days;

  Offset pointAt(double day) {
    final bounded = day.clamp(0.0, days.toDouble());
    var i = 0;
    while (i < _segments.length - 1 && bounded > _stops[i + 1]) {
      i++;
    }
    final fraction = (bounded - _stops[i]) / (_stops[i + 1] - _stops[i]);
    final metric = _segments[i];
    return metric.getTangentForOffset(metric.length * fraction)!.position;
  }
}
