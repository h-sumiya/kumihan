import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const double defaultKumihanFontSize = 18;
const EdgeInsets? defaultKumihanPagePadding = null;
const bool defaultKumihanShowTitle = true;
const bool defaultKumihanShowPageNumber = true;
const Object _unsetPagePadding = Object();

enum KumihanSinglePageNumberPosition { left, center, right }

const KumihanSinglePageNumberPosition defaultKumihanSinglePageNumberPosition =
    KumihanSinglePageNumberPosition.center;

@immutable
class KumihanLayoutData {
  const KumihanLayoutData({
    this.fontSize = defaultKumihanFontSize,
    this.pagePadding = defaultKumihanPagePadding,
    this.showTitle = defaultKumihanShowTitle,
    this.showPageNumber = defaultKumihanShowPageNumber,
    this.singlePageNumberPosition = defaultKumihanSinglePageNumberPosition,
  }) : assert(fontSize > 0);

  final double fontSize;
  final EdgeInsets? pagePadding;
  final bool showTitle;
  final bool showPageNumber;
  final KumihanSinglePageNumberPosition singlePageNumberPosition;

  KumihanLayoutData copyWith({
    double? fontSize,
    Object? pagePadding = _unsetPagePadding,
    bool? showTitle,
    bool? showPageNumber,
    KumihanSinglePageNumberPosition? singlePageNumberPosition,
  }) => KumihanLayoutData(
    fontSize: fontSize ?? this.fontSize,
    pagePadding: identical(pagePadding, _unsetPagePadding)
        ? this.pagePadding
        : pagePadding as EdgeInsets?,
    showTitle: showTitle ?? this.showTitle,
    showPageNumber: showPageNumber ?? this.showPageNumber,
    singlePageNumberPosition:
        singlePageNumberPosition ?? this.singlePageNumberPosition,
  );

  @override
  bool operator ==(Object other) =>
      other is KumihanLayoutData &&
      other.fontSize == fontSize &&
      other.pagePadding == pagePadding &&
      other.showTitle == showTitle &&
      other.showPageNumber == showPageNumber &&
      other.singlePageNumberPosition == singlePageNumberPosition;

  @override
  int get hashCode => Object.hash(
    fontSize,
    pagePadding,
    showTitle,
    showPageNumber,
    singlePageNumberPosition,
  );
}

enum KumihanWritingMode { vertical }

enum KumihanSpreadMode { single, doublePage }

class KumihanPagedSnapshot {
  const KumihanPagedSnapshot({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  KumihanPagedSnapshot copyWith({int? currentPage, int? totalPages}) =>
      KumihanPagedSnapshot(
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
      );
}

typedef KumihanSnapshot = KumihanPagedSnapshot;

class KumihanScrollSnapshot {
  const KumihanScrollSnapshot({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.scrollOffset,
    required this.maxScrollOffset,
    required this.contentWidth,
    required this.visibleRange,
  });

  final double viewportWidth;
  final double viewportHeight;
  final double scrollOffset;
  final double maxScrollOffset;
  final double contentWidth;
  final Rect visibleRange;

  KumihanScrollSnapshot copyWith({
    double? viewportWidth,
    double? viewportHeight,
    double? scrollOffset,
    double? maxScrollOffset,
    double? contentWidth,
    Rect? visibleRange,
  }) => KumihanScrollSnapshot(
    viewportWidth: viewportWidth ?? this.viewportWidth,
    viewportHeight: viewportHeight ?? this.viewportHeight,
    scrollOffset: scrollOffset ?? this.scrollOffset,
    maxScrollOffset: maxScrollOffset ?? this.maxScrollOffset,
    contentWidth: contentWidth ?? this.contentWidth,
    visibleRange: visibleRange ?? this.visibleRange,
  );
}

@immutable
class KumihanSelectableGlyph {
  const KumihanSelectableGlyph({
    required this.order,
    required this.rect,
    required this.text,
  });

  final int order;
  final Rect rect;
  final String text;

  bool hitTest(Offset position) => rect.contains(position);
}
