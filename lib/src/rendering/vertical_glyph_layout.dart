import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'kumihan_render_theme.dart';

const String _verticalSmallGlyphs =
    'ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ';
const String _verticalPunctuationGlyphs = '，、。﹐﹑﹒，．';
const String _dakutenGlyphs = '゛゜';
const String _rotatedGlyphs =
    ' '
    '‘’“”'
    '()[]{}'
    '（）〔〕［］｛｝'
    '〈〉《》「」『』【】｟｠〘〙〖〗«»〝〟'
    '…ー';

class VerticalGlyphLayout {
  const VerticalGlyphLayout({
    required this.text,
    required this.painter,
    required this.fontSize,
    required this.paintOffset,
    required this.rotation,
    required this.translateX,
    required this.translateY,
    required this.localX,
    required this.localY,
  });

  final String text;
  final TextPainter painter;
  final double fontSize;
  final Offset paintOffset;
  final double rotation;
  final double translateX;
  final double translateY;
  final double localX;
  final double localY;

  bool get isRotated => rotation != 0;
}

VerticalGlyphLayout computeVerticalGlyphLayout(
  Rect rect,
  String text,
  TextStyle style,
  KumihanRenderThemeData theme,
) {
  final normalizedText = text == '─' ? '―' : text;
  final painter = TextPainter(
    text: TextSpan(text: normalizedText, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
  )..layout(maxWidth: rect.width * 2);

  final fontSize = style.fontSize ?? theme.fontSize;
  var dx = rect.left + rect.width / 2;
  var dy = rect.top;

  if (_verticalSmallGlyphs.contains(normalizedText)) {
    dx += fontSize / 8;
    dy -= fontSize / 8;
  } else if (_verticalPunctuationGlyphs.contains(normalizedText)) {
    dx += 0.68 * fontSize;
    dy -= 0.65 * fontSize;
  }

  if (_dakutenGlyphs.contains(normalizedText)) {
    dx += 0.74 * fontSize;
    dy -= fontSize;
  }

  if (_shouldRotate(normalizedText)) {
    return VerticalGlyphLayout(
      text: normalizedText,
      painter: painter,
      fontSize: fontSize,
      paintOffset: Offset(0, -painter.height / 2),
      rotation: math.pi / 2,
      translateX: dx,
      translateY: dy,
      localX: 0,
      localY: -painter.height / 2,
    );
  }

  final paintOffset = Offset(
    dx - painter.width / 2,
    dy + fontSize / 2 - painter.height / 2,
  );
  return VerticalGlyphLayout(
    text: normalizedText,
    painter: painter,
    fontSize: fontSize,
    paintOffset: paintOffset,
    rotation: 0,
    translateX: 0,
    translateY: 0,
    localX: paintOffset.dx,
    localY: paintOffset.dy,
  );
}

bool _shouldRotate(String text) {
  if (text.isEmpty) {
    return false;
  }
  return _rotatedGlyphs.contains(text) || text == '\u2060';
}
