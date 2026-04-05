import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import 'page_flip_gutter_shadow.dart';
import 'page_flip_types.dart';

final class PageFlipPainter extends CustomPainter {
  const PageFlipPainter({
    required this.pageImages,
    required this.pageImageVersion,
    required this.rightPageIndex,
    required this.pageCount,
    required this.pageSize,
    required this.scene,
    required this.staticGutterDensity,
    required this.bookColor,
    required this.pageBackgroundColor,
    required this.borderColor,
  });

  final Map<int, ui.Image> pageImages;
  final int pageImageVersion;
  final int rightPageIndex;
  final int pageCount;
  final Size pageSize;
  final FlipScene? scene;
  final PageDensity staticGutterDensity;
  final Color bookColor;
  final Color pageBackgroundColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pageWidth = size.width / 2;
    final pageHeight = size.height;
    final currentRightPageIndex = rightPageIndex;
    final currentLeftPageIndex = rightPageIndex + 1;

    final bookRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final bookPaint = Paint()..color = bookColor;
    canvas.drawRRect(bookRect, bookPaint);

    if (scene != null) {
      final bottomPageIndex = scene!.direction == FlipDirection.back
          ? rightPageIndex + 3
          : rightPageIndex - 2;
      final flippingPageIndex = scene!.direction == FlipDirection.back
          ? rightPageIndex + 2
          : rightPageIndex - 1;
      final isHard = scene!.density == PageDensity.hard;

      if (isHard) {
        _drawHardBaseStaticPage(
          canvas,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          currentLeftPageIndex: currentLeftPageIndex,
          currentRightPageIndex: currentRightPageIndex,
          scene: scene!,
        );
      } else {
        _drawLeftPageLayer(
          canvas,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          currentLeftPageIndex: currentLeftPageIndex,
          currentRightPageIndex: currentRightPageIndex,
          scene: scene!,
          isHard: isHard,
        );
        _drawRightPageLayer(
          canvas,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          currentLeftPageIndex: currentLeftPageIndex,
          currentRightPageIndex: currentRightPageIndex,
          scene: scene!,
          isHard: isHard,
        );
      }

      final bottomImage = _imageForPage(bottomPageIndex);
      if (bottomPageIndex >= 0 && bottomPageIndex < pageCount) {
        if (isHard) {
          _drawStaticPage(
            canvas,
            rect: scene!.direction == FlipDirection.forward
                ? Rect.fromLTWH(pageWidth, 0, pageWidth, pageHeight)
                : Rect.fromLTWH(0, 0, pageWidth, pageHeight),
            image: bottomImage,
            pageNumber: bottomPageIndex,
            isVisible: true,
          );
        } else {
          _drawBottomPage(
            canvas,
            image: bottomImage,
            pageIndex: bottomPageIndex,
            scene: scene!,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
          );
        }
      }

      _drawBookShadow(
        canvas,
        size: size,
        pageWidth: pageWidth,
        density: staticGutterDensity,
      );

      final shadow = scene!.shadow;
      if (shadow != null && isHard) {
        _drawHardOuterShadow(
          canvas,
          shadow: shadow,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
        );
        _drawHardInnerShadow(
          canvas,
          shadow: shadow,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
        );
      }

      if (isHard) {
        _drawHardTopStaticPage(
          canvas,
          pageWidth: pageWidth,
          pageHeight: pageHeight,
          currentLeftPageIndex: currentLeftPageIndex,
          currentRightPageIndex: currentRightPageIndex,
          scene: scene!,
        );
      }

      final flippingImage = _imageForPage(flippingPageIndex);
      if (flippingPageIndex >= 0 && flippingPageIndex < pageCount) {
        if (isHard) {
          _drawHardPage(
            canvas,
            image: flippingImage,
            pageIndex: flippingPageIndex,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            isLeftPage: scene!.direction == FlipDirection.forward,
            angleDegrees: scene!.hardAngle,
          );
        } else {
          _drawFlippingPage(
            canvas,
            image: flippingImage,
            pageIndex: flippingPageIndex,
            scene: scene!,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
          );
        }
      }

      if (shadow != null) {
        if (!isHard) {
          _drawOuterShadow(
            canvas,
            shadow: shadow,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
          );
          _drawInnerShadow(
            canvas,
            shadow: shadow,
            pageRect: scene!.pageRect,
            pageWidth: pageWidth,
            pageHeight: pageHeight,
          );
        }
      }
    } else {
      _drawStaticPage(
        canvas,
        rect: Rect.fromLTWH(0, 0, pageWidth, pageHeight),
        image: _imageForPage(currentLeftPageIndex),
        pageNumber: currentLeftPageIndex,
        isVisible: true,
      );
      _drawStaticPage(
        canvas,
        rect: Rect.fromLTWH(pageWidth, 0, pageWidth, pageHeight),
        image: _imageForPage(currentRightPageIndex),
        pageNumber: currentRightPageIndex,
        isVisible: true,
      );
    }
  }

  void _drawHardBaseStaticPage(
    Canvas canvas, {
    required double pageWidth,
    required double pageHeight,
    required int currentLeftPageIndex,
    required int currentRightPageIndex,
    required FlipScene scene,
  }) {
    if (scene.direction == FlipDirection.forward) {
      _drawStaticPage(
        canvas,
        rect: Rect.fromLTWH(0, 0, pageWidth, pageHeight),
        image: _imageForPage(currentLeftPageIndex),
        pageNumber: currentLeftPageIndex,
        isVisible: true,
      );
      return;
    }

    _drawStaticPage(
      canvas,
      rect: Rect.fromLTWH(pageWidth, 0, pageWidth, pageHeight),
      image: _imageForPage(currentRightPageIndex),
      pageNumber: currentRightPageIndex,
      isVisible: true,
    );
  }

  void _drawHardTopStaticPage(
    Canvas canvas, {
    required double pageWidth,
    required double pageHeight,
    required int currentLeftPageIndex,
    required int currentRightPageIndex,
    required FlipScene scene,
  }) {
    if (scene.direction == FlipDirection.forward) {
      _drawHardPage(
        canvas,
        image: _imageForPage(currentRightPageIndex),
        pageIndex: currentRightPageIndex,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        isLeftPage: false,
        angleDegrees: 180 + scene.hardAngle,
      );
      return;
    }

    _drawHardPage(
      canvas,
      image: _imageForPage(currentLeftPageIndex),
      pageIndex: currentLeftPageIndex,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      isLeftPage: true,
      angleDegrees: 180 + scene.hardAngle,
    );
  }

  void _drawLeftPageLayer(
    Canvas canvas, {
    required double pageWidth,
    required double pageHeight,
    required int currentLeftPageIndex,
    required int currentRightPageIndex,
    required FlipScene scene,
    required bool isHard,
  }) {
    if (isHard && scene.direction == FlipDirection.back) {
      _drawHardPage(
        canvas,
        image: _imageForPage(currentLeftPageIndex),
        pageIndex: currentLeftPageIndex,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        isLeftPage: true,
        angleDegrees: 180 + scene.hardAngle,
      );
      return;
    }

    _drawStaticPage(
      canvas,
      rect: Rect.fromLTWH(0, 0, pageWidth, pageHeight),
      image: _imageForPage(currentLeftPageIndex),
      pageNumber: currentLeftPageIndex,
      isVisible: true,
    );
  }

  void _drawRightPageLayer(
    Canvas canvas, {
    required double pageWidth,
    required double pageHeight,
    required int currentLeftPageIndex,
    required int currentRightPageIndex,
    required FlipScene scene,
    required bool isHard,
  }) {
    if (isHard && scene.direction == FlipDirection.forward) {
      _drawHardPage(
        canvas,
        image: _imageForPage(currentRightPageIndex),
        pageIndex: currentRightPageIndex,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
        isLeftPage: false,
        angleDegrees: 180 + scene.hardAngle,
      );
      return;
    }

    _drawStaticPage(
      canvas,
      rect: Rect.fromLTWH(pageWidth, 0, pageWidth, pageHeight),
      image: _imageForPage(currentRightPageIndex),
      pageNumber: currentRightPageIndex,
      isVisible: true,
    );
  }

  ui.Image? _imageForPage(int pageIndex) => pageImages[pageIndex];

  void _drawStaticPage(
    Canvas canvas, {
    required Rect rect,
    required ui.Image? image,
    required int pageNumber,
    required bool isVisible,
  }) {
    if (!isVisible || pageNumber < 0 || pageNumber >= pageCount) {
      return;
    }

    _drawPageSurface(canvas, rect);
    if (image != null) {
      _drawImageIntoRect(canvas, image, rect);
    } else {
      _drawFallbackPage(canvas, rect, pageNumber + 1);
    }
  }

  void _drawBottomPage(
    Canvas canvas, {
    required ui.Image? image,
    required int pageIndex,
    required FlipScene scene,
    required double pageWidth,
    required double pageHeight,
  }) {
    final pageOrigin = _convertToBookSpace(
      scene.bottomPagePosition,
      scene.direction,
      pageWidth,
    );
    canvas.save();
    canvas.clipPath(
      _pathFromOffsets(
        scene.bottomClipArea
            .map(
              (point) => point == null
                  ? null
                  : _convertToBookSpace(point, scene.direction, pageWidth),
            )
            .toList(growable: false),
      ),
    );
    final rect = Rect.fromLTWH(
      pageOrigin.dx,
      pageOrigin.dy,
      pageWidth,
      pageHeight,
    );
    _drawPageSurface(canvas, rect);
    if (image != null) {
      _drawImageIntoRect(canvas, image, rect);
    } else {
      _drawFallbackPage(canvas, rect, pageIndex + 1);
    }
    canvas.restore();
  }

  void _drawFlippingPage(
    Canvas canvas, {
    required ui.Image? image,
    required int pageIndex,
    required FlipScene scene,
    required double pageWidth,
    required double pageHeight,
  }) {
    final pageOrigin = _convertToBookSpace(
      scene.activeCorner,
      scene.direction,
      pageWidth,
    );
    canvas.save();
    canvas.clipPath(
      _pathFromOffsets(
        scene.flippingClipArea
            .map(
              (point) => point == null
                  ? null
                  : _convertToBookSpace(point, scene.direction, pageWidth),
            )
            .toList(growable: false),
      ),
    );
    canvas.translate(pageOrigin.dx, pageOrigin.dy);
    canvas.rotate(scene.angle);

    final pageRect = Rect.fromLTWH(0, 0, pageWidth, pageHeight);

    _drawPageSurface(canvas, pageRect);
    if (image != null) {
      _drawImageIntoRect(canvas, image, pageRect);
    } else {
      _drawFallbackPage(canvas, pageRect, pageIndex + 1);
    }
    canvas.restore();
  }

  void _drawHardPage(
    Canvas canvas, {
    required ui.Image? image,
    required int pageIndex,
    required double pageWidth,
    required double pageHeight,
    required bool isLeftPage,
    required double angleDegrees,
  }) {
    if (pageIndex < 0 || pageIndex >= pageCount) {
      return;
    }

    _drawHardPlane(
      canvas,
      planeX: isLeftPage ? 0 : pageWidth,
      planeWidth: pageWidth,
      planeHeight: pageHeight,
      rotationOriginX: isLeftPage ? pageWidth : 0,
      angleDegrees: angleDegrees,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      hideBackface: true,
      painter: (canvas, rect) {
        _drawPageSurface(canvas, rect);
        if (image != null) {
          _drawImageIntoRect(canvas, image, rect);
        } else {
          _drawFallbackPage(canvas, rect, pageIndex + 1);
        }
      },
    );
  }

  void _drawBookShadow(
    Canvas canvas, {
    required Size size,
    required double pageWidth,
    required PageDensity density,
  }) {
    paintBookGutterShadow(
      canvas,
      size: size,
      pageWidth: pageWidth,
      density: density,
    );
  }

  void _drawOuterShadow(
    Canvas canvas, {
    required ShadowData shadow,
    required double pageWidth,
    required double pageHeight,
  }) {
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, pageWidth * 2, pageHeight));
    final shadowPosition = _convertToBookSpace(
      shadow.position,
      shadow.direction,
      pageWidth,
    );
    canvas.translate(shadowPosition.dx, shadowPosition.dy);
    canvas.rotate(math.pi + shadow.angle + math.pi / 2);

    if (shadow.direction == FlipDirection.forward) {
      canvas.translate(0, -100);
    } else {
      canvas.translate(-shadow.width, -100);
    }

    final shader = ui.Gradient.linear(
      Offset.zero,
      Offset(shadow.width, 0),
      shadow.direction == FlipDirection.forward
          ? [
              Color.fromRGBO(0, 0, 0, shadow.opacity),
              const Color.fromRGBO(0, 0, 0, 0),
            ]
          : [
              const Color.fromRGBO(0, 0, 0, 0),
              Color.fromRGBO(0, 0, 0, shadow.opacity),
            ],
    );

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, shadow.width, pageHeight * 2), paint);
    canvas.restore();
  }

  void _drawHardOuterShadow(
    Canvas canvas, {
    required ShadowData shadow,
    required double pageWidth,
    required double pageHeight,
  }) {
    final progress = shadow.progress > 100
        ? 200 - shadow.progress
        : shadow.progress;
    final shadowWidth = (((100 - progress) * (2.5 * pageWidth)) / 100 + 20)
        .clamp(0.0, pageWidth);
    final shouldMirror =
        (shadow.direction == FlipDirection.forward && shadow.progress > 100) ||
        (shadow.direction == FlipDirection.back && shadow.progress <= 100);

    _drawHardPlane(
      canvas,
      planeX: pageWidth,
      planeWidth: shadowWidth,
      planeHeight: pageHeight,
      rotationOriginX: 0,
      angleDegrees: shouldMirror ? 180 : 0,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      painter: (canvas, rect) {
        final shader = ui.Gradient.linear(
          rect.topRight,
          rect.topLeft,
          [
            Color.fromRGBO(0, 0, 0, shadow.opacity),
            const Color.fromRGBO(0, 0, 0, 0),
          ],
          const [0.05, 1],
        );
        canvas.drawRect(rect, Paint()..shader = shader);
      },
    );
  }

  void _drawHardInnerShadow(
    Canvas canvas, {
    required ShadowData shadow,
    required double pageWidth,
    required double pageHeight,
  }) {
    final progress = shadow.progress > 100
        ? 200 - shadow.progress
        : shadow.progress;
    final shadowWidth = (((100 - progress) * (2.5 * pageWidth)) / 100 + 20)
        .clamp(0.0, pageWidth);
    final shouldMirror =
        (shadow.direction == FlipDirection.forward && shadow.progress > 100) ||
        (shadow.direction == FlipDirection.back && shadow.progress <= 100);

    _drawHardPlane(
      canvas,
      planeX: pageWidth,
      planeWidth: shadowWidth,
      planeHeight: pageHeight,
      rotationOriginX: 0,
      angleDegrees: shouldMirror ? 180 : 0,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
      painter: (canvas, rect) {
        final shader = ui.Gradient.linear(
          rect.topLeft,
          rect.topRight,
          [
            Color.fromRGBO(0, 0, 0, shadow.opacity * progress / 100),
            const Color.fromRGBO(0, 0, 0, 0),
          ],
          const [0.05, 1],
        );
        canvas.drawRect(rect, Paint()..shader = shader);
      },
    );
  }

  void _drawHardPlane(
    Canvas canvas, {
    required double planeX,
    required double planeWidth,
    required double planeHeight,
    required double rotationOriginX,
    required double angleDegrees,
    required double pageWidth,
    required double pageHeight,
    required void Function(Canvas canvas, Rect rect) painter,
    bool hideBackface = false,
  }) {
    final radians = -angleDegrees * math.pi / 180;
    if (hideBackface && math.cos(radians) <= 0) {
      return;
    }

    canvas.save();
    canvas.transform(
      _hardPlaneMatrix(
        planeX: planeX,
        rotationOriginX: rotationOriginX,
        radians: radians,
        pageWidth: pageWidth,
        pageHeight: pageHeight,
      ).storage,
    );
    painter(canvas, Rect.fromLTWH(0, 0, planeWidth, planeHeight));
    canvas.restore();
  }

  vector.Matrix4 _hardPlaneMatrix({
    required double planeX,
    required double rotationOriginX,
    required double radians,
    required double pageWidth,
    required double pageHeight,
  }) {
    final perspectiveOrigin = Offset(pageWidth, pageHeight / 2);
    final perspective = vector.Matrix4.identity()..setEntry(3, 2, 1 / 2000);
    return vector.Matrix4.identity()
      ..translateByDouble(perspectiveOrigin.dx, perspectiveOrigin.dy, 0, 1)
      ..multiply(perspective)
      ..translateByDouble(-perspectiveOrigin.dx, -perspectiveOrigin.dy, 0, 1)
      ..translateByDouble(planeX, 0, 0, 1)
      ..translateByDouble(rotationOriginX, 0, 0, 1)
      ..rotateY(radians)
      ..translateByDouble(-rotationOriginX, 0, 0, 1);
  }

  void _drawInnerShadow(
    Canvas canvas, {
    required ShadowData shadow,
    required RectPoints pageRect,
    required double pageWidth,
    required double pageHeight,
  }) {
    final innerShadowWidth = (shadow.width * 3) / 4;
    final shadowPosition = _convertToBookSpace(
      shadow.position,
      shadow.direction,
      pageWidth,
    );
    canvas.save();
    canvas.clipPath(
      _pathFromOffsets([
        _convertToBookSpace(pageRect.topLeft, shadow.direction, pageWidth),
        _convertToBookSpace(pageRect.topRight, shadow.direction, pageWidth),
        _convertToBookSpace(pageRect.bottomRight, shadow.direction, pageWidth),
        _convertToBookSpace(pageRect.bottomLeft, shadow.direction, pageWidth),
      ]),
    );
    canvas.translate(shadowPosition.dx, shadowPosition.dy);
    canvas.rotate(math.pi + shadow.angle + math.pi / 2);

    if (shadow.direction == FlipDirection.forward) {
      canvas.translate(-innerShadowWidth, -100);
    } else {
      canvas.translate(0, -100);
    }

    final shader = ui.Gradient.linear(
      Offset.zero,
      Offset(innerShadowWidth, 0),
      shadow.direction == FlipDirection.forward
          ? [
              const Color.fromRGBO(0, 0, 0, 0),
              Color.fromRGBO(0, 0, 0, shadow.opacity),
              const Color.fromRGBO(0, 0, 0, 0.05),
              Color.fromRGBO(0, 0, 0, shadow.opacity),
            ]
          : [
              Color.fromRGBO(0, 0, 0, shadow.opacity),
              const Color.fromRGBO(0, 0, 0, 0.05),
              Color.fromRGBO(0, 0, 0, shadow.opacity),
              const Color.fromRGBO(0, 0, 0, 0),
            ],
      shadow.direction == FlipDirection.forward
          ? const [0, 0.7, 0.9, 1]
          : const [0, 0.1, 0.3, 1],
    );

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, innerShadowWidth, pageHeight * 2),
      paint,
    );
    canvas.restore();
  }

  Offset _convertToBookSpace(
    Offset point,
    FlipDirection direction,
    double pageWidth,
  ) {
    final x = direction == FlipDirection.forward
        ? point.dx + pageWidth
        : pageWidth - point.dx;
    return Offset(x, point.dy);
  }

  Path _pathFromOffsets(List<Offset?> points) {
    final path = Path();
    final filtered = points.whereType<Offset>().toList(growable: false);
    if (filtered.isEmpty) {
      return path;
    }
    path.moveTo(filtered.first.dx, filtered.first.dy);
    for (final point in filtered.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    return path;
  }

  void _drawPageSurface(Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = pageBackgroundColor);
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = borderColor,
    );
  }

  void _drawImageIntoRect(Canvas canvas, ui.Image image, Rect rect) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  void _drawFallbackPage(Canvas canvas, Rect rect, int pageNumber) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: '$pageNumber',
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: Color(0xFF343434),
        ),
      ),
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant PageFlipPainter oldDelegate) {
    return oldDelegate.pageImages != pageImages ||
        oldDelegate.pageImageVersion != pageImageVersion ||
        oldDelegate.rightPageIndex != rightPageIndex ||
        oldDelegate.pageCount != pageCount ||
        oldDelegate.pageSize != pageSize ||
        oldDelegate.scene != scene ||
        oldDelegate.staticGutterDensity != staticGutterDensity ||
        oldDelegate.bookColor != bookColor ||
        oldDelegate.pageBackgroundColor != pageBackgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}
