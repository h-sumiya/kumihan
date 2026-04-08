import 'dart:math' as math;
import 'dart:ui';

typedef Segment = ({Offset start, Offset end});

double distanceBetween(Offset? a, Offset? b) {
  if (a == null || b == null) {
    return double.infinity;
  }
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  return math.sqrt(dx * dx + dy * dy);
}

double angleBetweenSegments(Segment a, Segment b) {
  final a1 = a.start.dy - a.end.dy;
  final a2 = b.start.dy - b.end.dy;
  final b1 = a.end.dx - a.start.dx;
  final b2 = b.end.dx - b.start.dx;
  return math.acos(
    (a1 * a2 + b1 * b2) /
        (math.sqrt(a1 * a1 + b1 * b1) * math.sqrt(a2 * a2 + b2 * b2)),
  );
}

Offset? pointInRect(Rect rect, Offset? point) {
  if (point == null) {
    return null;
  }
  if (rect.contains(point)) {
    return point;
  }
  return null;
}

Offset rotatePoint(Offset transformedPoint, Offset startPoint, double angle) {
  return Offset(
    transformedPoint.dx * math.cos(angle) +
        transformedPoint.dy * math.sin(angle) +
        startPoint.dx,
    transformedPoint.dy * math.cos(angle) -
        transformedPoint.dx * math.sin(angle) +
        startPoint.dy,
  );
}

Offset limitPointToCircle({
  required Offset startPoint,
  required double radius,
  required Offset limitedPoint,
}) {
  if (distanceBetween(startPoint, limitedPoint) <= radius) {
    return limitedPoint;
  }

  final a = startPoint.dx;
  final b = startPoint.dy;
  final n = limitedPoint.dx;
  final m = limitedPoint.dy;

  var x =
      math.sqrt(
        (math.pow(radius, 2) * math.pow(a - n, 2)) /
            (math.pow(a - n, 2) + math.pow(b - m, 2)),
      ) +
      a;
  if (limitedPoint.dx < 0) {
    x *= -1;
  }

  var y = ((x - a) * (b - m)) / (a - n) + b;
  if (a - n + b == 0) {
    y = radius;
  }

  return Offset(x, y);
}

Offset? intersectSegmentsWithinRect(Rect rect, Segment one, Segment two) {
  return pointInRect(rect, intersectLines(one, two));
}

Offset? intersectLines(Segment one, Segment two) {
  final a1 = one.start.dy - one.end.dy;
  final a2 = two.start.dy - two.end.dy;

  final b1 = one.end.dx - one.start.dx;
  final b2 = two.end.dx - two.start.dx;

  final c1 = one.start.dx * one.end.dy - one.end.dx * one.start.dy;
  final c2 = two.start.dx * two.end.dy - two.end.dx * two.start.dy;

  final det1 = a1 * c2 - a2 * c1;
  final det2 = b1 * c2 - b2 * c1;

  final denominator = a1 * b2 - a2 * b1;
  final x = -((c1 * b2 - c2 * b1) / denominator);
  final y = -((a1 * c2 - a2 * c1) / denominator);

  if (x.isFinite && y.isFinite) {
    return Offset(x, y);
  }

  if ((det1 - det2).abs() < 0.1) {
    throw StateError('Segment included');
  }

  return null;
}
