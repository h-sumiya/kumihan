import 'dart:math' as math;
import 'dart:ui';

import 'page_flip_math.dart';
import 'page_flip_types.dart';

final class FlipCalculation {
  FlipCalculation({
    required this.direction,
    required this.corner,
    required double pageWidth,
    required double pageHeight,
  }) : _pageWidth = pageWidth,
       _pageHeight = pageHeight;

  final FlipDirection direction;
  final FlipCorner corner;

  final double _pageWidth;
  final double _pageHeight;

  double _angle = 0;
  Offset _position = Offset.zero;
  RectPoints _rect = const RectPoints(
    topLeft: Offset.zero,
    topRight: Offset.zero,
    bottomLeft: Offset.zero,
    bottomRight: Offset.zero,
  );

  Offset? _topIntersectPoint;
  Offset? _sideIntersectPoint;
  Offset? _bottomIntersectPoint;

  bool calc(Offset localPosition) {
    try {
      _position = _calcAngleAndPosition(localPosition);
      _calculateIntersectPoint(_position);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<Offset?> getFlippingClipArea() {
    final result = <Offset?>[];
    var clipBottom = false;

    result.add(_rect.topLeft);
    result.add(_topIntersectPoint);

    if (_sideIntersectPoint == null) {
      clipBottom = true;
    } else {
      result.add(_sideIntersectPoint!);

      if (_bottomIntersectPoint == null) {
        clipBottom = false;
      }
    }

    result.add(_bottomIntersectPoint);

    if (clipBottom || corner == FlipCorner.bottom) {
      result.add(_rect.bottomLeft);
    }

    return result;
  }

  List<Offset?> getBottomClipArea() {
    final result = <Offset?>[];

    result.add(_topIntersectPoint);

    if (corner == FlipCorner.top) {
      result.add(Offset(_pageWidth, 0));
    } else {
      if (_topIntersectPoint != null) {
        result.add(Offset(_pageWidth, 0));
      }
      result.add(Offset(_pageWidth, _pageHeight));
    }

    if (_sideIntersectPoint != null) {
      if (distanceBetween(_sideIntersectPoint, _topIntersectPoint) >= 10) {
        result.add(_sideIntersectPoint!);
      }
    } else if (corner == FlipCorner.top) {
      result.add(Offset(_pageWidth, _pageHeight));
    }

    result.add(_bottomIntersectPoint);
    result.add(_topIntersectPoint);

    return result;
  }

  double getAngle() {
    if (direction == FlipDirection.forward) {
      return -_angle;
    }
    return _angle;
  }

  RectPoints getRect() => _rect;

  Offset getPosition() => _position;

  Offset getActiveCorner() {
    if (direction == FlipDirection.forward) {
      return _rect.topLeft;
    }
    return _rect.topRight;
  }

  double getFlippingProgress() {
    return (((_position.dx - _pageWidth) / (2 * _pageWidth)) * 100).abs();
  }

  Offset getBottomPagePosition() {
    if (direction == FlipDirection.back) {
      return Offset(_pageWidth, 0);
    }
    return Offset.zero;
  }

  Offset getShadowStartPoint() {
    if (corner == FlipCorner.top) {
      return _topIntersectPoint!;
    }
    return _sideIntersectPoint ?? _topIntersectPoint!;
  }

  double getShadowAngle() {
    final angle = angleBetweenSegments(
      (
        start: getShadowStartPoint(),
        end:
            _sideIntersectPoint != null &&
                getShadowStartPoint() != _sideIntersectPoint
            ? _sideIntersectPoint!
            : _bottomIntersectPoint!,
      ),
      (start: Offset.zero, end: Offset(_pageWidth, 0)),
    );

    if (direction == FlipDirection.forward) {
      return angle;
    }
    return math.pi - angle;
  }

  Offset _calcAngleAndPosition(Offset position) {
    var result = position;

    _updateAngleAndGeometry(result);

    if (corner == FlipCorner.top) {
      result = _checkPositionAtCenterLine(
        checkedPosition: result,
        centerOne: Offset.zero,
        centerTwo: Offset(0, _pageHeight),
      );
    } else {
      result = _checkPositionAtCenterLine(
        checkedPosition: result,
        centerOne: Offset(0, _pageHeight),
        centerTwo: Offset.zero,
      );
    }

    if ((result.dx - _pageWidth).abs() < 1 && result.dy.abs() < 1) {
      throw StateError('Point is too small');
    }

    return result;
  }

  void _updateAngleAndGeometry(Offset position) {
    _angle = _calculateAngle(position);
    _rect = _getPageRect(position);
  }

  double _calculateAngle(Offset position) {
    final left = _pageWidth - position.dx + 1;
    final top = corner == FlipCorner.bottom
        ? _pageHeight - position.dy
        : position.dy;

    var angle = 2 * math.acos(left / math.sqrt(top * top + left * left));

    if (top < 0) {
      angle = -angle;
    }

    final da = math.pi - angle;
    if (!angle.isFinite || (da >= 0 && da < 0.003)) {
      throw StateError('The G point is too small');
    }

    if (corner == FlipCorner.bottom) {
      angle = -angle;
    }

    return angle;
  }

  RectPoints _getPageRect(Offset localPosition) {
    if (corner == FlipCorner.top) {
      return _getRectFromBasePoint(
        const [
          Offset(0, 0),
          Offset(1, 0),
          Offset(0, 1),
          Offset(1, 1),
        ].map((p) => Offset(p.dx * _pageWidth, p.dy * _pageHeight)).toList(),
        localPosition,
      );
    }

    return _getRectFromBasePoint([
      Offset(0, -_pageHeight),
      Offset(_pageWidth, -_pageHeight),
      Offset.zero,
      Offset(_pageWidth, 0),
    ], localPosition);
  }

  RectPoints _getRectFromBasePoint(List<Offset> points, Offset localPosition) {
    return RectPoints(
      topLeft: rotatePoint(points[0], localPosition, _angle),
      topRight: rotatePoint(points[1], localPosition, _angle),
      bottomLeft: rotatePoint(points[2], localPosition, _angle),
      bottomRight: rotatePoint(points[3], localPosition, _angle),
    );
  }

  void _calculateIntersectPoint(Offset position) {
    final boundRect = Rect.fromLTWH(-1, -1, _pageWidth + 2, _pageHeight + 2);

    if (corner == FlipCorner.top) {
      _topIntersectPoint = intersectSegmentsWithinRect(
        boundRect,
        (start: position, end: _rect.topRight),
        (start: Offset.zero, end: Offset(_pageWidth, 0)),
      );

      _sideIntersectPoint = intersectSegmentsWithinRect(
        boundRect,
        (start: position, end: _rect.bottomLeft),
        (start: Offset(_pageWidth, 0), end: Offset(_pageWidth, _pageHeight)),
      );

      _bottomIntersectPoint = intersectSegmentsWithinRect(
        boundRect,
        (start: _rect.bottomLeft, end: _rect.bottomRight),
        (start: Offset(0, _pageHeight), end: Offset(_pageWidth, _pageHeight)),
      );
    } else {
      _topIntersectPoint = intersectSegmentsWithinRect(
        boundRect,
        (start: _rect.topLeft, end: _rect.topRight),
        (start: Offset.zero, end: Offset(_pageWidth, 0)),
      );

      _sideIntersectPoint = intersectSegmentsWithinRect(
        boundRect,
        (start: position, end: _rect.topLeft),
        (start: Offset(_pageWidth, 0), end: Offset(_pageWidth, _pageHeight)),
      );

      _bottomIntersectPoint = intersectSegmentsWithinRect(
        boundRect,
        (start: _rect.bottomLeft, end: _rect.bottomRight),
        (start: Offset(0, _pageHeight), end: Offset(_pageWidth, _pageHeight)),
      );
    }
  }

  Offset _checkPositionAtCenterLine({
    required Offset checkedPosition,
    required Offset centerOne,
    required Offset centerTwo,
  }) {
    var result = checkedPosition;

    final limited = limitPointToCircle(
      startPoint: centerOne,
      radius: _pageWidth,
      limitedPoint: result,
    );
    if (limited != result) {
      result = limited;
      _updateAngleAndGeometry(result);
    }

    final radius = math.sqrt(
      math.pow(_pageWidth, 2) + math.pow(_pageHeight, 2),
    );

    var checkPointOne = _rect.bottomRight;
    var checkPointTwo = _rect.topLeft;

    if (corner == FlipCorner.bottom) {
      checkPointOne = _rect.topRight;
      checkPointTwo = _rect.bottomLeft;
    }

    if (checkPointOne.dx <= 0) {
      final bottomPoint = limitPointToCircle(
        startPoint: centerTwo,
        radius: radius,
        limitedPoint: checkPointTwo,
      );

      if (bottomPoint != result) {
        result = bottomPoint;
        _updateAngleAndGeometry(result);
      }
    }

    return result;
  }
}
