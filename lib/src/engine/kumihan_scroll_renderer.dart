part of 'kumihan_scroll_engine.dart';

extension on KumihanScrollEngine {
  void _paintVisibleRange(ui.Canvas canvas) {
    final vertical = _currentState.startsWith('v');
    final visibleLeft = _scrollOffset;
    final visibleRight = _scrollOffset + _width;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(visibleLeft, 0, _width, _height));

    for (var lineIndex = 0; lineIndex < _lines.length; lineIndex += 1) {
      final group = _lines[lineIndex];
      if (group.xEnd < visibleLeft || group.xStart > visibleRight) {
        continue;
      }

      for (final line in group.lines) {
        double x;
        double y;

        if (vertical) {
          x = group.xStart + _pageMarginSide;
          y = _pageMarginTop;
          line.draw(canvas, x, y);
        } else {
          x = group.xStart + _pageMarginTop;
          y = _pageMarginSide;
          line.drawYoko(canvas, y, x + line.width / 2);
        }

        line.x = x;
        _recordSelectableGlyphs(line, x, y, vertical);

        for (final attachment in line.attachments) {
          _drawLineAttachment(
            canvas,
            attachment,
            line,
            lineIndex,
            0,
            x,
            y,
            vertical,
            backPage: false,
          );
        }
      }
    }

    canvas.restore();
  }

  void _recordSelectableGlyphs(
    LayoutTextLine line,
    double x,
    double y,
    bool vertical,
  ) {
    if (line.start >= line.end || line.start >= line.block.atom.length) {
      return;
    }

    for (var atomIndex = line.start; atomIndex < line.end; atomIndex += 1) {
      final atomText = line.block.getAtomText(atomIndex);
      final glyphs = _visibleGlyphs(atomText);
      if (glyphs.isEmpty) {
        continue;
      }

      final atomExtent = line.block.getAtomHeight(atomIndex);
      if (atomExtent <= 0) {
        continue;
      }

      final glyphExtent = atomExtent / glyphs.length;
      final atomOffset = line.getAtomY(atomIndex);

      for (var index = 0; index < glyphs.length; index += 1) {
        final rect = vertical
            ? Rect.fromLTWH(
                x,
                y + line.y + atomOffset + glyphExtent * index,
                line.width,
                glyphExtent,
              )
            : Rect.fromLTWH(
                y + line.y + atomOffset + glyphExtent * index,
                x,
                glyphExtent,
                line.width,
              );
        _selectableGlyphs.add(
          KumihanSelectableGlyph(
            order: _selectableGlyphOrder++,
            rect: rect,
            text: glyphs[index],
          ),
        );
      }
    }
  }

  List<String> _visibleGlyphs(String text) {
    if (text.trim().isEmpty) {
      return const <String>[];
    }

    final glyphs = <String>[];
    for (final rune in text.runes) {
      switch (rune) {
        case 0x2060:
        case 0xfffc:
        case 0x200b:
        case 0x200c:
        case 0x200d:
        case 0xfeff:
          continue;
      }
      glyphs.add(String.fromCharCode(rune));
    }
    return glyphs;
  }

  void _drawLineAttachment(
    ui.Canvas canvas,
    LayoutTextLineAttachment attachment,
    LayoutTextLine line,
    int lineIndex,
    int pageStartLine,
    double x,
    double y,
    bool vertical, {
    required bool backPage,
  }) {
    switch (attachment) {
      case InlineDecorationAttachment():
        _drawInlineDecorationAttachment(
          canvas,
          attachment,
          line,
          x,
          y,
          vertical,
        );
      case WarichuMarker():
        if (vertical) {
          attachment.upperLine?.draw(canvas, x + line.width / 2, y);
          attachment.lowerLine?.draw(
            canvas,
            x + line.width / 2 - (attachment.lowerLine?.width ?? 0),
            y,
          );
        } else {
          final upperCenter = x + (attachment.upperLine?.width ?? 0) / 2;
          final lowerCenter =
              x + line.width - (attachment.lowerLine?.width ?? 0) / 2;
          attachment.upperLine?.drawYoko(canvas, y, upperCenter);
          attachment.lowerLine?.drawYoko(canvas, y, lowerCenter);
        }
      case LinkMarker():
        if (!backPage) {
          final top = line.getAtomY(attachment.startAtom);
          final bottom = line.getAtomY(attachment.endAtom);
          _clickable.add(
            vertical
                ? ClickableArea(
                    type: 'リンク',
                    x: x,
                    y: y + top + line.y,
                    width: line.width,
                    height: bottom - top,
                    data: attachment.linkTarget,
                  )
                : ClickableArea(
                    type: 'リンク',
                    x: y + top + line.y,
                    y: x,
                    width: bottom - top,
                    height: line.width,
                    data: attachment.linkTarget,
                  ),
          );
        }
      case SpanMarker():
        _drawSpanOrNoteMarker(
          canvas,
          attachment,
          line,
          lineIndex,
          pageStartLine,
          x,
          y,
          vertical,
        );
      case NoteMarker():
        _drawSpanOrNoteMarker(
          canvas,
          attachment,
          line,
          lineIndex,
          pageStartLine,
          x,
          y,
          vertical,
        );
      case QuoteMarker():
        _drawQuoteMarker(canvas, line, lineIndex, x, y, vertical);
    }
  }

  bool _lineGroupHasQuote(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= _lines.length) {
      return false;
    }
    return _lines[lineIndex].lines.any(
      (line) => line.attachments.any((attachment) => attachment is QuoteMarker),
    );
  }

  void _drawQuoteMarker(
    ui.Canvas canvas,
    LayoutTextLine line,
    int lineIndex,
    double x,
    double y,
    bool vertical,
  ) {
    final thickness = (_fontSize * 0.18).clamp(3.0, 6.0);
    final paint = Paint()
      ..color = fontColor.withAlpha(112)
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;
    final hasPrevious = _lineGroupHasQuote(lineIndex - 1);
    final hasNext = _lineGroupHasQuote(lineIndex + 1);
    final halfGap = _lineSpace / 2;
    final center = _fontSize / 2;

    if (vertical) {
      final top = y + line.y - center;
      final left = x - (hasNext ? halfGap : 0);
      final right = x + line.width + (hasPrevious ? halfGap : 0);
      canvas.drawLine(Offset(left, top), Offset(right, top), paint);
      return;
    }

    final left = y + line.y - center;
    final top = x - (hasPrevious ? halfGap : 0);
    final bottom = x + line.width + (hasNext ? halfGap : 0);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
  }

  void _drawInlineDecorationAttachment(
    ui.Canvas canvas,
    InlineDecorationAttachment attachment,
    LayoutTextLine line,
    double x,
    double y,
    bool vertical,
  ) {
    final item = attachment.line;
    final pointOffset = item.width == _fontSize ? _fontSize / 4 : 0;

    switch (attachment.kind) {
      case LayoutInlineDecorationKind.rightEmphasis:
        vertical
            ? item.draw(canvas, x + line.width - pointOffset, y)
            : item.drawYoko(canvas, y, x - item.width / 2 + pointOffset);
      case LayoutInlineDecorationKind.leftEmphasis:
        vertical
            ? item.draw(canvas, x - item.width + pointOffset, y)
            : item.drawYoko(
                canvas,
                y,
                x + line.width + item.width / 2 - pointOffset,
              );
      case LayoutInlineDecorationKind.referenceNote:
      case LayoutInlineDecorationKind.annotationNote:
        vertical
            ? item.draw(canvas, x - 0.45 * line.width, y)
            : item.drawYoko(canvas, y, x + 0.95 * line.width + item.width / 2);
      case LayoutInlineDecorationKind.leftRuby:
        item.color = fontColor;
        vertical
            ? item.draw(canvas, x - item.width, y)
            : item.drawYoko(canvas, y, x + line.width + item.width / 2);
      case LayoutInlineDecorationKind.rightRuby:
        item.color = fontColor;
        vertical
            ? item.draw(canvas, x + line.width, y)
            : item.drawYoko(canvas, y, x - item.width / 2);
      case LayoutInlineDecorationKind.kaeri:
        final size = item.block.atom.first.getFontSize();
        vertical
            ? item.draw(canvas, x - 0.2 * size, y)
            : item.drawYoko(canvas, y, x + line.width - 0.3 * size);
      case LayoutInlineDecorationKind.naka:
        final size = item.block.atom.first.getFontSize();
        vertical
            ? item.draw(canvas, x + line.width / 2 - size / 2, y)
            : item.drawYoko(canvas, y, x + line.width / 2);
      case LayoutInlineDecorationKind.okuri:
        final size = item.block.atom.first.getFontSize();
        vertical
            ? item.draw(canvas, x + line.width - 0.8 * size, y)
            : item.drawYoko(canvas, y, x + 0.3 * size);
    }
  }

  void _drawSpanOrNoteMarker(
    ui.Canvas canvas,
    LayoutLineMark item,
    LayoutTextLine line,
    int lineIndex,
    int pageStartLine,
    double x,
    double y,
    bool vertical,
  ) {
    canvas.save();
    final paint = Paint()
      ..color = fontColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    if (item is SpanMarker) {
      switch (item.kind) {
        case LayoutSpanMarkerKind.frameStart:
          if (vertical) {
            final left = x;
            final right = x + line.width / 2;
            final top = item.top + y;
            final bottom = item.bottom + y;
            canvas.drawPath(
              Path()
                ..moveTo(left, top)
                ..lineTo(right, top)
                ..lineTo(right, bottom)
                ..lineTo(left, bottom),
              paint,
            );
          } else {
            final top = x + line.width;
            final bottom = x + line.width / 2;
            final left = item.top + y;
            final right = item.bottom + y;
            canvas.drawPath(
              Path()
                ..moveTo(left, top)
                ..lineTo(left, bottom)
                ..lineTo(right, bottom)
                ..lineTo(right, top),
              paint,
            );
          }
        case LayoutSpanMarkerKind.frameEnd:
          if (vertical) {
            var left = x + line.width;
            if (lineIndex != pageStartLine) {
              left += _lineSpace + 1;
            }
            final right = x + line.width / 2;
            final top = item.top + y;
            final bottom = item.bottom + y;
            canvas.drawPath(
              Path()
                ..moveTo(left, top)
                ..lineTo(right, top)
                ..lineTo(right, bottom)
                ..lineTo(left, bottom),
              paint,
            );
          } else {
            var top = x;
            if (lineIndex != pageStartLine) {
              top -= _lineSpace + 1;
            }
            final bottom = x + line.width / 2;
            final left = item.top + y;
            final right = item.bottom + y;
            canvas.drawPath(
              Path()
                ..moveTo(left, top)
                ..lineTo(left, bottom)
                ..lineTo(right, bottom)
                ..lineTo(right, top),
              paint,
            );
          }
        case LayoutSpanMarkerKind.frameMiddle:
          if (vertical) {
            final left = x;
            var right = x + line.width;
            if (lineIndex != pageStartLine) {
              right += _lineSpace + 1;
            }
            final top = item.top + y;
            final bottom = item.bottom + y;
            canvas.drawLine(Offset(left, top), Offset(right, top), paint);
            canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
          } else {
            var top = x;
            if (lineIndex != pageStartLine) {
              top -= _lineSpace + 1;
            }
            final bottom = x + line.width;
            final left = item.top + y;
            final right = item.bottom + y;
            canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
            canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
          }
        case LayoutSpanMarkerKind.frameBox:
          if (vertical) {
            final left = x - 1;
            final right = x + line.width;
            final top = item.top + y;
            final bottom = item.bottom + y;
            if (item.isStart ?? false) {
              canvas.drawLine(Offset(left, top), Offset(right + 1, top), paint);
            }
            if (item.isEnd ?? false) {
              canvas.drawLine(
                Offset(left, bottom),
                Offset(right + 1, bottom),
                paint,
              );
            }
            canvas.drawLine(Offset(left, top), Offset(left, bottom + 1), paint);
            canvas.drawLine(
              Offset(right, top),
              Offset(right, bottom + 1),
              paint,
            );
          } else {
            final top = x - 1;
            final bottom = x + line.width;
            final left = item.top + y;
            final right = item.bottom + y;
            if (item.isStart ?? false) {
              canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
            }
            if (item.isEnd ?? false) {
              canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
            }
            canvas.drawLine(Offset(left, top), Offset(right, top), paint);
            canvas.drawLine(
              Offset(left, bottom + 1),
              Offset(right, bottom + 1),
              paint,
            );
          }
        case LayoutSpanMarkerKind.rightSolid:
        case LayoutSpanMarkerKind.rightDouble:
        case LayoutSpanMarkerKind.rightChain:
        case LayoutSpanMarkerKind.rightDashed:
        case LayoutSpanMarkerKind.rightWave:
          final position = item.kind == LayoutSpanMarkerKind.rightWave
              ? x + line.width + 3
              : x + line.width + 2;
          if (item.kind == LayoutSpanMarkerKind.rightChain) {
            paint.strokeCap = StrokeCap.square;
          }
          if (vertical) {
            if (item.kind == LayoutSpanMarkerKind.rightWave) {
              _drawWavyLine(
                canvas,
                paint,
                position,
                item.top + y,
                item.bottom + y,
              );
            } else {
              canvas.drawLine(
                Offset(position, item.top + y),
                Offset(position, item.bottom + y),
                paint,
              );
              if (item.kind == LayoutSpanMarkerKind.rightDouble) {
                canvas.drawLine(
                  Offset(position + 3, item.top + y),
                  Offset(position + 3, item.bottom + y),
                  paint,
                );
              }
            }
          } else if (item.kind == LayoutSpanMarkerKind.rightWave) {
            _drawWavyLineYoko(
              canvas,
              paint,
              position,
              item.top + y,
              item.bottom + y,
            );
          } else {
            canvas.drawLine(
              Offset(item.top + y, position),
              Offset(item.bottom + y, position),
              paint,
            );
            if (item.kind == LayoutSpanMarkerKind.rightDouble) {
              canvas.drawLine(
                Offset(item.top + y, position + 3),
                Offset(item.bottom + y, position + 3),
                paint,
              );
            }
          }
        case LayoutSpanMarkerKind.leftSolid:
        case LayoutSpanMarkerKind.leftDouble:
        case LayoutSpanMarkerKind.leftChain:
        case LayoutSpanMarkerKind.leftDashed:
        case LayoutSpanMarkerKind.leftWave:
          final position = item.kind == LayoutSpanMarkerKind.leftWave
              ? x - 3
              : x - 2;
          if (vertical) {
            if (item.kind == LayoutSpanMarkerKind.leftWave) {
              _drawWavyLine(
                canvas,
                paint,
                position,
                item.top + y,
                item.bottom + y,
              );
            } else {
              canvas.drawLine(
                Offset(position, item.top + y),
                Offset(position, item.bottom + y),
                paint,
              );
              if (item.kind == LayoutSpanMarkerKind.leftDouble) {
                canvas.drawLine(
                  Offset(position - 3, item.top + y),
                  Offset(position - 3, item.bottom + y),
                  paint,
                );
              }
            }
          } else if (item.kind == LayoutSpanMarkerKind.leftWave) {
            _drawWavyLineYoko(
              canvas,
              paint,
              position,
              item.top + y,
              item.bottom + y,
            );
          } else {
            canvas.drawLine(
              Offset(item.top + y, position),
              Offset(item.bottom + y, position),
              paint,
            );
            if (item.kind == LayoutSpanMarkerKind.leftDouble) {
              canvas.drawLine(
                Offset(item.top + y, position - 3),
                Offset(item.bottom + y, position - 3),
                paint,
              );
            }
          }
        case LayoutSpanMarkerKind.cancel:
          final position = x + line.width / 2;
          if (vertical) {
            canvas.drawLine(
              Offset(position, item.top + y),
              Offset(position, item.bottom + y),
              paint,
            );
          } else {
            canvas.drawLine(
              Offset(item.top + y, position),
              Offset(item.bottom + y, position),
              paint,
            );
          }
        case null:
          break;
      }
    }

    canvas.restore();
  }
}
