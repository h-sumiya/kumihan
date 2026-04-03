import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'engine/constants.dart' as engine;

const Color defaultKumihanTextColor = engine.fontColor;
const Color defaultKumihanCaptionColor = engine.captionColor;
const Color defaultKumihanLinkColor = Color(0xff3559d9);
const Color defaultKumihanInternalLinkColor = Color(0xff1d8a56);

@immutable
class KumihanThemeData {
  const KumihanThemeData({
    this.textColor = defaultKumihanTextColor,
    this.captionColor = defaultKumihanCaptionColor,
    this.linkColor = defaultKumihanLinkColor,
    this.internalLinkColor = defaultKumihanInternalLinkColor,
    Color? rubyColor,
  }) : rubyColor = rubyColor ?? textColor;

  final Color textColor;
  final Color captionColor;
  final Color rubyColor;
  final Color linkColor;
  final Color internalLinkColor;

  KumihanThemeData copyWith({
    Color? textColor,
    Color? captionColor,
    Color? rubyColor,
    Color? linkColor,
    Color? internalLinkColor,
  }) {
    return KumihanThemeData(
      textColor: textColor ?? this.textColor,
      captionColor: captionColor ?? this.captionColor,
      rubyColor: rubyColor ?? this.rubyColor,
      linkColor: linkColor ?? this.linkColor,
      internalLinkColor: internalLinkColor ?? this.internalLinkColor,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KumihanThemeData &&
        other.textColor == textColor &&
        other.captionColor == captionColor &&
        other.rubyColor == rubyColor &&
        other.linkColor == linkColor &&
        other.internalLinkColor == internalLinkColor;
  }

  @override
  int get hashCode => Object.hash(
    textColor,
    captionColor,
    rubyColor,
    linkColor,
    internalLinkColor,
  );
}
