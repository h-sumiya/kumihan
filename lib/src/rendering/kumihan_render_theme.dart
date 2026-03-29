import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../layout_result/layout_result.dart';

const Color defaultKumihanRenderPaperColor = Color(0xfffffdf1);
const Color defaultKumihanRenderTextColor = Color(0xff444444);
const Color defaultKumihanRenderLinkColor = Color(0xff3559d9);
const Color defaultKumihanRenderNoteColor = Color(0xff446644);
const Color defaultKumihanRenderMarkerColor = Color(0x66755733);
const Color defaultKumihanRenderGuideColor = Color(0x22665522);
const Color defaultKumihanRenderBannerColor = Color(0xddb85c38);

@immutable
class KumihanRenderThemeData {
  const KumihanRenderThemeData({
    this.paperColor = defaultKumihanRenderPaperColor,
    this.textColor = defaultKumihanRenderTextColor,
    Color? rubyColor,
    this.noteColor = defaultKumihanRenderNoteColor,
    this.linkColor = defaultKumihanRenderLinkColor,
    this.markerColor = defaultKumihanRenderMarkerColor,
    this.guideColor = defaultKumihanRenderGuideColor,
    this.provisionalBannerColor = defaultKumihanRenderBannerColor,
    this.fontSize = 18,
    this.fontFamily,
    this.fontFamilyFallback = const <String>[],
    this.pagePadding = const EdgeInsets.fromLTRB(24, 24, 24, 24),
    this.lineGapEm = 0.65,
    this.blockGapEm = 1.2,
    this.rubyScale = 0.5,
    this.scriptScale = 0.6,
    this.noteScale = 0.5,
    this.minTableCellLineExtent = 6,
    this.showGuides = false,
    this.showDiagnosticsOverlay = true,
    this.showProvisionalBanner = true,
    this.provisionalLabel = 'v1 provisional renderer',
  }) : assert(fontSize > 0),
       assert(lineGapEm >= 0),
       assert(blockGapEm >= 0),
       assert(rubyScale > 0),
       assert(scriptScale > 0),
       assert(noteScale > 0),
       rubyColor = rubyColor ?? textColor;

  final Color paperColor;
  final Color textColor;
  final Color rubyColor;
  final Color noteColor;
  final Color linkColor;
  final Color markerColor;
  final Color guideColor;
  final Color provisionalBannerColor;
  final double fontSize;
  final String? fontFamily;
  final List<String> fontFamilyFallback;
  final EdgeInsets pagePadding;
  final double lineGapEm;
  final double blockGapEm;
  final double rubyScale;
  final double scriptScale;
  final double noteScale;
  final double minTableCellLineExtent;
  final bool showGuides;
  final bool showDiagnosticsOverlay;
  final bool showProvisionalBanner;
  final String provisionalLabel;

  LayoutConstraints constraintsFor(Size size) {
    final availableHeight = math.max(
      size.height - pagePadding.vertical,
      fontSize,
    );
    return LayoutConstraints(
      writingMode: LayoutWritingMode.vertical,
      lineExtent: math.max(availableHeight / fontSize, 1),
      lineGap: lineGapEm,
      blockGap: blockGapEm,
      baseFontSize: 1,
      rubyScale: rubyScale,
      scriptScale: scriptScale,
      noteScale: noteScale,
      minTableCellLineExtent: minTableCellLineExtent,
    );
  }

  KumihanRenderThemeData copyWith({
    Color? paperColor,
    Color? textColor,
    Color? rubyColor,
    Color? noteColor,
    Color? linkColor,
    Color? markerColor,
    Color? guideColor,
    Color? provisionalBannerColor,
    double? fontSize,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    EdgeInsets? pagePadding,
    double? lineGapEm,
    double? blockGapEm,
    double? rubyScale,
    double? scriptScale,
    double? noteScale,
    double? minTableCellLineExtent,
    bool? showGuides,
    bool? showDiagnosticsOverlay,
    bool? showProvisionalBanner,
    String? provisionalLabel,
  }) {
    return KumihanRenderThemeData(
      paperColor: paperColor ?? this.paperColor,
      textColor: textColor ?? this.textColor,
      rubyColor: rubyColor ?? this.rubyColor,
      noteColor: noteColor ?? this.noteColor,
      linkColor: linkColor ?? this.linkColor,
      markerColor: markerColor ?? this.markerColor,
      guideColor: guideColor ?? this.guideColor,
      provisionalBannerColor:
          provisionalBannerColor ?? this.provisionalBannerColor,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      pagePadding: pagePadding ?? this.pagePadding,
      lineGapEm: lineGapEm ?? this.lineGapEm,
      blockGapEm: blockGapEm ?? this.blockGapEm,
      rubyScale: rubyScale ?? this.rubyScale,
      scriptScale: scriptScale ?? this.scriptScale,
      noteScale: noteScale ?? this.noteScale,
      minTableCellLineExtent:
          minTableCellLineExtent ?? this.minTableCellLineExtent,
      showGuides: showGuides ?? this.showGuides,
      showDiagnosticsOverlay:
          showDiagnosticsOverlay ?? this.showDiagnosticsOverlay,
      showProvisionalBanner:
          showProvisionalBanner ?? this.showProvisionalBanner,
      provisionalLabel: provisionalLabel ?? this.provisionalLabel,
    );
  }
}
