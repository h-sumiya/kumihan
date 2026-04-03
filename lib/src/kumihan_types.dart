import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const double defaultKumihanFontSize = 18;
const EdgeInsets? defaultKumihanPagePadding = null;
const bool defaultKumihanShowTitle = true;
const bool defaultKumihanShowPageNumber = true;
const Object _unsetPagePadding = Object();
const Object _unsetBookOuterPadding = Object();
const Object _unsetBookContentPadding = Object();

enum KumihanSinglePageNumberPosition { left, center, right }

enum KumihanFullPageAlignment { left, center, right }

const KumihanSinglePageNumberPosition defaultKumihanSinglePageNumberPosition =
    KumihanSinglePageNumberPosition.center;
const KumihanFullPageAlignment defaultKumihanFullPageAlignment =
    KumihanFullPageAlignment.right;
const KumihanFullPageAlignment defaultKumihanBookRightPageFullPageAlignment =
    KumihanFullPageAlignment.left;
const KumihanFullPageAlignment defaultKumihanBookLeftPageFullPageAlignment =
    KumihanFullPageAlignment.right;

@immutable
class KumihanLayoutData {
  const KumihanLayoutData({
    this.fontSize = defaultKumihanFontSize,
    this.pagePadding = defaultKumihanPagePadding,
    this.showTitle = defaultKumihanShowTitle,
    this.showPageNumber = defaultKumihanShowPageNumber,
    this.singlePageNumberPosition = defaultKumihanSinglePageNumberPosition,
    this.fullPageAlignment = defaultKumihanFullPageAlignment,
  }) : assert(fontSize > 0);

  final double fontSize;
  final EdgeInsets? pagePadding;
  final bool showTitle;
  final bool showPageNumber;
  final KumihanSinglePageNumberPosition singlePageNumberPosition;
  final KumihanFullPageAlignment fullPageAlignment;

  KumihanLayoutData copyWith({
    double? fontSize,
    Object? pagePadding = _unsetPagePadding,
    bool? showTitle,
    bool? showPageNumber,
    KumihanSinglePageNumberPosition? singlePageNumberPosition,
    KumihanFullPageAlignment? fullPageAlignment,
  }) => KumihanLayoutData(
    fontSize: fontSize ?? this.fontSize,
    pagePadding: identical(pagePadding, _unsetPagePadding)
        ? this.pagePadding
        : pagePadding as EdgeInsets?,
    showTitle: showTitle ?? this.showTitle,
    showPageNumber: showPageNumber ?? this.showPageNumber,
    singlePageNumberPosition:
        singlePageNumberPosition ?? this.singlePageNumberPosition,
    fullPageAlignment: fullPageAlignment ?? this.fullPageAlignment,
  );

  @override
  bool operator ==(Object other) =>
      other is KumihanLayoutData &&
      other.fontSize == fontSize &&
      other.pagePadding == pagePadding &&
      other.showTitle == showTitle &&
      other.showPageNumber == showPageNumber &&
      other.singlePageNumberPosition == singlePageNumberPosition &&
      other.fullPageAlignment == fullPageAlignment;

  @override
  int get hashCode => Object.hash(
    fontSize,
    pagePadding,
    showTitle,
    showPageNumber,
    singlePageNumberPosition,
    fullPageAlignment,
  );
}

enum KumihanWritingMode { vertical }

enum KumihanSpreadMode { single, doublePage }

@immutable
class KumihanBookLayoutData {
  const KumihanBookLayoutData({
    this.fontSize = defaultKumihanFontSize,
    this.outerPadding = EdgeInsets.zero,
    this.contentPadding = EdgeInsets.zero,
    this.pageGap = 0,
    this.showTitle = defaultKumihanShowTitle,
    this.showPageNumber = defaultKumihanShowPageNumber,
    this.singlePageNumberPosition = defaultKumihanSinglePageNumberPosition,
    this.rightPageFullPageAlignment =
        defaultKumihanBookRightPageFullPageAlignment,
    this.leftPageFullPageAlignment =
        defaultKumihanBookLeftPageFullPageAlignment,
  }) : assert(fontSize > 0),
       assert(pageGap >= 0);

  final double fontSize;
  final EdgeInsets outerPadding;
  final EdgeInsets contentPadding;
  final double pageGap;
  final bool showTitle;
  final bool showPageNumber;
  final KumihanSinglePageNumberPosition singlePageNumberPosition;
  final KumihanFullPageAlignment rightPageFullPageAlignment;
  final KumihanFullPageAlignment leftPageFullPageAlignment;

  KumihanBookLayoutData copyWith({
    double? fontSize,
    Object? outerPadding = _unsetBookOuterPadding,
    Object? contentPadding = _unsetBookContentPadding,
    double? pageGap,
    bool? showTitle,
    bool? showPageNumber,
    KumihanSinglePageNumberPosition? singlePageNumberPosition,
    KumihanFullPageAlignment? rightPageFullPageAlignment,
    KumihanFullPageAlignment? leftPageFullPageAlignment,
  }) => KumihanBookLayoutData(
    fontSize: fontSize ?? this.fontSize,
    outerPadding: identical(outerPadding, _unsetBookOuterPadding)
        ? this.outerPadding
        : outerPadding as EdgeInsets,
    contentPadding: identical(contentPadding, _unsetBookContentPadding)
        ? this.contentPadding
        : contentPadding as EdgeInsets,
    pageGap: pageGap ?? this.pageGap,
    showTitle: showTitle ?? this.showTitle,
    showPageNumber: showPageNumber ?? this.showPageNumber,
    singlePageNumberPosition:
        singlePageNumberPosition ?? this.singlePageNumberPosition,
    rightPageFullPageAlignment:
        rightPageFullPageAlignment ?? this.rightPageFullPageAlignment,
    leftPageFullPageAlignment:
        leftPageFullPageAlignment ?? this.leftPageFullPageAlignment,
  );

  @override
  bool operator ==(Object other) =>
      other is KumihanBookLayoutData &&
      other.fontSize == fontSize &&
      other.outerPadding == outerPadding &&
      other.contentPadding == contentPadding &&
      other.pageGap == pageGap &&
      other.showTitle == showTitle &&
      other.showPageNumber == showPageNumber &&
      other.singlePageNumberPosition == singlePageNumberPosition &&
      other.rightPageFullPageAlignment == rightPageFullPageAlignment &&
      other.leftPageFullPageAlignment == leftPageFullPageAlignment;

  @override
  int get hashCode => Object.hash(
    fontSize,
    outerPadding,
    contentPadding,
    pageGap,
    showTitle,
    showPageNumber,
    singlePageNumberPosition,
    rightPageFullPageAlignment,
    leftPageFullPageAlignment,
  );
}

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
