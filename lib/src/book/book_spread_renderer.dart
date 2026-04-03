import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../engine/constants.dart';
import '../engine/kumihan_engine.dart';
import '../kumihan_page_paint_context.dart';
import '../kumihan_theme.dart';
import '../kumihan_types.dart';

class BookSpreadRenderer {
  const BookSpreadRenderer({
    required this.engine,
    required this.layout,
    required this.theme,
    required this.spreadMode,
  });

  final KumihanEngine engine;
  final KumihanBookLayoutData layout;
  final KumihanThemeData theme;
  final KumihanSpreadMode spreadMode;

  Size resolvePageSize(Size size) => _resolve(size).rightRect.size;

  _BookSpreadMetrics _resolve(Size size) {
    final fontSize = layout.fontSize.roundToDouble();
    final outerPadding = layout.outerPadding;
    final contentPadding = layout.contentPadding;
    final minPageHeight = fontSize * 6;
    final pageGap = spreadMode == KumihanSpreadMode.doublePage
        ? layout.pageGap
        : 0.0;
    final leftSlotWidth = spreadMode == KumihanSpreadMode.doublePage
        ? math.max(size.width / 2 - outerPadding.left - pageGap, fontSize)
        : 0.0;
    final rightSlotWidth = spreadMode == KumihanSpreadMode.doublePage
        ? math.max(size.width / 2 - outerPadding.right - pageGap, fontSize)
        : math.max(
            size.width - outerPadding.left - outerPadding.right,
            fontSize,
          );
    final pageWidthBase = spreadMode == KumihanSpreadMode.doublePage
        ? math.max(math.min(leftSlotWidth, rightSlotWidth), fontSize)
        : rightSlotWidth;

    final pageWidth = math.max(pageWidthBase, fontSize);

    final headerReservedExtent =
        layout.showTitle && engine.headerTitle.isNotEmpty
        ? math.max(1.85 * fontSize + 20, 0)
        : 0.0;
    final pageNumberReservedExtent = layout.showPageNumber
        ? math.max(2.07 * fontSize, 44)
        : 0.0;
    final desiredTop =
        outerPadding.top + contentPadding.top + headerReservedExtent;
    final desiredBottom =
        outerPadding.bottom + contentPadding.bottom + pageNumberReservedExtent;
    final maxMarginTotal = math.max(size.height - minPageHeight, 0.0);
    final verticalMarginTotal = desiredTop + desiredBottom;
    final verticalFactor =
        verticalMarginTotal > maxMarginTotal && verticalMarginTotal > 0
        ? maxMarginTotal / verticalMarginTotal
        : 1.0;
    final pageMarginTop = desiredTop * verticalFactor;
    final pageMarginBottom = desiredBottom * verticalFactor;
    final pageHeight = math.max(
      size.height - pageMarginTop - pageMarginBottom,
      fontSize,
    );
    final centerX = size.width / 2;
    final leftX = spreadMode == KumihanSpreadMode.doublePage
        ? outerPadding.left +
              _inlineOffset(
                leftSlotWidth - pageWidth,
                layout.leftPageFullPageAlignment,
              )
        : null;
    final rightBaseX = spreadMode == KumihanSpreadMode.doublePage
        ? centerX + pageGap
        : outerPadding.left;
    final rightX =
        rightBaseX +
        _inlineOffset(
          rightSlotWidth - pageWidth,
          layout.rightPageFullPageAlignment,
        );

    final rightRect = Rect.fromLTWH(
      rightX,
      pageMarginTop,
      pageWidth,
      pageHeight,
    );
    final leftRect = spreadMode == KumihanSpreadMode.doublePage
        ? Rect.fromLTWH(leftX!, pageMarginTop, pageWidth, pageHeight)
        : null;

    return _BookSpreadMetrics(
      fontSize: fontSize,
      contentPadding: contentPadding,
      pageMarginBottom: pageMarginBottom,
      outerPadding: outerPadding,
      pageMarginTop: pageMarginTop,
      rightRect: rightRect,
      leftRect: leftRect,
      size: size,
    );
  }

  double _inlineOffset(
    double inlineOverflow,
    KumihanFullPageAlignment alignment,
  ) {
    final overflow = math.max(inlineOverflow, 0.0);
    return switch (alignment) {
      KumihanFullPageAlignment.left => 0.0,
      KumihanFullPageAlignment.center => overflow / 2,
      KumihanFullPageAlignment.right => overflow,
    };
  }

  void paint(
    ui.Canvas canvas,
    Size size, {
    required int currentPage,
    required int totalPages,
  }) {
    final metrics = _resolve(size);
    final lastPage = math.max(totalPages - 1, 0);

    canvas.drawRect(Offset.zero & size, Paint()..color = theme.paperColor);

    if (spreadMode == KumihanSpreadMode.doublePage) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        Paint()
          ..color = engine.fontColor.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
    }

    if (spreadMode == KumihanSpreadMode.doublePage) {
      if (currentPage > 0) {
        engine.paintPage(
          canvas,
          currentPage - 1,
          PagePaintContext(
            contentRect: metrics.rightRect,
            backPage: true,
            recordInteractiveRegions: false,
          ),
        );
      }
      if (currentPage < lastPage - 1 && metrics.leftRect != null) {
        engine.paintPage(
          canvas,
          currentPage + 2,
          PagePaintContext(
            contentRect: metrics.leftRect!,
            backPage: true,
            recordInteractiveRegions: false,
          ),
        );
      }
    } else if (currentPage < lastPage) {
      engine.paintPage(
        canvas,
        currentPage + 1,
        PagePaintContext(
          contentRect: metrics.rightRect,
          backPage: true,
          recordInteractiveRegions: false,
        ),
      );
    }

    _paintHeader(canvas, metrics);
    _paintPageNumbers(
      canvas,
      metrics,
      currentPage: currentPage,
      totalPages: totalPages,
    );

    if (spreadMode == KumihanSpreadMode.doublePage) {
      if (currentPage <= lastPage) {
        engine.paintPage(
          canvas,
          currentPage,
          PagePaintContext(contentRect: metrics.rightRect),
        );
      }
      if (currentPage + 1 <= lastPage && metrics.leftRect != null) {
        engine.paintPage(
          canvas,
          currentPage + 1,
          PagePaintContext(contentRect: metrics.leftRect!),
        );
      }
      _paintDebugRects(canvas, metrics);
      return;
    }

    if (currentPage <= lastPage) {
      engine.paintPage(
        canvas,
        currentPage,
        PagePaintContext(contentRect: metrics.rightRect),
      );
    }
    _paintDebugRects(canvas, metrics);
  }

  void _paintDebugRects(ui.Canvas canvas, _BookSpreadMetrics metrics) {
    final rightFill = Paint()
      ..color = const Color(0xffff0000).withValues(alpha: 0.08);
    final rightStroke = Paint()
      ..color = const Color(0xffff0000).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(metrics.rightRect, rightFill);
    canvas.drawRect(metrics.rightRect, rightStroke);

    if (metrics.leftRect == null) {
      return;
    }

    final leftFill = Paint()
      ..color = const Color(0xff00aa00).withValues(alpha: 0.08);
    final leftStroke = Paint()
      ..color = const Color(0xff00aa00).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(metrics.leftRect!, leftFill);
    canvas.drawRect(metrics.leftRect!, leftStroke);
  }

  void _paintHeader(ui.Canvas canvas, _BookSpreadMetrics metrics) {
    final headerTitle = engine.headerTitle;
    if (!layout.showTitle || headerTitle.isEmpty) {
      return;
    }

    final x = spreadMode == KumihanSpreadMode.single
        ? metrics.rightRect.left + metrics.contentPadding.left
        : metrics.outerPadding.left + metrics.contentPadding.left;
    final width = math.max(
      spreadMode == KumihanSpreadMode.single
          ? metrics.rightRect.width - metrics.contentPadding.horizontal
          : metrics.size.width -
                metrics.outerPadding.horizontal -
                metrics.contentPadding.horizontal,
      1.0,
    );
    final y = metrics.pageMarginTop - 1.85 * metrics.fontSize;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(x, y, width, metrics.pageMarginTop));
    final painter = TextPainter(
      text: TextSpan(
        text: headerTitle,
        style: TextStyle(
          color: engine.fontColor.withValues(alpha: theme.isDark ? 0.64 : 0.5),
          fontFamily: defaultGothicFontFamilies.first,
          fontFamilyFallback: defaultGothicFontFamilies.sublist(1),
          package: bundledFontPackage,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset(x, y));
    canvas.restore();
  }

  void _paintPageNumbers(
    ui.Canvas canvas,
    _BookSpreadMetrics metrics, {
    required int currentPage,
    required int totalPages,
  }) {
    if (!layout.showPageNumber || totalPages <= 0) {
      return;
    }

    if (spreadMode == KumihanSpreadMode.doublePage) {
      if (currentPage < totalPages) {
        _paintPageNumberLabel(
          canvas,
          metrics,
          pageIndex: currentPage,
          x:
              metrics.rightRect.right -
              metrics.contentPadding.right -
              metrics.fontSize,
          alignRight: true,
          totalPages: totalPages,
        );
      }
      if (currentPage + 1 < totalPages) {
        _paintPageNumberLabel(
          canvas,
          metrics,
          pageIndex: currentPage + 1,
          x:
              metrics.leftRect!.left +
              metrics.contentPadding.left +
              metrics.fontSize,
          alignRight: false,
          totalPages: totalPages,
        );
      }
      return;
    }

    final label = '${currentPage + 1}/$totalPages';
    final painter = _pageNumberPainter(label, metrics.fontSize);
    final x = switch (layout.singlePageNumberPosition) {
      KumihanSinglePageNumberPosition.left =>
        metrics.rightRect.left + metrics.contentPadding.left + metrics.fontSize,
      KumihanSinglePageNumberPosition.center =>
        metrics.size.width / 2 - painter.width / 2,
      KumihanSinglePageNumberPosition.right =>
        metrics.rightRect.right -
            metrics.contentPadding.right -
            metrics.fontSize -
            painter.width,
    };
    painter.paint(
      canvas,
      Offset(
        x,
        metrics.size.height -
            metrics.pageMarginBottom +
            metrics.fontSize -
            painter.height / 2,
      ),
    );
  }

  void _paintPageNumberLabel(
    ui.Canvas canvas,
    _BookSpreadMetrics metrics, {
    required bool alignRight,
    required int pageIndex,
    required double x,
    required int totalPages,
  }) {
    final painter = _pageNumberPainter(
      '${pageIndex + 1}/$totalPages',
      metrics.fontSize,
    );
    painter.paint(
      canvas,
      Offset(
        alignRight ? x - painter.width : x,
        metrics.size.height -
            metrics.pageMarginBottom +
            metrics.fontSize -
            painter.height / 2,
      ),
    );
  }

  TextPainter _pageNumberPainter(String label, double fontSize) {
    return TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: engine.fontColor,
          fontFamily: defaultMinchoFontFamilies.first,
          fontFamilyFallback: defaultMinchoFontFamilies.sublist(1),
          package: bundledFontPackage,
          fontSize: 0.9 * fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
  }
}

class _BookSpreadMetrics {
  const _BookSpreadMetrics({
    required this.fontSize,
    required this.contentPadding,
    required this.pageMarginBottom,
    required this.outerPadding,
    required this.pageMarginTop,
    required this.rightRect,
    required this.leftRect,
    required this.size,
  });

  final double fontSize;
  final EdgeInsets contentPadding;
  final double pageMarginBottom;
  final EdgeInsets outerPadding;
  final double pageMarginTop;
  final Rect rightRect;
  final Rect? leftRect;
  final Size size;
}
