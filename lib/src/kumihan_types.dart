import 'dart:ui';

import 'package:flutter/foundation.dart';

const double defaultKumihanFontSize = 18;

@immutable
class KumihanLayoutData {
  const KumihanLayoutData({this.fontSize = defaultKumihanFontSize})
    : assert(fontSize > 0);

  final double fontSize;

  KumihanLayoutData copyWith({double? fontSize}) =>
      KumihanLayoutData(fontSize: fontSize ?? this.fontSize);

  @override
  bool operator ==(Object other) =>
      other is KumihanLayoutData && other.fontSize == fontSize;

  @override
  int get hashCode => fontSize.hashCode;
}

enum KumihanWritingMode { vertical }

enum KumihanSpreadMode { single }

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
