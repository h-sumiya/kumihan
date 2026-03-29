import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'engine/constants.dart' as engine;

const Color defaultKumihanPaperColor = Color(engine.paperColorValue);
const Color defaultKumihanTextColor = engine.fontColor;
const Color defaultKumihanCaptionColor = engine.captionColor;
const Color defaultKumihanLinkColor = Color(0xff3559d9);
const Color defaultKumihanInternalLinkColor = Color(0xff1d8a56);

const Object _unsetPaperTexture = Object();

@immutable
class KumihanThemeData {
  const KumihanThemeData({
    this.paperColor = defaultKumihanPaperColor,
    this.textColor = defaultKumihanTextColor,
    this.captionColor = defaultKumihanCaptionColor,
    this.linkColor = defaultKumihanLinkColor,
    this.internalLinkColor = defaultKumihanInternalLinkColor,
    this.paperTexture,
    this.paperTextureOpacity = 0.18,
    this.backPageOpacity = 0.08,
    Color? rubyColor,
  }) : rubyColor = rubyColor ?? textColor;

  final Color paperColor;
  final Color textColor;
  final Color captionColor;
  final Color rubyColor;
  final Color linkColor;
  final Color internalLinkColor;
  final ImageProvider<Object>? paperTexture;
  final double paperTextureOpacity;
  final double backPageOpacity;

  bool get isDark => paperColor.computeLuminance() < 0.35;

  KumihanThemeData copyWith({
    Color? paperColor,
    Color? textColor,
    Color? captionColor,
    Color? rubyColor,
    Color? linkColor,
    Color? internalLinkColor,
    Object? paperTexture = _unsetPaperTexture,
    double? paperTextureOpacity,
    double? backPageOpacity,
  }) {
    return KumihanThemeData(
      paperColor: paperColor ?? this.paperColor,
      textColor: textColor ?? this.textColor,
      captionColor: captionColor ?? this.captionColor,
      rubyColor: rubyColor ?? this.rubyColor,
      linkColor: linkColor ?? this.linkColor,
      internalLinkColor: internalLinkColor ?? this.internalLinkColor,
      paperTexture: identical(paperTexture, _unsetPaperTexture)
          ? this.paperTexture
          : paperTexture as ImageProvider<Object>?,
      paperTextureOpacity: paperTextureOpacity ?? this.paperTextureOpacity,
      backPageOpacity: backPageOpacity ?? this.backPageOpacity,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KumihanThemeData &&
        other.paperColor == paperColor &&
        other.textColor == textColor &&
        other.captionColor == captionColor &&
        other.rubyColor == rubyColor &&
        other.linkColor == linkColor &&
        other.internalLinkColor == internalLinkColor &&
        other.paperTexture == paperTexture &&
        other.paperTextureOpacity == paperTextureOpacity &&
        other.backPageOpacity == backPageOpacity;
  }

  @override
  int get hashCode => Object.hash(
    paperColor,
    textColor,
    captionColor,
    rubyColor,
    linkColor,
    internalLinkColor,
    paperTexture,
    paperTextureOpacity,
    backPageOpacity,
  );
}
