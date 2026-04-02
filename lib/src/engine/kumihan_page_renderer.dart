part of 'kumihan_engine.dart';

extension on KumihanEngine {
  void _showOnePage(
    ui.Canvas canvas,
    int pageNo,
    bool leftSide, {
    bool backPage = false,
    KumihanRenderCommandSink? traceSink,
  }) {
    final vertical = _currentState.startsWith('v');
    final pageStartLine = pageNo < _pages.length ? _pages[pageNo].line : 0;
    var cursor = vertical ? _pageWidth : 0.0;
    final endLine = pageNo + 1 < _pages.length
        ? _pages[pageNo + 1].line
        : _lines.length;

    canvas.save();

    if (_pages[pageNo].centering) {
      var used = -_lineSpace;
      for (var lineIndex = pageStartLine; lineIndex < endLine; lineIndex += 1) {
        used += _lines[lineIndex].width + _lineSpace;
      }
      cursor = vertical
          ? _pageWidth - (_pageWidth - used) / 2
          : (_pageHeight - used) / 2;
    }

    for (var lineIndex = pageStartLine; lineIndex < endLine; lineIndex += 1) {
      final group = _lines[lineIndex];

      for (final line in group.lines) {
        double x;
        double y;

        if (vertical) {
          x = leftSide
              ? cursor - line.width + _pageMarginSide
              : _width - _pageMarginSide - _pageWidth + cursor - line.width;
          y = _pageMarginTop;
          line.draw(canvas, x, y, backPage: backPage, traceSink: traceSink);
        } else {
          x = cursor + _pageMarginTop;
          y = leftSide
              ? _pageMarginSide
              : _width - _pageMarginSide - _pageWidth;
          line.drawYoko(
            canvas,
            y,
            x + line.width / 2,
            backPage: backPage,
            traceSink: traceSink,
          );
        }

        line.x = x;

        for (final attachment in line.attachments) {
          _drawLineAttachment(
            canvas,
            attachment,
            line,
            lineIndex,
            pageStartLine,
            x,
            y,
            vertical,
            backPage: backPage,
            traceSink: traceSink,
          );
        }
      }

      cursor = vertical
          ? cursor - group.width - _lineSpace
          : cursor + group.width + _lineSpace;
    }

    canvas.restore();
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
    KumihanRenderCommandSink? traceSink,
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
          traceSink: traceSink,
        );
      case WarichuMarker():
        if (vertical) {
          attachment.upperLine?.draw(
            canvas,
            x + line.width / 2,
            y,
            traceSink: traceSink,
          );
          attachment.lowerLine?.draw(
            canvas,
            x + line.width / 2 - (attachment.lowerLine?.width ?? 0),
            y,
            traceSink: traceSink,
          );
        } else {
          final upperCenter = x + (attachment.upperLine?.width ?? 0) / 2;
          final lowerCenter =
              x + line.width - (attachment.lowerLine?.width ?? 0) / 2;
          attachment.upperLine?.drawYoko(
            canvas,
            y,
            upperCenter,
            traceSink: traceSink,
          );
          attachment.lowerLine?.drawYoko(
            canvas,
            y,
            lowerCenter,
            traceSink: traceSink,
          );
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
          traceSink?.call(
            KumihanRenderCommand(
              kind: 'region',
              role: 'link',
              localX: vertical ? x : y + top + line.y,
              localY: vertical ? y + top + line.y : x,
              width: vertical ? line.width : bottom - top,
              height: vertical ? bottom - top : line.width,
              data: <String, Object?>{'target': attachment.linkTarget},
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
          traceSink: traceSink,
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
          traceSink: traceSink,
        );
    }
  }

  void _drawInlineDecorationAttachment(
    ui.Canvas canvas,
    InlineDecorationAttachment attachment,
    LayoutTextLine line,
    double x,
    double y,
    bool vertical, {
    KumihanRenderCommandSink? traceSink,
  }) {
    final item = attachment.line;
    final pointOffset = item.width == _fontSize ? _fontSize / 4 : 0;

    switch (attachment.kind) {
      case LayoutInlineDecorationKind.rightEmphasis:
        vertical
            ? item.draw(
                canvas,
                x + line.width - pointOffset,
                y,
                traceSink: traceSink,
              )
            : item.drawYoko(
                canvas,
                y,
                x - item.width / 2 + pointOffset,
                traceSink: traceSink,
              );
      case LayoutInlineDecorationKind.leftEmphasis:
        vertical
            ? item.draw(
                canvas,
                x - item.width + pointOffset,
                y,
                traceSink: traceSink,
              )
            : item.drawYoko(
                canvas,
                y,
                x + line.width + item.width / 2 - pointOffset,
                traceSink: traceSink,
              );
      case LayoutInlineDecorationKind.referenceNote:
      case LayoutInlineDecorationKind.annotationNote:
        vertical
            ? item.draw(canvas, x - 0.45 * line.width, y, traceSink: traceSink)
            : item.drawYoko(
                canvas,
                y,
                x + 0.95 * line.width + item.width / 2,
                traceSink: traceSink,
              );
      case LayoutInlineDecorationKind.leftRuby:
        item.color = fontColor;
        vertical
            ? item.draw(canvas, x - item.width, y, traceSink: traceSink)
            : item.drawYoko(
                canvas,
                y,
                x + line.width + item.width / 2,
                traceSink: traceSink,
              );
      case LayoutInlineDecorationKind.rightRuby:
        item.color = fontColor;
        vertical
            ? item.draw(canvas, x + line.width, y, traceSink: traceSink)
            : item.drawYoko(
                canvas,
                y,
                x - item.width / 2,
                traceSink: traceSink,
              );
      case LayoutInlineDecorationKind.kaeri:
        final size = item.block.atom.first.getFontSize();
        vertical
            ? item.draw(canvas, x - 0.2 * size, y, traceSink: traceSink)
            : item.drawYoko(
                canvas,
                y,
                x + line.width - 0.3 * size,
                traceSink: traceSink,
              );
      case LayoutInlineDecorationKind.naka:
        final size = item.block.atom.first.getFontSize();
        vertical
            ? item.draw(
                canvas,
                x + line.width / 2 - size / 2,
                y,
                traceSink: traceSink,
              )
            : item.drawYoko(
                canvas,
                y,
                x + line.width / 2,
                traceSink: traceSink,
              );
      case LayoutInlineDecorationKind.okuri:
        final size = item.block.atom.first.getFontSize();
        vertical
            ? item.draw(
                canvas,
                x + line.width - 0.8 * size,
                y,
                traceSink: traceSink,
              )
            : item.drawYoko(canvas, y, x + 0.3 * size, traceSink: traceSink);
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
    bool vertical, {
    KumihanRenderCommandSink? traceSink,
  }) {
    final markerTop = item is SpanMarker ? item.top + y : y;
    final markerBottom = item is SpanMarker ? item.bottom + y : y;
    final markerRole = switch (item) {
      SpanMarker(kind: final kind?) => kind.name,
      SpanMarker() => item.markType,
      NoteMarker(kind: final kind?) => kind.name,
      NoteMarker() => item.markType,
      _ => '',
    };

    traceSink?.call(
      KumihanRenderCommand(
        kind: 'marker',
        role: markerRole,
        localX: vertical ? x : markerTop,
        localY: vertical ? markerTop : x,
        width: vertical ? line.width : markerBottom - markerTop,
        height: vertical ? markerBottom - markerTop : line.width,
        data: <String, Object?>{'vertical': vertical, 'lineIndex': lineIndex},
      ),
    );

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
