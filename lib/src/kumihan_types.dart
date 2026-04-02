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

class KumihanSnapshot {
  const KumihanSnapshot({required this.currentPage, required this.totalPages});

  final int currentPage;
  final int totalPages;

  KumihanSnapshot copyWith({int? currentPage, int? totalPages}) =>
      KumihanSnapshot(
        currentPage: currentPage ?? this.currentPage,
        totalPages: totalPages ?? this.totalPages,
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
