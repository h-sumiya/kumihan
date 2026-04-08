import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'kumihan_theme.dart';

const Color defaultKumihanBookColor = Color(0xFFD7C8AE);
const Color defaultKumihanBookPageBackgroundColor = Color(0xFFFCFBF7);
const Color defaultKumihanBookBorderColor = Color(0xFFBDB7AA);
const Object _unsetBookPaperTexture = Object();

@immutable
class KumihanBookThemeData {
  const KumihanBookThemeData({
    this.paperColor,
    Object? paperTexture = _unsetBookPaperTexture,
    this.paperTextureOpacity,
    this.backPageOpacity,
    this.bookColor = defaultKumihanBookColor,
    this.pageBackgroundColor = defaultKumihanBookPageBackgroundColor,
    this.borderColor = defaultKumihanBookBorderColor,
  }) : _paperTexture = paperTexture;

  final Color? paperColor;
  final Object? _paperTexture;
  final double? paperTextureOpacity;
  final double? backPageOpacity;
  final Color bookColor;
  final Color pageBackgroundColor;
  final Color borderColor;

  ImageProvider<Object>? get paperTexture {
    if (identical(_paperTexture, _unsetBookPaperTexture)) {
      return null;
    }
    return _paperTexture as ImageProvider<Object>?;
  }

  bool get overridesPaperTexture =>
      !identical(_paperTexture, _unsetBookPaperTexture);

  KumihanThemeData applyTo(KumihanThemeData theme) {
    return theme.copyWith(
      paperColor: paperColor ?? theme.paperColor,
      paperTexture: overridesPaperTexture ? paperTexture : theme.paperTexture,
      paperTextureOpacity: paperTextureOpacity ?? theme.paperTextureOpacity,
      backPageOpacity: backPageOpacity ?? theme.backPageOpacity,
    );
  }

  KumihanBookThemeData copyWith({
    Color? paperColor,
    Object? paperTexture = _unsetBookPaperTexture,
    double? paperTextureOpacity,
    double? backPageOpacity,
    Color? bookColor,
    Color? pageBackgroundColor,
    Color? borderColor,
  }) {
    return KumihanBookThemeData(
      paperColor: paperColor ?? this.paperColor,
      paperTexture: identical(paperTexture, _unsetBookPaperTexture)
          ? _paperTexture
          : paperTexture,
      paperTextureOpacity: paperTextureOpacity ?? this.paperTextureOpacity,
      backPageOpacity: backPageOpacity ?? this.backPageOpacity,
      bookColor: bookColor ?? this.bookColor,
      pageBackgroundColor: pageBackgroundColor ?? this.pageBackgroundColor,
      borderColor: borderColor ?? this.borderColor,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KumihanBookThemeData &&
        other.paperColor == paperColor &&
        other._paperTexture == _paperTexture &&
        other.paperTextureOpacity == paperTextureOpacity &&
        other.backPageOpacity == backPageOpacity &&
        other.bookColor == bookColor &&
        other.pageBackgroundColor == pageBackgroundColor &&
        other.borderColor == borderColor;
  }

  @override
  int get hashCode => Object.hash(
    paperColor,
    _paperTexture,
    paperTextureOpacity,
    backPageOpacity,
    bookColor,
    pageBackgroundColor,
    borderColor,
  );
}
