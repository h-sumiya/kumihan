import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../debug/render_trace.dart';
import 'constants.dart';
import 'helpers.dart';
import 'line_breaker.dart';
import 'utr50.dart';

class LayoutBlockUserData {
  LayoutBlockUserData({
    List<LayoutExtra>? extras,
    List<LayoutInsert>? inserts,
    List<LayoutRuby>? rubies,
  }) : extras = extras ?? <LayoutExtra>[],
       inserts = inserts ?? <LayoutInsert>[],
       rubies = rubies ?? <LayoutRuby>[];

  final List<LayoutExtra> extras;
  final List<LayoutInsert> inserts;
  final List<LayoutRuby> rubies;
}

enum LayoutAnnotationKind {
  unsupported,
  outsideImage,
  inlineImage,
  link,
  ruledLine,
  tcy,
  textStyle,
  warichu,
  midashi,
  anchor,
  kaeritenKunten,
  inlineStyleDash,
  inlineStyleSmall,
  inlineStyleCombined,
  kaeri,
  naka,
  okuri,
  rightRuby,
  leftRuby,
  frame,
  span,
  emphasis,
  noteReference,
  note,
}

enum LayoutInlineDecorationKind {
  rightRuby,
  leftRuby,
  kaeri,
  naka,
  okuri,
  referenceNote,
  annotationNote,
  rightEmphasis,
  leftEmphasis,
}

enum LayoutExtraType {
  unsupported,
  frame,
  outsideImage,
  inlineImage,
  link,
  ruledLine,
  tcy,
  textStyle,
  warichu,
  noteReference,
  span,
  emphasis,
  note,
}

class LayoutInsert {
  LayoutInsert({
    required this.startIndex,
    required this.text,
    required this.type,
    this.tl,
  });

  final int startIndex;
  final String text;
  LayoutTextLine? tl;
  final LayoutInlineDecorationKind type;
}

class LayoutStyleSpan {
  LayoutStyleSpan({
    required this.endIndex,
    required this.startIndex,
    required this.type,
  });

  final int endIndex;
  final int startIndex;
  final String type;
}

class LayoutRuby {
  LayoutRuby({
    required this.endIndex,
    required this.ruby,
    required this.spans,
    required this.startIndex,
    required this.type,
    this.tb,
    this.trackingEnd = 0,
    this.trackingStart = 0,
  });

  final int endIndex;
  final String ruby;
  final List<LayoutStyleSpan> spans;
  final int startIndex;
  LayoutTextBlock? tb;
  double trackingEnd;
  double trackingStart;
  final LayoutInlineDecorationKind type;
}

class LayoutExtra {
  LayoutExtra({
    required this.type,
    this.imageHeight,
    this.imageWidth,
    this.endIndex,
    this.linkTarget,
    this.ruby,
    this.startIndex,
    this.style,
  });

  final int? endIndex;
  final double? imageHeight;
  final double? imageWidth;
  final String? linkTarget;
  final String? ruby;
  final int? startIndex;
  final String? style;
  final LayoutExtraType type;
}

const String _sidewaysCloseGlyphs = '$closingBrackets$punctuationMarks・￼゛゜';
const String _rotatedAtomTypes = '…─';
const String _verticalSmallGlyphs = 'ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶㇰㇱㇲㇳㇴㇵㇶㇷㇸㇹㇺㇻㇼㇽㇾㇿ';
const String _verticalPunctuationGlyphs = '，、。﹐﹑﹒，．';

class MeasuredText {
  MeasuredText({
    required this.painter,
    required this.ascent,
    required this.descent,
    required this.width,
  });

  final TextPainter painter;
  final double ascent;
  final double descent;
  final double width;
}

abstract interface class LayoutEnvironment {
  Color get fontColor;
  Color get paperColor;
  List<String> get gothicFontFamilies;
  List<String> get fixedGothicFontFamilies;
  List<String> get fixedMinchoFontFamilies;
  List<String> get minchoFontFamilies;
  MeasuredText layoutText(LayoutAtom atom, String text, Color color);
}

class LayoutAtom {
  LayoutAtom(
    this.index,
    String characterType,
    double fontSize,
    int fontType, {
    bool bold = false,
    bool italic = false,
    bool kinsoku = false,
  }) : _fontSize = fontSize,
       _fontType = fontType,
       _bold = bold,
       _italic = italic,
       _kinsoku = kinsoku,
       _rotated = false,
       _r = characterType == 'R' || characterType == 'r',
       _t = characterType == 'u' || characterType == 'r';

  int index;
  double offsetX = 0;
  double offsetY = 0;
  double tracking = 0;
  Color? color;
  double? width;
  double? height;
  ui.Image? image;
  ui.Picture? picture;

  double _fontSize;
  int _fontType;
  bool _kinsoku;
  bool _rotated;
  bool _r;
  bool _t;
  bool _bold;
  bool _italic;

  LayoutAtom clone(int nextIndex, {bool includeKinsoku = false}) {
    final atom = LayoutAtom(
      nextIndex,
      'R',
      _fontSize,
      _fontType,
      bold: _bold,
      italic: _italic,
      kinsoku: includeKinsoku ? _kinsoku : false,
    );
    atom._rotated = _rotated;
    atom._r = _r;
    atom._t = _t;
    atom.offsetX = offsetX;
    atom.offsetY = offsetY;
    atom.tracking = tracking;
    atom.color = color;
    atom.width = width;
    atom.height = height;
    atom.image = image;
    atom.picture = picture;
    return atom;
  }

  LayoutAtom setKinsoku([bool enabled = true]) {
    _kinsoku = enabled;
    return this;
  }

  bool isKinsoku() => _kinsoku;

  double getFontSize() => _fontSize;

  double getWidth() => width ?? _fontSize;

  void setFontSize(double size) {
    _fontSize = size;
  }

  LayoutAtom setRotated() {
    _rotated = true;
    return setR();
  }

  bool isRotated() => _rotated;

  LayoutAtom setR([bool enabled = true]) {
    _r = enabled;
    return this;
  }

  bool getR() => _r;

  LayoutAtom setT([bool enabled = true]) {
    _t = enabled;
    return this;
  }

  bool getT() => _t;

  LayoutAtom setFontType([int type = 0]) {
    _fontType = type;
    return this;
  }

  LayoutAtom setFontMincho() {
    _fontType &= ~2;
    return this;
  }

  LayoutAtom setFontGothic() {
    _fontType |= 2;
    return this;
  }

  LayoutAtom setFontProportional() {
    _fontType &= ~1;
    return this;
  }

  LayoutAtom setFontFixed() {
    _fontType |= 1;
    return this;
  }

  LayoutAtom setFontBold([bool enabled = true]) {
    _bold = enabled;
    return this;
  }

  LayoutAtom setFontItalic([bool enabled = true]) {
    _italic = enabled;
    return this;
  }

  void setFont(int font) {
    _fontType = font;
  }

  TextStyle createTextStyle(LayoutEnvironment environment, {Color? color}) {
    final families = switch (_fontType & 3) {
      0 => environment.minchoFontFamilies,
      1 => environment.fixedMinchoFontFamilies,
      2 => environment.gothicFontFamilies,
      _ => environment.fixedGothicFontFamilies,
    };

    return TextStyle(
      color: color,
      fontFamily: families.firstOrNull,
      fontFamilyFallback: families.length > 1 ? families.sublist(1) : null,
      package: bundledFontPackage,
      fontSize: _fontSize,
      fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.ideographic,
    );
  }
}

sealed class LayoutTextLineAttachment {
  const LayoutTextLineAttachment();
}

class InlineDecorationAttachment extends LayoutTextLineAttachment {
  const InlineDecorationAttachment({required this.kind, required this.line});

  final LayoutInlineDecorationKind kind;
  final LayoutTextLine line;
}

sealed class LayoutLineMark extends LayoutTextLineAttachment {
  const LayoutLineMark();
}

class NoteMarker extends LayoutLineMark {
  const NoteMarker({
    required this.annotation,
    required this.height,
    required this.markType,
    required this.top,
    required this.width,
  });

  final String annotation;
  final double height;
  final String markType;
  final double top;
  final double width;
}

class SpanMarker extends LayoutLineMark {
  const SpanMarker({
    required this.bottom,
    required this.markType,
    required this.top,
    this.isEnd,
    this.isStart,
  });

  final double bottom;
  final bool? isEnd;
  final bool? isStart;
  final String markType;
  final double top;
}

class LinkMarker extends LayoutLineMark {
  const LinkMarker({
    required this.endAtom,
    required this.linkTarget,
    required this.startAtom,
  }) : markType = 'リンク';

  final int endAtom;
  final String linkTarget;
  final String markType;
  final int startAtom;
}

class WarichuMarker extends LayoutLineMark {
  const WarichuMarker({required this.lowerLine, required this.upperLine});

  final LayoutTextLine? lowerLine;
  final LayoutTextLine? upperLine;
}

class LayoutTextLine {
  LayoutTextLine(this.block, this.start, this.end, this.width, this.textWidth);

  final LayoutTextBlock block;
  final int start;
  final int end;
  final double width;
  final double textWidth;
  LayoutTextLine? nextLine;
  double y = 0;
  double x = 0;
  int? pageIndex;
  Color? color;
  final Map<LayoutInlineDecorationKind, double> rubyBottom =
      <LayoutInlineDecorationKind, double>{
        LayoutInlineDecorationKind.rightRuby: 0,
        LayoutInlineDecorationKind.leftRuby: 0,
      };
  final List<LayoutTextLineAttachment> attachments =
      <LayoutTextLineAttachment>[];

  double getAtomY(int atomIndex, {bool includeTrailingTracking = false}) {
    var offset = 0.0;
    for (var index = start; index < atomIndex; index += 1) {
      offset += block.getAtomHeight(index, includeTracking: true);
    }

    if (includeTrailingTracking && atomIndex < block.atom.length) {
      offset += block.atom[atomIndex].tracking;
    }

    return offset;
  }

  int? getAtomFromY(double position) {
    var current = y;
    for (var index = start; index < end; index += 1) {
      current += block.getAtomHeight(index, includeTracking: true);
      if (position < current) {
        return index;
      }
    }
    return null;
  }

  void draw(
    ui.Canvas canvas,
    double baseX,
    double baseY, {
    bool backPage = false,
    KumihanRenderCommandSink? traceSink,
  }) {
    final environment = block.environment;

    for (var index = start; index < end; index += 1) {
      final atom = block.atom[index];
      var x = baseX + width / 2 + atom.offsetX;
      var y = baseY + this.y + atom.offsetY + atom.tracking;
      final atomHeight = block.getAtomHeight(index);

      if (atom.picture != null) {
        final pictureWidth = atom.width!;
        final pictureHeight = atom.height!;
        final rect = Rect.fromLTWH(
          x - pictureWidth / 2,
          y,
          pictureWidth,
          pictureHeight,
        );
        canvas.save();
        canvas.translate(rect.left, rect.top);
        canvas.scale(rect.width / pictureWidth, rect.height / pictureHeight);
        canvas.drawPicture(atom.picture!);
        canvas.restore();
        traceSink?.call(
          KumihanRenderCommand(
            kind: 'picture',
            translateX: rect.left,
            translateY: rect.top,
            width: pictureWidth,
            height: pictureHeight,
            scaleX: rect.width / pictureWidth,
            scaleY: rect.height / pictureHeight,
            data: <String, Object?>{'atomIndex': index, 'backPage': backPage},
          ),
        );
      } else if (atom.image != null) {
        final imageWidth = atom.width!;
        final imageHeight = atom.height!;
        final rect = Rect.fromLTWH(
          x - imageWidth / 2,
          y,
          imageWidth,
          imageHeight,
        );
        final paint = Paint();
        if (!backPage) {
          paint.colorFilter = ColorFilter.mode(
            environment.paperColor,
            BlendMode.modulate,
          );
        }
        canvas.drawImageRect(
          atom.image!,
          Rect.fromLTWH(
            0,
            0,
            atom.image!.width.toDouble(),
            atom.image!.height.toDouble(),
          ),
          rect,
          paint,
        );
        traceSink?.call(
          KumihanRenderCommand(
            kind: 'image',
            translateX: rect.left,
            translateY: rect.top,
            width: atom.image!.width.toDouble(),
            height: atom.image!.height.toDouble(),
            scaleX: rect.width / atom.image!.width,
            scaleY: rect.height / atom.image!.height,
            data: <String, Object?>{'atomIndex': index, 'backPage': backPage},
          ),
        );
      } else {
        final text = block.getAtomText(index);
        if (text != '￼') {
          final fontSize = atom.getFontSize();
          final textColor = atom.color ?? color ?? environment.fontColor;
          final measured = environment.layoutText(atom, text, textColor);
          final painter = measured.painter;

          canvas.save();
          if (atom.getR()) {
            var translatedY = y;
            if (text == '゛' || text == '゜') {
              translatedY -= 0.26 * fontSize;
            }
            canvas.translate(x, translatedY);
            canvas.rotate(0.5 * 3.1415926535897932);
            painter.paint(
              canvas,
              const Offset(0, 0) - Offset(0, painter.height / 2),
            );
            traceSink?.call(
              KumihanRenderCommand(
                kind: 'glyph',
                text: text,
                translateX: x,
                translateY: translatedY,
                localX: 0,
                localY: -painter.height / 2,
                width: painter.width,
                height: painter.height,
                rotation: 0.5 * 3.1415926535897932,
                data: <String, Object?>{
                  'atomIndex': index,
                  'backPage': backPage,
                  'fontSize': fontSize,
                  'rotated': true,
                },
              ),
            );
          } else {
            if (atom.getT()) {
              if (_verticalSmallGlyphs.contains(text)) {
                x += fontSize / 8;
                y -= fontSize / 8;
              } else if (_verticalPunctuationGlyphs.contains(text)) {
                x += 0.68 * fontSize;
                y -= 0.65 * fontSize;
              }

              if (text == '゛' || text == '゜') {
                x += 0.74 * fontSize;
                y -= fontSize;
              }
            }

            painter.paint(
              canvas,
              Offset(
                x - painter.width / 2,
                y + fontSize / 2 - painter.height / 2,
              ),
            );
            traceSink?.call(
              KumihanRenderCommand(
                kind: 'glyph',
                text: text,
                localX: x - painter.width / 2,
                localY: y + fontSize / 2 - painter.height / 2,
                width: painter.width,
                height: painter.height,
                data: <String, Object?>{
                  'atomIndex': index,
                  'backPage': backPage,
                  'fontSize': fontSize,
                  'rotated': false,
                },
              ),
            );
          }
          canvas.restore();
        }
      }

      baseY += atomHeight + atom.tracking;
    }
  }

  void drawYoko(
    ui.Canvas canvas,
    double baseX,
    double baseY, {
    bool backPage = false,
    KumihanRenderCommandSink? traceSink,
  }) {
    final environment = block.environment;

    for (var index = start; index < end; index += 1) {
      final atom = block.atom[index];
      final baseline = baseY - atom.offsetX;
      var x = baseX + y + atom.offsetY + atom.tracking;
      final atomHeight = block.getAtomHeight(index);

      if (atom.picture != null) {
        final pictureHeight = atom.height!;
        final pictureWidth = atom.width!;
        final rect = Rect.fromLTWH(
          x,
          baseline - pictureWidth / 2,
          pictureHeight,
          pictureWidth,
        );
        canvas.save();
        canvas.translate(rect.left, rect.top);
        canvas.scale(rect.width / pictureHeight, rect.height / pictureWidth);
        canvas.drawPicture(atom.picture!);
        canvas.restore();
        traceSink?.call(
          KumihanRenderCommand(
            kind: 'picture',
            translateX: rect.left,
            translateY: rect.top,
            width: pictureHeight,
            height: pictureWidth,
            scaleX: rect.width / pictureHeight,
            scaleY: rect.height / pictureWidth,
            data: <String, Object?>{
              'atomIndex': index,
              'backPage': backPage,
              'writingMode': 'horizontal',
            },
          ),
        );
      } else if (atom.image != null) {
        final imageHeight = atom.height!;
        final imageWidth = atom.width!;
        final rect = Rect.fromLTWH(
          x,
          baseline - imageWidth / 2,
          imageHeight,
          imageWidth,
        );
        final paint = Paint();
        if (!backPage) {
          paint.colorFilter = ColorFilter.mode(
            environment.paperColor,
            BlendMode.modulate,
          );
        }
        canvas.drawImageRect(
          atom.image!,
          Rect.fromLTWH(
            0,
            0,
            atom.image!.width.toDouble(),
            atom.image!.height.toDouble(),
          ),
          rect,
          paint,
        );
        traceSink?.call(
          KumihanRenderCommand(
            kind: 'image',
            translateX: rect.left,
            translateY: rect.top,
            width: atom.image!.width.toDouble(),
            height: atom.image!.height.toDouble(),
            scaleX: rect.width / atom.image!.width,
            scaleY: rect.height / atom.image!.height,
            data: <String, Object?>{
              'atomIndex': index,
              'backPage': backPage,
              'writingMode': 'horizontal',
            },
          ),
        );
      } else {
        final text = block.getAtomText(index);
        if (text != '￼') {
          final fontSize = atom.getFontSize();
          final textColor = atom.color ?? color ?? environment.fontColor;
          final measured = environment.layoutText(atom, text, textColor);
          final painter = measured.painter;

          canvas.save();
          if (text == '゛' || text == '゜') {
            x -= 0.26 * fontSize;
          }
          painter.paint(canvas, Offset(x, baseline - painter.height / 2));
          traceSink?.call(
            KumihanRenderCommand(
              kind: 'glyph',
              text: text,
              localX: x,
              localY: baseline - painter.height / 2,
              width: painter.width,
              height: painter.height,
              data: <String, Object?>{
                'atomIndex': index,
                'backPage': backPage,
                'fontSize': fontSize,
                'writingMode': 'horizontal',
              },
            ),
          );
          canvas.restore();
        }
      }

      baseX += atomHeight + atom.tracking;
    }
  }
}

class LayoutTextBlock {
  LayoutTextBlock(this.environment);

  final LayoutEnvironment environment;
  String rawtext = '';
  List<LayoutAtom> atom = <LayoutAtom>[];
  LayoutTextLine? textLine;
  LayoutBlockUserData userData = LayoutBlockUserData();

  void setText(
    String text,
    double fontSize,
    int fontType,
    bool bold,
    bool italic,
    String rotation,
  ) {
    rawtext = text;
    atom = <LayoutAtom>[];

    final breaker = LineBreaker(text);
    var segmentStart = 0;
    var previousAllowed = true;
    var previousJoin = false;
    LineBreak? breakpoint;

    while ((breakpoint = breaker.nextBreak()) != null) {
      final atomCount = atom.length;

      for (var index = segmentStart; index < breakpoint!.position; index += 1) {
        final codePoint = codePointAt(text, index);
        final character = charAt(text, index);
        final characterType = getUtr50Type(codePoint);
        final isOpening = openingBrackets.contains(character);
        final isRotated = _rotatedAtomTypes.contains(character);
        final allowsBreak =
            characterType != 'R' ||
            isOpening ||
            isRotated ||
            _sidewaysCloseGlyphs.contains(character);

        if (previousAllowed || allowsBreak) {
          atom.add(
            LayoutAtom(
              index,
              characterType,
              fontSize,
              fontType,
              bold: bold,
              italic: italic,
              kinsoku:
                  previousJoin ||
                  (index != segmentStart && !isOpening && !isRotated),
            ),
          );
        }

        previousAllowed = allowsBreak;
        previousJoin = character.endsWith('⁠');

        if ((codePoint ?? 0) > 0xffff) {
          index += 1;
        }
      }

      if (atom.length == atomCount) {
        atom.add(
          LayoutAtom(
            segmentStart,
            'R',
            fontSize,
            fontType,
            bold: bold,
            italic: italic,
          ),
        );
      }

      segmentStart = breakpoint.position;
    }

    if (rotation == 'h') {
      for (final item in atom) {
        item.setRotated();
      }
    }
  }

  int getAtomIndexAt(int offset) {
    if (offset >= rawtext.length) {
      return atom.length;
    }
    for (var index = atom.length - 1; index > 0; index -= 1) {
      if (atom[index].index <= offset) {
        return index;
      }
    }
    return 0;
  }

  int splitAtom(int offset, {bool inheritTracking = true}) {
    if (offset == 0) {
      return 0;
    }
    if (offset >= rawtext.length) {
      return atom.length;
    }

    var atomIndex = getAtomIndexAt(offset);
    if (atom[atomIndex].index != offset) {
      final newAtom = atom[atomIndex].clone(
        offset,
        includeKinsoku: inheritTracking,
      );
      atomIndex += 1;
      atom.insert(atomIndex, newAtom);
    }

    return atomIndex;
  }

  int? setTCY(int startOffset, int endOffset) {
    final start = splitAtom(startOffset);
    if (atom[start].isRotated()) {
      return null;
    }

    final end = splitAtom(endOffset);
    if (end - start > 1) {
      atom.removeRange(start + 1, end);
    }

    final item = atom[start];
    item
      ..setR(false)
      ..setT(false)
      ..setFontFixed();
    item.offsetY = 0.05 * item.getFontSize();
    return start;
  }

  String getAtomText(int atomIndex) {
    final item = atom[atomIndex];
    return atomIndex < atom.length - 1
        ? rawtext.substring(item.index, atom[atomIndex + 1].index)
        : rawtext.substring(item.index);
  }

  double getAtomHeight(int atomIndex, {bool includeTracking = false}) {
    final item = atom[atomIndex];
    final fontSize = item.getFontSize();
    final atomText = getAtomText(atomIndex);
    final tracking = includeTracking ? item.tracking : 0.0;

    if (item.height != null) {
      return item.height!;
    }

    if (atomIndex < atom.length - 1) {
      final nextText = getAtomText(atomIndex + 1);
      if (closingBrackets.contains(atomText) &&
          '$punctuationMarks$openingBrackets$closingBrackets・'.contains(
            nextText,
          )) {
        return fontSize / 2 + tracking;
      }

      if ('$openingBrackets・'.contains(atomText) &&
          openingBrackets.contains(nextText)) {
        return fontSize / 2 + tracking;
      }

      if (punctuationMarks.contains(atomText) &&
          '$openingBrackets$closingBrackets'.contains(nextText)) {
        return fontSize / 2 + tracking;
      }
    }

    if (atomText == '⁠' ||
        atomText == '￼' ||
        atomText == '゛' ||
        atomText == '゜') {
      return tracking;
    }

    if (item.getR()) {
      return environment
              .layoutText(item, atomText, environment.fontColor)
              .width +
          tracking;
    }

    return fontSize + tracking;
  }

  LayoutTextLine? createTextLine([
    LayoutTextLine? previous,
    double limit = 0,
    bool justify = false,
  ]) {
    final start = previous?.end ?? 0;
    if (start >= atom.length) {
      return null;
    }

    var maxWidth = 0.0;
    var trackedWidth = 0.0;
    var chunkWidth = 0.0;
    var lastBreakWidth = 0.0;
    var breakIndex = start;
    var lastAtomWidth = 0.0;

    for (var index = start; index < atom.length; index += 1) {
      final item = atom[index];
      final text = charAt(rawtext, item.index);

      if (item.isKinsoku()) {
      } else {
        lastBreakWidth = trackedWidth;
        breakIndex = index;
        if (maxWidth < chunkWidth) {
          maxWidth = chunkWidth;
        }
        chunkWidth = 0;
      }

      final atomWidth = item.getWidth();
      lastAtomWidth = atomWidth;
      if (chunkWidth < atomWidth) {
        chunkWidth = atomWidth;
      }

      if (previous != null &&
          index == start &&
          openingBrackets.contains(text)) {
        item.tracking = -atomWidth / 2;
      }

      trackedWidth += getAtomHeight(index, includeTracking: true);

      if (limit > 0 && trackedWidth > limit && breakIndex != start) {
        if (!'$closingBrackets$punctuationMarks'.contains(text)) {
          break;
        }
        if (trackedWidth - atomWidth / 2 > limit) {
          break;
        }
      }

      if (limit <= 0 || index >= atom.length - 1) {
        lastBreakWidth = trackedWidth;
        breakIndex = index + 1;
        if (maxWidth < chunkWidth) {
          maxWidth = chunkWidth;
        }
      }
    }

    if (breakIndex != start) {
      final lastText = getAtomText(breakIndex - 1);
      final lastChar = charAt(lastText, lastText.length - 1);
      if ('$closingBrackets$punctuationMarks'.contains(lastChar)) {
        lastBreakWidth -= lastAtomWidth / 2;
      }
    }

    if (justify && breakIndex < atom.length) {
      var adjustableCount = 0;
      for (var index = start + 1; index < breakIndex; index += 1) {
        if (!atom[index].isKinsoku()) {
          adjustableCount += 1;
        }
      }

      if (lastBreakWidth < limit && adjustableCount > 0) {
        final addition = (limit - lastBreakWidth) / adjustableCount;
        for (var index = start + 1; index < breakIndex; index += 1) {
          final item = atom[index];
          if (!item.isKinsoku()) {
            item.tracking += addition;
            lastBreakWidth += addition;
          }
        }
      }
    }

    final line = LayoutTextLine(
      this,
      start,
      breakIndex,
      maxWidth,
      lastBreakWidth,
    );
    if (previous != null) {
      previous.nextLine = line;
    } else {
      textLine = line;
    }

    return line;
  }

  LayoutTextLine? getTextLineAtCharIndex(int offset) {
    LayoutTextLine? match;
    if (offset < rawtext.length) {
      var line = textLine;
      while (line != null && atom[line.start].index <= offset) {
        match = line;
        line = line.nextLine;
      }
    }
    return match;
  }
}
