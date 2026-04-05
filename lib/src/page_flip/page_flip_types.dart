import 'dart:ui';

enum FlipDirection { forward, back }

enum FlipCorner { top, bottom }

enum PageDensity { soft, hard }

final class BookRect {
  const BookRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.pageWidth,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double pageWidth;
}

final class RectPoints {
  const RectPoints({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRight;
}

final class ShadowData {
  const ShadowData({
    required this.position,
    required this.angle,
    required this.width,
    required this.opacity,
    required this.direction,
    required this.progress,
  });

  final Offset position;
  final double angle;
  final double width;
  final double opacity;
  final FlipDirection direction;
  final double progress;
}

final class FlipScene {
  const FlipScene({
    required this.direction,
    required this.corner,
    required this.density,
    required this.pageRect,
    required this.bottomClipArea,
    required this.flippingClipArea,
    required this.bottomPagePosition,
    required this.activeCorner,
    required this.pagePosition,
    required this.angle,
    required this.hardAngle,
    required this.progress,
    required this.shadow,
  });

  final FlipDirection direction;
  final FlipCorner corner;
  final PageDensity density;
  final RectPoints pageRect;
  final List<Offset?> bottomClipArea;
  final List<Offset?> flippingClipArea;
  final Offset bottomPagePosition;
  final Offset activeCorner;
  final Offset pagePosition;
  final double angle;
  final double hardAngle;
  final double progress;
  final ShadowData? shadow;
}

final class PageFlipSnapshot {
  const PageFlipSnapshot({
    required this.rightPageIndex,
    required this.pageCount,
    required this.isInteracting,
  });

  final int rightPageIndex;
  final int pageCount;
  final bool isInteracting;
}
