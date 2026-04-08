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
    this.drawGutterShadow = true,
  });

  final KumihanEngine engine;
  final KumihanBookLayoutData layout;
  final KumihanThemeData theme;
  final KumihanSpreadMode spreadMode;
  final bool drawGutterShadow;

  Size resolvePageSize(Size size) {
    final viewportSize = _viewportSize(size);
    return resolvePageMetrics(viewportSize, BookPageSlot.right).bodyRect.size;
  }

  void paint(
    ui.Canvas canvas,
    Size size, {
    required int currentPage,
    required int totalPages,
  }) {
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.paperColor);

    if (spreadMode == KumihanSpreadMode.doublePage) {
      final viewportWidth = size.width / 2;
      _paintViewport(
        canvas,
        Size(viewportWidth, size.height),
        viewportSlot: BookPageSlot.left,
        globalViewportOrigin: Offset.zero,
        currentPage: currentPage,
        totalPages: totalPages,
      );
      canvas.save();
      canvas.translate(viewportWidth, 0);
      _paintViewport(
        canvas,
        Size(viewportWidth, size.height),
        viewportSlot: BookPageSlot.right,
        globalViewportOrigin: Offset(viewportWidth, 0),
        currentPage: currentPage,
        totalPages: totalPages,
      );
      canvas.restore();
      return;
    }

    _paintViewport(
      canvas,
      size,
      viewportSlot: BookPageSlot.single,
      globalViewportOrigin: Offset.zero,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  void paintViewport(
    ui.Canvas canvas,
    Size viewportSize, {
    required BookPageSlot viewportSlot,
    required Offset globalViewportOrigin,
    required int currentPage,
    required int totalPages,
    bool recordInteractiveRegions = true,
  }) {
    _paintViewport(
      canvas,
      viewportSize,
      viewportSlot: viewportSlot,
      globalViewportOrigin: globalViewportOrigin,
      currentPage: currentPage,
      totalPages: totalPages,
      recordInteractiveRegions: recordInteractiveRegions,
    );
  }

  Size _viewportSize(Size spreadSize) {
    return spreadMode == KumihanSpreadMode.doublePage
        ? Size(spreadSize.width / 2, spreadSize.height)
        : spreadSize;
  }

  EdgeInsets _resolveUiPadding(EdgeInsets padding, BookPageSlot slot) {
    if (slot == BookPageSlot.left) {
      return EdgeInsets.fromLTRB(
        padding.right,
        padding.top,
        padding.left,
        padding.bottom,
      );
    }
    return padding;
  }

  EdgeInsets _resolveBodyPadding(BookPageSlot slot) {
    final bodyPadding = layout.bodyPadding;
    return switch (slot) {
      BookPageSlot.left => EdgeInsets.fromLTRB(
        bodyPadding.outer,
        bodyPadding.top,
        bodyPadding.inner,
        bodyPadding.bottom,
      ),
      BookPageSlot.right || BookPageSlot.single => EdgeInsets.fromLTRB(
        bodyPadding.inner,
        bodyPadding.top,
        bodyPadding.outer,
        bodyPadding.bottom,
      ),
    };
  }

  EdgeInsets _scaleVerticalInsets(EdgeInsets insets, double factor) {
    if (factor == 1) {
      return insets;
    }
    return EdgeInsets.fromLTRB(
      insets.left,
      insets.top * factor,
      insets.right,
      insets.bottom * factor,
    );
  }

  BookPageMetrics resolvePageMetrics(Size viewportSize, BookPageSlot slot) {
    final fontSize = layout.fontSize.roundToDouble();
    final minBodyHeight = fontSize * 6;
    final headerReservedExtent =
        layout.showTitle && engine.headerTitle.isNotEmpty
        ? math.max(1.85 * fontSize + 20, 0)
        : 0.0;
    final pageNumberReservedExtent = layout.showPageNumber
        ? math.max(2.07 * fontSize, 44)
        : 0.0;

    final topUiPadding = _resolveUiPadding(layout.topUiPadding, slot);
    final bottomUiPadding = _resolveUiPadding(layout.bottomUiPadding, slot);
    final bodyPadding = _resolveBodyPadding(slot);

    final topReservedExtent =
        topUiPadding.top +
        headerReservedExtent +
        topUiPadding.bottom +
        bodyPadding.top;
    final bottomReservedExtent =
        bodyPadding.bottom +
        bottomUiPadding.top +
        pageNumberReservedExtent +
        bottomUiPadding.bottom;

    final maxReservedExtent = math.max(viewportSize.height - minBodyHeight, 0);
    final reservedExtent = topReservedExtent + bottomReservedExtent;
    final verticalFactor =
        reservedExtent > maxReservedExtent && reservedExtent > 0
        ? maxReservedExtent / reservedExtent
        : 1.0;

    final scaledTopUiPadding = _scaleVerticalInsets(
      topUiPadding,
      verticalFactor,
    );
    final scaledBottomUiPadding = _scaleVerticalInsets(
      bottomUiPadding,
      verticalFactor,
    );
    final scaledBodyPadding = _scaleVerticalInsets(bodyPadding, verticalFactor);
    final scaledHeaderReservedExtent = headerReservedExtent * verticalFactor;
    final scaledPageNumberReservedExtent =
        pageNumberReservedExtent * verticalFactor;
    final scaledTopReservedExtent =
        scaledTopUiPadding.top +
        scaledHeaderReservedExtent +
        scaledTopUiPadding.bottom +
        scaledBodyPadding.top;
    final scaledBottomReservedExtent =
        scaledBodyPadding.bottom +
        scaledBottomUiPadding.top +
        scaledPageNumberReservedExtent +
        scaledBottomUiPadding.bottom;

    final bodyRect = Rect.fromLTWH(
      scaledBodyPadding.left,
      scaledTopReservedExtent,
      math.max(
        viewportSize.width - scaledBodyPadding.left - scaledBodyPadding.right,
        fontSize,
      ),
      math.max(
        viewportSize.height -
            scaledTopReservedExtent -
            scaledBottomReservedExtent,
        fontSize,
      ),
    );

    return BookPageMetrics(
      bodyPadding: scaledBodyPadding,
      bodyRect: bodyRect,
      bottomReservedExtent: scaledBottomReservedExtent,
      bottomUiPadding: scaledBottomUiPadding,
      fontSize: fontSize,
      pageNumberReservedExtent: scaledPageNumberReservedExtent,
      topUiPadding: scaledTopUiPadding,
      viewportSize: viewportSize,
    );
  }

  Rect resolveBodyRect(Size viewportSize, BookPageSlot slot) {
    return resolvePageMetrics(viewportSize, slot).bodyRect;
  }

  void paintDocumentPageSurface(
    ui.Canvas canvas,
    Size viewportSize, {
    required int pageIndex,
    required int totalPages,
    required BookPageSlot slot,
    Offset globalViewportOrigin = Offset.zero,
    bool resetPaintState = true,
    bool recordInteractiveRegions = true,
  }) {
    canvas.drawRect(
      Offset.zero & viewportSize,
      Paint()..color = theme.paperColor,
    );

    if (resetPaintState) {
      engine.resetPaintState();
    }

    if (pageIndex < 0 || pageIndex >= totalPages) {
      return;
    }

    final metrics = resolvePageMetrics(viewportSize, slot);
    _paintPageSurface(
      canvas,
      metrics,
      globalContentOrigin: globalViewportOrigin + metrics.bodyRect.topLeft,
      pageIndex: pageIndex,
      totalPages: totalPages,
      viewportSlot: slot,
      sourceSlot: slot,
      backPage: false,
      recordInteractiveRegions: recordInteractiveRegions,
    );
  }

  void _paintViewport(
    ui.Canvas canvas,
    Size viewportSize, {
    required BookPageSlot viewportSlot,
    required Offset globalViewportOrigin,
    required int currentPage,
    required int totalPages,
    bool recordInteractiveRegions = true,
  }) {
    canvas.drawRect(
      Offset.zero & viewportSize,
      Paint()..color = theme.paperColor,
    );

    final metrics = resolvePageMetrics(viewportSize, viewportSlot);
    final lastPage = math.max(totalPages - 1, 0);
    final backPageIndex = _backPageIndexForViewport(
      viewportSlot,
      currentPage,
      lastPage,
    );
    final frontPageIndex = _frontPageIndexForViewport(
      viewportSlot,
      currentPage,
      lastPage,
    );
    final globalContentOrigin = globalViewportOrigin + metrics.bodyRect.topLeft;

    if (backPageIndex != null) {
      _paintPageSurface(
        canvas,
        metrics,
        globalContentOrigin: globalContentOrigin,
        pageIndex: backPageIndex,
        totalPages: totalPages,
        viewportSlot: viewportSlot,
        sourceSlot: _slotForPage(backPageIndex),
        backPage: true,
        recordInteractiveRegions: recordInteractiveRegions,
      );
    }

    if (frontPageIndex != null) {
      _paintPageSurface(
        canvas,
        metrics,
        globalContentOrigin: globalContentOrigin,
        pageIndex: frontPageIndex,
        totalPages: totalPages,
        viewportSlot: viewportSlot,
        sourceSlot: _slotForPage(frontPageIndex),
        backPage: false,
        recordInteractiveRegions: recordInteractiveRegions,
      );
    }

    _paintGutterShadow(canvas, metrics, viewportSlot: viewportSlot);
  }

  int? _frontPageIndexForViewport(
    BookPageSlot viewportSlot,
    int currentPage,
    int lastPage,
  ) {
    final pageIndex = switch (viewportSlot) {
      BookPageSlot.single || BookPageSlot.right => currentPage,
      BookPageSlot.left => currentPage + 1,
    };
    return pageIndex <= lastPage ? pageIndex : null;
  }

  int? _backPageIndexForViewport(
    BookPageSlot viewportSlot,
    int currentPage,
    int lastPage,
  ) {
    final pageIndex = switch (viewportSlot) {
      BookPageSlot.single => currentPage + 1,
      BookPageSlot.right => currentPage > 0 ? currentPage - 1 : -1,
      BookPageSlot.left => currentPage + 2,
    };
    return pageIndex >= 0 && pageIndex <= lastPage ? pageIndex : null;
  }

  KumihanFullPageAlignment _alignmentForSlot(BookPageSlot slot) {
    return switch (slot) {
      BookPageSlot.single ||
      BookPageSlot.right => layout.rightPageFullPageAlignment,
      BookPageSlot.left => layout.leftPageFullPageAlignment,
    };
  }

  BookPageSlot _slotForPage(int pageIndex) {
    if (spreadMode == KumihanSpreadMode.single) {
      return BookPageSlot.single;
    }
    return pageIndex.isEven ? BookPageSlot.right : BookPageSlot.left;
  }

  Paint _backPageLayerPaint() {
    return Paint()
      ..color =
          (theme.isDark ? const Color(0xff000000) : const Color(0xffffffff))
              .withValues(alpha: clampDouble(theme.backPageOpacity, 0, 1));
  }

  void _paintGutterShadow(
    ui.Canvas canvas,
    BookPageMetrics metrics, {
    required BookPageSlot viewportSlot,
  }) {
    if (!drawGutterShadow ||
        theme.disableGutterShadow ||
        spreadMode != KumihanSpreadMode.doublePage ||
        viewportSlot == BookPageSlot.single) {
      return;
    }

    final shadowWidth = math.min(metrics.viewportSize.width * 0.08, 24.0);
    if (shadowWidth <= 0) {
      return;
    }

    final rect = viewportSlot == BookPageSlot.left
        ? Rect.fromLTWH(
            metrics.viewportSize.width - shadowWidth,
            0,
            shadowWidth,
            metrics.viewportSize.height,
          )
        : Rect.fromLTWH(0, 0, shadowWidth, metrics.viewportSize.height);
    final begin = viewportSlot == BookPageSlot.left
        ? rect.centerLeft
        : rect.centerRight;
    final end = viewportSlot == BookPageSlot.left
        ? rect.centerRight
        : rect.centerLeft;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          begin,
          end,
          const <Color>[
            Color(0x00000000),
            Color(0x14000000),
            Color(0x24000000),
          ],
          const <double>[0.0, 0.55, 1.0],
        ),
    );
  }

  void _paintPageSurface(
    ui.Canvas canvas,
    BookPageMetrics metrics, {
    required Offset globalContentOrigin,
    required int pageIndex,
    required int totalPages,
    required BookPageSlot viewportSlot,
    required BookPageSlot sourceSlot,
    required bool backPage,
    bool recordInteractiveRegions = true,
  }) {
    if (backPage) {
      canvas.save();
      canvas.translate(metrics.viewportSize.width, 0);
      canvas.scale(-1, 1);
      canvas.saveLayer(
        Offset.zero & metrics.viewportSize,
        _backPageLayerPaint(),
      );
    }

    _paintHeader(canvas, metrics, viewportSlot: viewportSlot);
    _paintPageNumber(
      canvas,
      metrics,
      pageIndex: pageIndex,
      totalPages: totalPages,
      sourceSlot: sourceSlot,
    );

    if (backPage) {
      canvas.restore();
      canvas.restore();
    }

    engine.paintPage(
      canvas,
      pageIndex,
      PagePaintContext(
        contentRect: metrics.bodyRect,
        globalContentOrigin: globalContentOrigin,
        backPage: backPage,
        recordInteractiveRegions: !backPage && recordInteractiveRegions,
        inlineAlignment: _alignmentForSlot(sourceSlot),
      ),
    );
  }

  void _paintHeader(
    ui.Canvas canvas,
    BookPageMetrics metrics, {
    required BookPageSlot viewportSlot,
  }) {
    final headerTitle = engine.headerTitle;
    if (!layout.showTitle || headerTitle.isEmpty) {
      return;
    }

    final availableWidth = math.max(
      metrics.viewportSize.width - metrics.topUiPadding.horizontal,
      1.0,
    );
    final globalHeaderX = switch (spreadMode) {
      KumihanSpreadMode.single => resolvePageMetrics(
        metrics.viewportSize,
        BookPageSlot.left,
      ).topUiPadding.left,
      KumihanSpreadMode.doublePage => resolvePageMetrics(
        metrics.viewportSize,
        BookPageSlot.left,
      ).topUiPadding.left,
    };
    final globalHeaderWidth = switch (spreadMode) {
      KumihanSpreadMode.single => availableWidth,
      KumihanSpreadMode.doublePage => math.max(
        metrics.viewportSize.width * 2 -
            resolvePageMetrics(
              metrics.viewportSize,
              BookPageSlot.left,
            ).topUiPadding.left -
            resolvePageMetrics(
              metrics.viewportSize,
              BookPageSlot.right,
            ).topUiPadding.right,
        1.0,
      ),
    };
    final globalViewportLeft = switch (spreadMode) {
      KumihanSpreadMode.single => 0.0,
      KumihanSpreadMode.doublePage =>
        viewportSlot == BookPageSlot.right ? metrics.viewportSize.width : 0.0,
    };
    final baselineY =
        metrics.bodyRect.top -
        metrics.bodyPadding.top -
        metrics.topUiPadding.bottom -
        1.85 * metrics.fontSize;

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        metrics.topUiPadding.left,
        0,
        availableWidth,
        math.max(
          metrics.bodyRect.top - metrics.bodyPadding.top,
          metrics.fontSize,
        ),
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
    )..layout(maxWidth: globalHeaderWidth);
    painter.paint(
      canvas,
      Offset(globalHeaderX - globalViewportLeft, baselineY),
    );
    canvas.restore();
  }

  void _paintPageNumber(
    ui.Canvas canvas,
    BookPageMetrics metrics, {
    required int pageIndex,
    required int totalPages,
    required BookPageSlot sourceSlot,
  }) {
    if (!layout.showPageNumber || totalPages <= 0) {
      return;
    }

    final painter = _pageNumberPainter(
      '${pageIndex + 1}/$totalPages',
      metrics.fontSize,
    );
    final x = switch (sourceSlot) {
      BookPageSlot.left => metrics.bottomUiPadding.left + metrics.fontSize,
      BookPageSlot.right =>
        metrics.viewportSize.width -
            metrics.bottomUiPadding.right -
            metrics.fontSize -
            painter.width,
      BookPageSlot.single => switch (layout.singlePageNumberPosition) {
        KumihanSinglePageNumberPosition.left =>
          metrics.bottomUiPadding.left + metrics.fontSize,
        KumihanSinglePageNumberPosition.center =>
          metrics.viewportSize.width / 2 - painter.width / 2,
        KumihanSinglePageNumberPosition.right =>
          metrics.viewportSize.width -
              metrics.bottomUiPadding.right -
              metrics.fontSize -
              painter.width,
      },
    };

    painter.paint(
      canvas,
      Offset(
        x,
        metrics.viewportSize.height -
            metrics.bottomReservedExtent +
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

class BookPageMetrics {
  const BookPageMetrics({
    required this.bodyPadding,
    required this.bodyRect,
    required this.bottomReservedExtent,
    required this.bottomUiPadding,
    required this.fontSize,
    required this.pageNumberReservedExtent,
    required this.topUiPadding,
    required this.viewportSize,
  });

  final EdgeInsets bodyPadding;
  final Rect bodyRect;
  final double bottomReservedExtent;
  final EdgeInsets bottomUiPadding;
  final double fontSize;
  final double pageNumberReservedExtent;
  final EdgeInsets topUiPadding;
  final Size viewportSize;
}

enum BookPageSlot { single, right, left }
