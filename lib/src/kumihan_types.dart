import 'package:flutter/foundation.dart';

enum KumihanWritingMode { vertical, horizontal }

enum KumihanSpreadMode { single, doublePage }

const double defaultKumihanFontSize = 18;
const double defaultKumihanPageMarginScale = 1;

@immutable
class KumihanLayoutData {
  const KumihanLayoutData({
    this.fontSize = defaultKumihanFontSize,
    this.pageMarginScale = defaultKumihanPageMarginScale,
  }) : assert(fontSize > 0),
       assert(pageMarginScale > 0);

  final double fontSize;
  final double pageMarginScale;

  KumihanLayoutData copyWith({double? fontSize, double? pageMarginScale}) {
    return KumihanLayoutData(
      fontSize: fontSize ?? this.fontSize,
      pageMarginScale: pageMarginScale ?? this.pageMarginScale,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KumihanLayoutData &&
        other.fontSize == fontSize &&
        other.pageMarginScale == pageMarginScale;
  }

  @override
  int get hashCode => Object.hash(fontSize, pageMarginScale);
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
