import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';

import '../layout_result/compat/utr50.dart';
import 'kumihan_render_theme.dart';

const String _verticalSmallGlyphs = 'ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ';
const String _verticalPunctuationGlyphs = '，、。﹐﹑﹒，．';
const String _dakutenGlyphs = '゛゜';
const String _rotatedGlyphs =
    ' '
    '‘’“”'
    '()[]{}'
    '（）〔〕［］｛｝'
    '〈〉《》「」『』【】｟｠〘〙〖〗«»〝〟'
    '…ー─';

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
  final rotate = _shouldRotate(text);
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
  )..layout(maxWidth: rotate ? 100000 : rect.width * 2);

  final fontSize = style.fontSize ?? theme.fontSize;
  var dx = rect.left + rect.width / 2;
  var dy = rect.top;

  if (_verticalSmallGlyphs.contains(text)) {
    dx += fontSize / 8;
    dy -= fontSize / 8;
  } else if (_verticalPunctuationGlyphs.contains(text)) {
    dx += 0.68 * fontSize;
    dy -= 0.65 * fontSize;
  }

  if (_dakutenGlyphs.contains(text)) {
    dx += 0.74 * fontSize;
    dy -= fontSize;
  }

  if (rotate) {
    return VerticalGlyphLayout(
      text: text,
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
    text: text,
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

bool shouldRotateVerticalGlyph(String text) => _shouldRotate(text);

bool _shouldRotate(String text) {
  if (text.isEmpty) {
    return false;
  }
  if (text == '―') {
    return false;
  }
  var sawSideways = false;
  for (final character in text.characters) {
    if (character == '\u2060') {
      sawSideways = true;
      continue;
    }
    if (_rotatedGlyphs.contains(character)) {
      sawSideways = true;
      continue;
    }
    final type = getUtr50Type(character.runes.firstOrNull);
    if (type == 'R' || type == 'r') {
      sawSideways = true;
      continue;
    }
    return false;
  }
  return sawSideways;
}
