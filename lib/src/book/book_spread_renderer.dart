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
  final KumihanLayoutData layout;
  final KumihanThemeData theme;
  final KumihanSpreadMode spreadMode;

  Size resolvePageSize(Size size) => _resolve(size).rightRect.size;

  _BookSpreadMetrics _resolve(Size size) {
    final fontSize = layout.fontSize.roundToDouble();
    final lineSpace = fontSize * 0.63;
    final customPadding = layout.pagePadding;
    final useCustomPadding = customPadding != null;
    final minPageWidth = fontSize * 6;
    final minPageHeight = fontSize * 6;
    final double pageWidthBase = switch (spreadMode) {
      KumihanSpreadMode.doublePage => size.width / 2,
      KumihanSpreadMode.single => size.width,
    };

    late double pageMarginSide;
    late double pageMarginCenter;
    late double pageWidth;

    if (useCustomPadding) {
      final desiredSide = customPadding.left;
      final desiredCenter = customPadding.right;
      final maxMarginTotal = math.max(pageWidthBase - minPageWidth, 0.0);
      final marginTotal = desiredSide + desiredCenter;
      final marginFactor = marginTotal > maxMarginTotal && marginTotal > 0
          ? maxMarginTotal / marginTotal
          : 1.0;
      pageMarginSide = desiredSide * marginFactor;
      pageMarginCenter = desiredCenter * marginFactor;
      pageWidth = pageWidthBase - pageMarginSide - pageMarginCenter;
    } else {
      if (spreadMode == KumihanSpreadMode.doublePage) {
        final desiredSide = math.max(size.width * 0.045, fontSize);
        final maxSide = math.max((size.width / 2 - minPageWidth) / 2.1, 0.0);
        pageMarginSide = math.min(desiredSide, maxSide);
      } else {
        final desiredSide = math.max(size.width * 0.08, fontSize);
        final maxSide = math.max((size.width - minPageWidth) / 2.1, 0.0);
        pageMarginSide = math.min(desiredSide, maxSide);
      }
      pageMarginCenter = 1.1 * pageMarginSide;
      pageWidth = pageWidthBase - pageMarginSide - pageMarginCenter;
    }

    pageWidth = math.max(pageWidth, fontSize);
    pageWidth -= (pageWidth + lineSpace) % (fontSize + lineSpace);
    if (!useCustomPadding && spreadMode == KumihanSpreadMode.single) {
      pageMarginSide = (size.width - pageWidth) / 2;
    }

    final headerReservedExtent =
        layout.showTitle && engine.headerTitle.isNotEmpty
        ? math.max(1.85 * fontSize + 20, 0)
        : 0.0;
    final pageNumberReservedExtent = layout.showPageNumber
        ? math.max(2.07 * fontSize, 44)
        : 0.0;
    final desiredTop = useCustomPadding
        ? customPadding.top + headerReservedExtent
        : math.max(size.height * 0.07, headerReservedExtent);
    final desiredBottom = useCustomPadding
        ? customPadding.bottom + pageNumberReservedExtent
        : math.max(size.height * 0.07, pageNumberReservedExtent);
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

    final rightRect = Rect.fromLTWH(
      spreadMode == KumihanSpreadMode.doublePage
          ? size.width - pageMarginSide - pageWidth
          : pageMarginSide,
      pageMarginTop,
      pageWidth,
      pageHeight,
    );
    final leftRect = spreadMode == KumihanSpreadMode.doublePage
        ? Rect.fromLTWH(pageMarginSide, pageMarginTop, pageWidth, pageHeight)
        : null;

    return _BookSpreadMetrics(
      fontSize: fontSize,
      pageMarginBottom: pageMarginBottom,
      pageMarginCenter: pageMarginCenter,
      pageMarginSide: pageMarginSide,
      pageMarginTop: pageMarginTop,
      pageWidth: pageWidth,
      rightRect: rightRect,
      leftRect: leftRect,
      size: size,
    );
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
      return;
    }

    if (currentPage <= lastPage) {
      engine.paintPage(
        canvas,
        currentPage,
        PagePaintContext(contentRect: metrics.rightRect),
      );
    }
  }

  void _paintHeader(ui.Canvas canvas, _BookSpreadMetrics metrics) {
    final headerTitle = engine.headerTitle;
    if (!layout.showTitle || headerTitle.isEmpty) {
      return;
    }

    final x = spreadMode == KumihanSpreadMode.single
        ? metrics.pageMarginSide
        : metrics.pageMarginSide + metrics.fontSize;
    final width = spreadMode == KumihanSpreadMode.single
        ? metrics.size.width - metrics.pageMarginSide - metrics.fontSize
        : metrics.pageWidth - metrics.fontSize;
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
          x: metrics.size.width - metrics.pageMarginSide - metrics.fontSize,
          alignRight: true,
          totalPages: totalPages,
        );
      }
      if (currentPage + 1 < totalPages) {
        _paintPageNumberLabel(
          canvas,
          metrics,
          pageIndex: currentPage + 1,
          x: metrics.pageMarginSide + metrics.fontSize,
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
        metrics.pageMarginSide + metrics.fontSize,
      KumihanSinglePageNumberPosition.center =>
        metrics.size.width / 2 - painter.width / 2,
      KumihanSinglePageNumberPosition.right =>
        metrics.size.width -
            metrics.pageMarginCenter -
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
    required this.pageMarginBottom,
    required this.pageMarginCenter,
    required this.pageMarginSide,
    required this.pageMarginTop,
    required this.pageWidth,
    required this.rightRect,
    required this.leftRect,
    required this.size,
  });

  final double fontSize;
  final double pageMarginBottom;
  final double pageMarginCenter;
  final double pageMarginSide;
  final double pageMarginTop;
  final double pageWidth;
  final Rect rightRect;
  final Rect? leftRect;
  final Size size;
}
