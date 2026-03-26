import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

const Object _unsetPagePadding = Object();

enum KumihanWritingMode { vertical, horizontal }

enum KumihanSpreadMode { single, doublePage }

const double defaultKumihanFontSize = 18;
const EdgeInsets? defaultKumihanPagePadding = null;
const bool defaultKumihanShowTitle = true;
const bool defaultKumihanShowPageNumber = true;

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
  }) {
    return KumihanLayoutData(
      fontSize: fontSize ?? this.fontSize,
      pagePadding: identical(pagePadding, _unsetPagePadding)
          ? this.pagePadding
          : pagePadding as EdgeInsets?,
      showTitle: showTitle ?? this.showTitle,
      showPageNumber: showPageNumber ?? this.showPageNumber,
      singlePageNumberPosition:
          singlePageNumberPosition ?? this.singlePageNumberPosition,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KumihanLayoutData &&
        other.fontSize == fontSize &&
        other.pagePadding == pagePadding &&
        other.showTitle == showTitle &&
        other.showPageNumber == showPageNumber &&
        other.singlePageNumberPosition == singlePageNumberPosition;
  }

  @override
  int get hashCode => Object.hash(
    fontSize,
    pagePadding,
    showTitle,
    showPageNumber,
    singlePageNumberPosition,
  );
}

class KumihanSnapshot {
  const KumihanSnapshot({
    required this.currentPage,
    required this.spreadMode,
    required this.totalPages,
    required this.writingMode,
  });

  final int currentPage;
  final KumihanSpreadMode spreadMode;
  final int totalPages;
  final KumihanWritingMode writingMode;

  KumihanSnapshot copyWith({
    int? currentPage,
    KumihanSpreadMode? spreadMode,
    int? totalPages,
    KumihanWritingMode? writingMode,
  }) {
    return KumihanSnapshot(
      currentPage: currentPage ?? this.currentPage,
      spreadMode: spreadMode ?? this.spreadMode,
      totalPages: totalPages ?? this.totalPages,
      writingMode: writingMode ?? this.writingMode,
    );
  }
}
