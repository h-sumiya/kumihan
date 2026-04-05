import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const double defaultKumihanFontSize = 18;
const EdgeInsets? defaultKumihanPagePadding = null;
const bool defaultKumihanShowTitle = true;
const bool defaultKumihanShowPageNumber = true;
const Object _unsetPagePadding = Object();
const Object _unsetBookTopUiPadding = Object();
const Object _unsetBookBodyPadding = Object();
const Object _unsetBookBottomUiPadding = Object();

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
class KumihanBookBodyPadding {
  const KumihanBookBodyPadding({
    this.top = 0,
    this.inner = 0,
    this.outer = 0,
    this.bottom = 0,
  }) : assert(top >= 0),
       assert(inner >= 0),
       assert(outer >= 0),
       assert(bottom >= 0);

  final double top;
  final double inner;
  final double outer;
  final double bottom;

  KumihanBookBodyPadding copyWith({
    double? top,
    double? inner,
    double? outer,
    double? bottom,
  }) => KumihanBookBodyPadding(
    top: top ?? this.top,
    inner: inner ?? this.inner,
    outer: outer ?? this.outer,
    bottom: bottom ?? this.bottom,
  );

  @override
  bool operator ==(Object other) =>
      other is KumihanBookBodyPadding &&
      other.top == top &&
      other.inner == inner &&
      other.outer == outer &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(top, inner, outer, bottom);
}

@immutable
class KumihanBookLayoutData {
  const KumihanBookLayoutData({
    this.fontSize = defaultKumihanFontSize,
    this.topUiPadding = EdgeInsets.zero,
    this.bodyPadding = const KumihanBookBodyPadding(),
    this.bottomUiPadding = EdgeInsets.zero,
    this.showTitle = defaultKumihanShowTitle,
    this.showPageNumber = defaultKumihanShowPageNumber,
    this.singlePageNumberPosition = defaultKumihanSinglePageNumberPosition,
    this.rightPageFullPageAlignment =
        defaultKumihanBookRightPageFullPageAlignment,
    this.leftPageFullPageAlignment =
        defaultKumihanBookLeftPageFullPageAlignment,
  }) : assert(fontSize > 0);

  final double fontSize;
  final EdgeInsets topUiPadding;
  final KumihanBookBodyPadding bodyPadding;
  final EdgeInsets bottomUiPadding;
  final bool showTitle;
  final bool showPageNumber;
  final KumihanSinglePageNumberPosition singlePageNumberPosition;
  final KumihanFullPageAlignment rightPageFullPageAlignment;
  final KumihanFullPageAlignment leftPageFullPageAlignment;

  KumihanBookLayoutData copyWith({
    double? fontSize,
    Object? topUiPadding = _unsetBookTopUiPadding,
    Object? bodyPadding = _unsetBookBodyPadding,
    Object? bottomUiPadding = _unsetBookBottomUiPadding,
    bool? showTitle,
    bool? showPageNumber,
    KumihanSinglePageNumberPosition? singlePageNumberPosition,
    KumihanFullPageAlignment? rightPageFullPageAlignment,
    KumihanFullPageAlignment? leftPageFullPageAlignment,
  }) => KumihanBookLayoutData(
    fontSize: fontSize ?? this.fontSize,
    topUiPadding: identical(topUiPadding, _unsetBookTopUiPadding)
        ? this.topUiPadding
        : topUiPadding as EdgeInsets,
    bodyPadding: identical(bodyPadding, _unsetBookBodyPadding)
        ? this.bodyPadding
        : bodyPadding as KumihanBookBodyPadding,
    bottomUiPadding: identical(bottomUiPadding, _unsetBookBottomUiPadding)
        ? this.bottomUiPadding
        : bottomUiPadding as EdgeInsets,
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
      other.topUiPadding == topUiPadding &&
      other.bodyPadding == bodyPadding &&
      other.bottomUiPadding == bottomUiPadding &&
      other.showTitle == showTitle &&
      other.showPageNumber == showPageNumber &&
      other.singlePageNumberPosition == singlePageNumberPosition &&
      other.rightPageFullPageAlignment == rightPageFullPageAlignment &&
      other.leftPageFullPageAlignment == leftPageFullPageAlignment;

  @override
  int get hashCode => Object.hash(
    fontSize,
    topUiPadding,
    bodyPadding,
    bottomUiPadding,
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
