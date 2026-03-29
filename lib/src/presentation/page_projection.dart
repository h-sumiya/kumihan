import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout_result/layout_result.dart';
import '../rendering/kumihan_render_theme.dart';

class KumihanPageProjection {
  const KumihanPageProjection({
    required this.pageIndex,
    required this.pageCount,
    required this.pageStartInlineOffset,
    required this.pageInlineExtent,
    required this.fontSize,
    required Map<Object, double> slotInlineOffsets,
  }) : _slotInlineOffsets = slotInlineOffsets;

  factory KumihanPageProjection.resolve({
    required LayoutResult result,
    required KumihanRenderThemeData theme,
    required Size size,
    int pageIndex = 0,
  }) {
    final fontSize = theme.fontSize;
    final lineGap = fontSize * theme.lineGapEm;
    final minPageWidth = fontSize * 6;
    final desiredSide = theme.pagePadding.left;
    final desiredCenter = theme.pagePadding.right;
    final maxMarginTotal = math.max(size.width - minPageWidth, 0.0);
    final marginTotal = desiredSide + desiredCenter;
    final marginFactor = marginTotal > maxMarginTotal && marginTotal > 0
        ? maxMarginTotal / marginTotal
        : 1.0;
    final pageWidth = math.max(
      size.width - desiredSide * marginFactor - desiredCenter * marginFactor,
      fontSize,
    );
    final snappedPageWidth = math.max(
      pageWidth - ((pageWidth + lineGap) % (fontSize + lineGap)),
      fontSize,
    );
    final pageInlineExtent = math.max(snappedPageWidth / fontSize, 1.0);
    final pageStride = pageInlineExtent + theme.lineGapEm;
    final pageCount = math.max(
      1,
      _resolvePageCount(result, pageInlineExtent, theme.lineGapEm),
    );
    final resolvedIndex = pageIndex.clamp(0, pageCount - 1);
    return KumihanPageProjection(
      pageIndex: resolvedIndex,
      pageCount: pageCount,
      pageStartInlineOffset: resolvedIndex * pageStride,
      pageInlineExtent: pageInlineExtent,
      fontSize: fontSize,
      slotInlineOffsets: _resolveSlotInlineOffsets(
        result,
        pageInlineExtent,
        theme.lineGapEm,
        resolvedIndex,
      ),
    );
  }

  final int pageIndex;
  final int pageCount;
  final double pageStartInlineOffset;
  final double pageInlineExtent;
  final double fontSize;
  final Map<Object, double> _slotInlineOffsets;

  double get pageEndInlineOffset => pageStartInlineOffset + pageInlineExtent;

  bool overlapsInline(double inlineOffset, double inlineExtent) {
    final end = inlineOffset + inlineExtent;
    return end > pageStartInlineOffset && inlineOffset < pageEndInlineOffset;
  }

  double projectInline(double inlineOffset) =>
      inlineOffset - pageStartInlineOffset;

  double? projectedSlotInlineOffset(Object key) => _slotInlineOffsets[key];

  Rect? projectLogicalRect(
    Rect contentRect, {
    required double inlineOffset,
    required double blockOffset,
    required double inlineExtent,
    required double blockExtent,
  }) {
    if (!overlapsInline(inlineOffset, inlineExtent)) {
      return null;
    }
    final projectedInlineOffset = projectInline(inlineOffset);
    return Rect.fromLTWH(
      contentRect.right - (projectedInlineOffset + inlineExtent) * fontSize,
      contentRect.top + blockOffset * fontSize,
      inlineExtent * fontSize,
      blockExtent * fontSize,
    );
  }

  static int _resolvePageCount(
    LayoutResult result,
    double pageInlineExtent,
    double lineGap,
  ) {
    final slots = _collectSlots(result);
    var pageCount = 1;
    var currentWidth = -lineGap;
    for (final slot in slots) {
      final nextWidth = currentWidth + slot.inlineExtent + lineGap;
      if (currentWidth >= 0 && nextWidth > pageInlineExtent) {
        pageCount += 1;
        currentWidth = slot.inlineExtent;
        continue;
      }
      currentWidth = nextWidth;
    }
    return pageCount;
  }

  static Map<Object, double> _resolveSlotInlineOffsets(
    LayoutResult result,
    double pageInlineExtent,
    double lineGap,
    int targetPage,
  ) {
    final slots = _collectSlots(result);
    final offsets = <Object, double>{};
    var currentPage = 0;
    var currentWidth = -lineGap;
    for (final slot in slots) {
      final nextWidth = currentWidth + slot.inlineExtent + lineGap;
      if (currentWidth >= 0 && nextWidth > pageInlineExtent) {
        currentPage += 1;
        currentWidth = -lineGap;
      }
      final projectedInlineOffset = currentWidth + lineGap;
      if (currentPage == targetPage) {
        offsets[slot.key] = projectedInlineOffset;
      }
      currentWidth = projectedInlineOffset + slot.inlineExtent;
    }
    return Map<Object, double>.unmodifiable(offsets);
  }

  static List<_ProjectionSlot> _collectSlots(LayoutResult result) {
    final slots = <_ProjectionSlot>[];
    for (final block in result.blocks) {
      switch (block) {
        case LayoutParagraphResult():
          for (final line in block.lineGroup.lines) {
            slots.add(
              _ProjectionSlot(key: line, inlineExtent: line.inlineExtent),
            );
          }
        case LayoutEmptyLineResult():
          for (final line in block.lineGroup.lines) {
            slots.add(
              _ProjectionSlot(key: line, inlineExtent: line.inlineExtent),
            );
          }
        case LayoutTableResult():
          slots.add(
            _ProjectionSlot(key: block, inlineExtent: block.inlineExtent),
          );
        case LayoutUnsupportedBlockResult():
          slots.add(
            _ProjectionSlot(key: block, inlineExtent: block.inlineExtent),
          );
      }
    }
    return slots;
  }
}

class _ProjectionSlot {
  const _ProjectionSlot({required this.key, required this.inlineExtent});

  final Object key;
  final double inlineExtent;
}
