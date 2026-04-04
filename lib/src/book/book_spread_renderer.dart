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
        _paintPageSurface(
          canvas,
          metrics,
          destinationRect: metrics.rightRect,
          pageIndex: currentPage - 1,
          totalPages: totalPages,
          sourceSlot: _slotForPage(currentPage - 1),
          backPage: true,
        );
      }
      if (currentPage < lastPage - 1 && metrics.leftRect != null) {
        _paintPageSurface(
          canvas,
          metrics,
          destinationRect: metrics.leftRect!,
          pageIndex: currentPage + 2,
          totalPages: totalPages,
          sourceSlot: _slotForPage(currentPage + 2),
          backPage: true,
        );
      }
    } else if (currentPage < lastPage) {
      _paintPageSurface(
        canvas,
        metrics,
        destinationRect: metrics.rightRect,
        pageIndex: currentPage + 1,
        totalPages: totalPages,
        sourceSlot: _BookPageSlot.single,
        backPage: true,
      );
    }

    if (spreadMode == KumihanSpreadMode.doublePage) {
      if (currentPage <= lastPage) {
        _paintPageSurface(
          canvas,
          metrics,
          destinationRect: metrics.rightRect,
          pageIndex: currentPage,
          totalPages: totalPages,
          sourceSlot: _slotForPage(currentPage),
          backPage: false,
        );
      }
      if (currentPage + 1 <= lastPage && metrics.leftRect != null) {
        _paintPageSurface(
          canvas,
          metrics,
          destinationRect: metrics.leftRect!,
          pageIndex: currentPage + 1,
          totalPages: totalPages,
          sourceSlot: _slotForPage(currentPage + 1),
          backPage: false,
        );
      }
      return;
    }

    if (currentPage <= lastPage) {
      _paintPageSurface(
        canvas,
        metrics,
        destinationRect: metrics.rightRect,
        pageIndex: currentPage,
        totalPages: totalPages,
        sourceSlot: _BookPageSlot.single,
        backPage: false,
      );
    }
  }

  _BookPageSlot _slotForPage(int pageIndex) {
    if (spreadMode == KumihanSpreadMode.single) {
      return _BookPageSlot.single;
    }
    return pageIndex.isEven ? _BookPageSlot.right : _BookPageSlot.left;
  }

  KumihanFullPageAlignment _alignmentForSlot(_BookPageSlot slot) {
    return switch (slot) {
      _BookPageSlot.single || _BookPageSlot.right =>
        layout.rightPageFullPageAlignment,
      _BookPageSlot.left => layout.leftPageFullPageAlignment,
    };
  }

  Rect _sourceRectForSlot(_BookSpreadMetrics metrics, _BookPageSlot slot) {
    return switch (slot) {
      _BookPageSlot.single || _BookPageSlot.right => metrics.rightRect,
      _BookPageSlot.left => metrics.leftRect!,
    };
  }

  double _headerGlobalX(_BookSpreadMetrics metrics) {
    return spreadMode == KumihanSpreadMode.single
        ? metrics.rightRect.left + metrics.contentPadding.left
        : metrics.outerPadding.left + metrics.contentPadding.left;
  }

  double _headerGlobalWidth(_BookSpreadMetrics metrics) {
    return math.max(
      spreadMode == KumihanSpreadMode.single
          ? metrics.rightRect.width - metrics.contentPadding.horizontal
          : metrics.size.width -
                metrics.outerPadding.horizontal -
                metrics.contentPadding.horizontal,
      1.0,
    );
  }

  double _headerY(_BookSpreadMetrics metrics) {
    return metrics.pageMarginTop - 1.85 * metrics.fontSize;
  }

  Paint _backPageLayerPaint() {
    return Paint()
      ..color =
          (theme.isDark ? const Color(0xff000000) : const Color(0xffffffff))
              .withValues(alpha: clampDouble(theme.backPageOpacity, 0, 1));
  }

  void _paintPageSurface(
    ui.Canvas canvas,
    _BookSpreadMetrics metrics, {
    required Rect destinationRect,
    required int pageIndex,
    required int totalPages,
    required _BookPageSlot sourceSlot,
    required bool backPage,
  }) {
    _paintPageChrome(
      canvas,
      metrics,
      destinationRect: destinationRect,
      pageIndex: pageIndex,
      totalPages: totalPages,
      sourceSlot: sourceSlot,
      backPage: backPage,
    );

    engine.paintPage(
      canvas,
      pageIndex,
      PagePaintContext(
        contentRect: destinationRect,
        backPage: backPage,
        recordInteractiveRegions: !backPage,
        inlineAlignment: _alignmentForSlot(sourceSlot),
      ),
    );
  }

  void _paintPageChrome(
    ui.Canvas canvas,
    _BookSpreadMetrics metrics, {
    required Rect destinationRect,
    required int pageIndex,
    required int totalPages,
    required _BookPageSlot sourceSlot,
    required bool backPage,
  }) {
    final sourceRect = _sourceRectForSlot(metrics, sourceSlot);
    canvas.save();
    canvas.translate(destinationRect.left, 0);
    if (backPage) {
      canvas.translate(destinationRect.width, 0);
      canvas.scale(-1, 1);
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, destinationRect.width, metrics.size.height),
        _backPageLayerPaint(),
      );
    }
    _paintHeader(
      canvas,
      metrics,
      sourceRect: sourceRect,
      pageWidth: destinationRect.width,
    );
    _paintPageNumber(
      canvas,
      metrics,
      sourceRect: sourceRect,
      pageWidth: destinationRect.width,
      pageIndex: pageIndex,
      totalPages: totalPages,
      sourceSlot: sourceSlot,
    );
    if (backPage) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintHeader(
    ui.Canvas canvas,
    _BookSpreadMetrics metrics, {
    required Rect sourceRect,
    required double pageWidth,
  }) {
    final headerTitle = engine.headerTitle;
    if (!layout.showTitle || headerTitle.isEmpty) {
      return;
    }

    final y = _headerY(metrics);
    final x = _headerGlobalX(metrics) - sourceRect.left;
    final width = math.max(pageWidth - metrics.contentPadding.horizontal, 1.0);

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        metrics.contentPadding.left,
        y,
        width,
        metrics.pageMarginTop,
      ),
    );
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
    )..layout(maxWidth: _headerGlobalWidth(metrics));
    painter.paint(canvas, Offset(x, y));
    canvas.restore();
  }

  void _paintPageNumber(
    ui.Canvas canvas,
    _BookSpreadMetrics metrics, {
    required Rect sourceRect,
    required double pageWidth,
    required int pageIndex,
    required int totalPages,
    required _BookPageSlot sourceSlot,
  }) {
    if (!layout.showPageNumber || totalPages <= 0) {
      return;
    }

    final painter = _pageNumberPainter(
      '${pageIndex + 1}/$totalPages',
      metrics.fontSize,
    );
    final x = switch (sourceSlot) {
      _BookPageSlot.left =>
        metrics.contentPadding.left + metrics.fontSize,
      _BookPageSlot.right =>
        pageWidth -
            metrics.contentPadding.right -
            metrics.fontSize -
            painter.width,
      _BookPageSlot.single => switch (layout.singlePageNumberPosition) {
        KumihanSinglePageNumberPosition.left =>
          metrics.rightRect.left +
              metrics.contentPadding.left +
              metrics.fontSize -
              sourceRect.left,
        KumihanSinglePageNumberPosition.center =>
          metrics.size.width / 2 - painter.width / 2 - sourceRect.left,
        KumihanSinglePageNumberPosition.right =>
          metrics.rightRect.right -
              metrics.contentPadding.right -
              metrics.fontSize -
              painter.width -
              sourceRect.left,
      },
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

enum _BookPageSlot { single, right, left }
