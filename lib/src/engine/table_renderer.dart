import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../ast.dart';
import 'constants.dart';
import 'document_compiler.dart';

class RenderedTableBlock {
  const RenderedTableBlock({
    required this.height,
    required this.picture,
    required this.width,
  });

  final double height;
  final ui.Picture picture;
  final double width;
}

Future<RenderedTableBlock> renderTableBlock({
  required AstCompiledTableEntry table,
  required Color fontColor,
  required double fontSize,
  required List<String> gothicFontFamilies,
  required double maxHeight,
  required List<String> minchoFontFamilies,
  required double maxWidth,
}) async {
  final normalizedRows = _normalizeRows(table.rows);
  final columnCount = normalizedRows.isEmpty ? 0 : normalizedRows.first.length;
  if (columnCount == 0) {
    return _renderFallbackBlock(
      fontColor: fontColor,
      fontSize: fontSize,
      minchoFontFamilies: minchoFontFamilies,
    );
  }

  final bodyRows = table.headerRowCount < normalizedRows.length
      ? normalizedRows.length - table.headerRowCount
      : normalizedRows.length;
  final maxTextLength = _maxTextLength(normalizedRows);
  final minimumColumnWidth = math.max(
    columnCount >= 4 ? fontSize * 3.2 : fontSize * 4.4,
    56.0,
  );
  final minimumGridWidth = columnCount * minimumColumnWidth + columnCount + 1;
  final preferStacked =
      columnCount >= 5 ||
      (columnCount >= 4 && minimumGridWidth > maxWidth * 0.88) ||
      (columnCount >= 3 && maxTextLength > 32 && minimumGridWidth > maxWidth) ||
      (bodyRows <= 2 && columnCount >= 3 && minimumGridWidth > maxWidth * 0.94);

  final plan = preferStacked
      ? _buildStackedPlan(
          rows: normalizedRows,
          headerRowCount: table.headerRowCount,
          fontColor: fontColor,
          fontSize: fontSize,
          gothicFontFamilies: gothicFontFamilies,
          minchoFontFamilies: minchoFontFamilies,
          width: maxWidth,
        )
      : _buildGridPlan(
          rows: normalizedRows,
          headerRowCount: table.headerRowCount,
          fontColor: fontColor,
          fontSize: fontSize,
          gothicFontFamilies: gothicFontFamilies,
          minchoFontFamilies: minchoFontFamilies,
          minimumColumnWidth: minimumColumnWidth,
          width: maxWidth,
        );

  final width = math.max(plan.width, 1.0);
  final height = math.max(plan.height, 1.0);
  final scale = math.min(1, math.min(maxWidth / width, maxHeight / height));
  final outputWidth = width * scale;
  final outputHeight = height * scale;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale.toDouble());
  plan.paint(canvas);
  final picture = recorder.endRecording();
  return RenderedTableBlock(
    height: outputHeight,
    picture: picture,
    width: outputWidth,
  );
}

Future<RenderedTableBlock> _renderFallbackBlock({
  required Color fontColor,
  required double fontSize,
  required List<String> minchoFontFamilies,
}) async {
  final painter = _createPainter(
    '（空の表）',
    _bodyStyle(
      color: fontColor,
      fontFamilies: minchoFontFamilies,
      fontSize: fontSize,
    ),
    maxWidth: math.max(fontSize * 6, 96),
  );
  final width = painter.width + fontSize * 1.2;
  final height = painter.height + fontSize;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final borderPaint = Paint()
    ..color = fontColor
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height), borderPaint);
  painter.paint(canvas, Offset(fontSize * 0.6, fontSize / 2));
  final picture = recorder.endRecording();
  return RenderedTableBlock(height: height, picture: picture, width: width);
}

List<List<AstCompiledTableCell>> _normalizeRows(List<List<AstCompiledTableCell>> rows) {
  if (rows.isEmpty) {
    return const <List<AstCompiledTableCell>>[];
  }

  var columnCount = 0;
  for (final row in rows) {
    if (row.length > columnCount) {
      columnCount = row.length;
    }
  }
  if (columnCount <= 0) {
    return const <List<AstCompiledTableCell>>[];
  }

  return rows
      .map(
        (row) => <AstCompiledTableCell>[
          ...row,
          for (var index = row.length; index < columnCount; index += 1)
            const AstCompiledTableCell(text: '', alignment: AstTableAlignment.start),
        ],
      )
      .toList(growable: false);
}

int _maxTextLength(List<List<AstCompiledTableCell>> rows) {
  var maxLength = 0;
  for (final row in rows) {
    for (final cell in row) {
      if (cell.text.length > maxLength) {
        maxLength = cell.text.length;
      }
    }
  }
  return maxLength;
}

TextStyle _bodyStyle({
  required Color color,
  required List<String> fontFamilies,
  required double fontSize,
}) {
  return TextStyle(
    color: color,
    fontFamily: fontFamilies.firstOrNull,
    fontFamilyFallback: fontFamilies.length > 1 ? fontFamilies.sublist(1) : null,
    package: bundledFontPackage,
    fontSize: fontSize,
    height: 1.28,
    textBaseline: TextBaseline.ideographic,
  );
}

TextStyle _headerStyle({
  required Color color,
  required List<String> fontFamilies,
  required double fontSize,
}) {
  return _bodyStyle(
    color: color,
    fontFamilies: fontFamilies,
    fontSize: fontSize,
  ).copyWith(fontWeight: FontWeight.w600);
}

TextPainter _createPainter(
  String text,
  TextStyle style, {
  required double maxWidth,
  TextAlign textAlign = TextAlign.left,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: textAlign,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: math.max(maxWidth, 1));
}

TextAlign _textAlignForCell(AstTableAlignment alignment) {
  switch (alignment) {
    case AstTableAlignment.center:
      return TextAlign.center;
    case AstTableAlignment.end:
      return TextAlign.right;
    case AstTableAlignment.start:
      return TextAlign.left;
  }
}

_RenderedTablePlan _buildGridPlan({
  required Color fontColor,
  required double fontSize,
  required List<String> gothicFontFamilies,
  required int headerRowCount,
  required List<String> minchoFontFamilies,
  required double minimumColumnWidth,
  required List<List<AstCompiledTableCell>> rows,
  required double width,
}) {
  final columnCount = rows.first.length;
  const border = 1.0;
  final horizontalPadding = math.max(fontSize * 0.5, 10);
  final verticalPadding = math.max(fontSize * 0.34, 6);
  final maxTableWidth = math.max(width, 1);
  final availableCellWidth = math.max(maxTableWidth - border * (columnCount + 1), 1);
  final naturalWidths = List<double>.filled(columnCount, minimumColumnWidth);
  var naturalWidthSum = 0.0;

  final headerMeasureStyle = _headerStyle(
    color: fontColor,
    fontFamilies: gothicFontFamilies,
    fontSize: fontSize,
  );
  final bodyMeasureStyle = _bodyStyle(
    color: fontColor,
    fontFamilies: minchoFontFamilies,
    fontSize: fontSize,
  );

  for (var column = 0; column < columnCount; column += 1) {
    var columnWidth = minimumColumnWidth;
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      final cell = rows[rowIndex][column];
      final style = rowIndex < headerRowCount ? headerMeasureStyle : bodyMeasureStyle;
      final painter = _createPainter(
        cell.text.isEmpty ? ' ' : cell.text,
        style,
        maxWidth: double.infinity,
      );
      final measured = painter.width + horizontalPadding * 2;
      if (measured > columnWidth) {
        columnWidth = measured;
      }
    }
    naturalWidths[column] = columnWidth;
    naturalWidthSum += columnWidth;
  }

  final widths = naturalWidthSum <= availableCellWidth
      ? List<double>.from(naturalWidths)
      : List<double>.filled(columnCount, minimumColumnWidth);

  if (naturalWidthSum > availableCellWidth) {
    final baseWidth = minimumColumnWidth * columnCount;
    final remaining = math.max(availableCellWidth - baseWidth, 0);
    final flexTotal = naturalWidthSum - baseWidth;

    if (remaining > 0 && flexTotal > 0) {
      for (var column = 0; column < columnCount; column += 1) {
        final flex = math.max(naturalWidths[column] - minimumColumnWidth, 0);
        widths[column] += remaining * flex / flexTotal;
      }
    } else if (remaining > 0) {
      final addition = remaining / columnCount;
      for (var column = 0; column < columnCount; column += 1) {
        widths[column] += addition;
      }
    }

    final currentWidth = widths.fold<double>(0, (sum, item) => sum + item);
    final correction = availableCellWidth - currentWidth;
    if (widths.isNotEmpty) {
      widths[widths.length - 1] += correction;
    }
  }

  final tableWidth = border * (columnCount + 1) + widths.fold<double>(0, (sum, item) => sum + item);

  final rowHeights = <double>[];
  final painters = <List<TextPainter>>[];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
    final rowPainters = <TextPainter>[];
    var rowHeight = 0.0;
    for (var column = 0; column < columnCount; column += 1) {
      final cell = rows[rowIndex][column];
      final style = rowIndex < headerRowCount ? headerMeasureStyle : bodyMeasureStyle;
      final painter = _createPainter(
        cell.text.isEmpty ? ' ' : cell.text,
        style,
        maxWidth: math.max(widths[column] - horizontalPadding * 2, 1),
        textAlign: _textAlignForCell(cell.alignment),
      );
      rowPainters.add(painter);
      final cellHeight = painter.height + verticalPadding * 2;
      if (cellHeight > rowHeight) {
        rowHeight = cellHeight;
      }
    }
    painters.add(rowPainters);
    rowHeights.add(rowHeight);
  }

  final totalHeight = border + rowHeights.fold<double>(0, (sum, item) => sum + item + border);
  return _RenderedTablePlan(
    height: totalHeight,
    paint: (canvas) {
      final borderPaint = Paint()
        ..color = fontColor
        ..strokeWidth = border
        ..style = PaintingStyle.stroke;
      final headerFill = Paint()
        ..color = fontColor.withValues(alpha: 0.05)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, tableWidth, totalHeight), borderPaint);

      var y = border;
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
        final rowHeight = rowHeights[rowIndex];
        if (rowIndex < headerRowCount) {
          canvas.drawRect(
            Rect.fromLTWH(border, y, tableWidth - border * 2, rowHeight),
            headerFill,
          );
        }

        var x = border;
        for (var column = 0; column < columnCount; column += 1) {
          final cellWidth = widths[column];
          final painter = painters[rowIndex][column];
          final innerWidth = math.max(cellWidth - horizontalPadding * 2, 1);
          final cellX = x + horizontalPadding;
          final cellY = y + (rowHeight - painter.height) / 2;
          final alignment = rows[rowIndex][column].alignment;
          final offsetX = switch (alignment) {
            AstTableAlignment.center => cellX + (innerWidth - painter.width) / 2,
            AstTableAlignment.end => cellX + innerWidth - painter.width,
            AstTableAlignment.start => cellX,
          };
          painter.paint(canvas, Offset(offsetX, cellY));

          x += cellWidth;
          if (column < columnCount - 1) {
            canvas.drawLine(Offset(x, y), Offset(x, y + rowHeight), borderPaint);
            x += border;
          }
        }

        y += rowHeight;
        canvas.drawLine(Offset(0, y), Offset(tableWidth, y), borderPaint);
        y += border;
      }
    },
    width: tableWidth,
  );
}

_RenderedTablePlan _buildStackedPlan({
  required Color fontColor,
  required double fontSize,
  required List<String> gothicFontFamilies,
  required int headerRowCount,
  required List<String> minchoFontFamilies,
  required List<List<AstCompiledTableCell>> rows,
  required double width,
}) {
  const border = 1.0;
  final outerPadding = math.max(fontSize * 0.56, 10);
  final innerPadding = math.max(fontSize * 0.34, 6);
  final pairGap = math.max(fontSize * 0.18, 3);
  final cardGap = math.max(fontSize * 0.55, 12);
  final maxCardWidth = math.max(width, 1.0);
  final labelStyle = _headerStyle(
    color: fontColor,
    fontFamilies: gothicFontFamilies,
    fontSize: fontSize * 0.85,
  );
  final valueStyle = _bodyStyle(
    color: fontColor,
    fontFamilies: minchoFontFamilies,
    fontSize: fontSize,
  );

  final columnCount = rows.first.length;
  final headerLabels = headerRowCount > 0
      ? rows.first.map((cell) => cell.text.isEmpty ? '列' : cell.text).toList(growable: false)
      : List<String>.generate(columnCount, (index) => '列${index + 1}');
  final dataRows = headerRowCount < rows.length ? rows.sublist(headerRowCount) : rows;
  final cards = dataRows.isEmpty ? rows : dataRows;
  var naturalContentWidth = 0.0;
  for (final label in headerLabels) {
    final labelPainter = _createPainter(label, labelStyle, maxWidth: double.infinity);
    naturalContentWidth = math.max(naturalContentWidth, labelPainter.width);
  }
  for (final row in cards) {
    for (final cell in row) {
      final valuePainter = _createPainter(
        cell.text.isEmpty ? ' ' : cell.text,
        valueStyle,
        maxWidth: double.infinity,
      );
      naturalContentWidth = math.max(naturalContentWidth, valuePainter.width);
    }
  }
  final cardWidth = math.min(
    maxCardWidth,
    math.max(naturalContentWidth + outerPadding * 2 + border * 2, fontSize * 8),
  ).toDouble();
  final cardLayouts = <_StackedCardLayout>[];
  var totalHeight = 0.0;

  for (final row in cards) {
    final pairLayouts = <_StackedPairLayout>[];
    var cardHeight = border;
    final contentWidth = math.max(cardWidth - outerPadding * 2, 1.0);
    for (var column = 0; column < columnCount; column += 1) {
      final labelPainter = _createPainter(
        headerLabels[column],
        labelStyle,
        maxWidth: contentWidth.toDouble(),
      );
      final valuePainter = _createPainter(
        row[column].text.isEmpty ? ' ' : row[column].text,
        valueStyle,
        maxWidth: contentWidth.toDouble(),
        textAlign: _textAlignForCell(row[column].alignment),
      );
      final pairHeight = innerPadding + labelPainter.height + pairGap + valuePainter.height + innerPadding;
      pairLayouts.add(
        _StackedPairLayout(
          alignment: row[column].alignment,
          height: pairHeight,
          labelPainter: labelPainter,
          valuePainter: valuePainter,
        ),
      );
      cardHeight += pairHeight + border;
    }
    cardLayouts.add(_StackedCardLayout(height: cardHeight, pairs: pairLayouts));
    totalHeight += cardHeight + cardGap;
  }

  if (cardLayouts.isNotEmpty) {
    totalHeight -= cardGap;
  }

  return _RenderedTablePlan(
    height: totalHeight,
    paint: (canvas) {
      final borderPaint = Paint()
        ..color = fontColor
        ..strokeWidth = border
        ..style = PaintingStyle.stroke;
      final labelFill = Paint()
        ..color = fontColor.withValues(alpha: 0.04)
        ..style = PaintingStyle.fill;

      var y = 0.0;
      for (final card in cardLayouts) {
        canvas.drawRect(Rect.fromLTWH(0, y, cardWidth, card.height), borderPaint);
        var pairY = y + border;
        for (var index = 0; index < card.pairs.length; index += 1) {
          final pair = card.pairs[index];
          final sectionTop = pairY;
          canvas.drawRect(
            Rect.fromLTWH(border, sectionTop, cardWidth - border * 2, pair.height),
            labelFill,
          );
          final labelX = outerPadding;
          final labelY = sectionTop + innerPadding;
          pair.labelPainter.paint(canvas, Offset(labelX.toDouble(), labelY.toDouble()));

          final contentWidth = math.max(cardWidth - outerPadding * 2, 1.0);
          final valueX = switch (pair.alignment) {
            AstTableAlignment.center => outerPadding + (contentWidth - pair.valuePainter.width) / 2,
            AstTableAlignment.end => outerPadding + contentWidth - pair.valuePainter.width,
            AstTableAlignment.start => outerPadding,
          };
          pair.valuePainter.paint(
            canvas,
            Offset(valueX.toDouble(), (labelY + pair.labelPainter.height + pairGap).toDouble()),
          );

          pairY += pair.height;
          canvas.drawLine(Offset(0, pairY), Offset(cardWidth, pairY), borderPaint);
          pairY += border;
          if (index == card.pairs.length - 1) {
            pairY -= border;
          }
        }
        y += card.height + cardGap;
      }
    },
    width: cardWidth,
  );
}

class _RenderedTablePlan {
  const _RenderedTablePlan({
    required this.height,
    required this.paint,
    required this.width,
  });

  final double height;
  final void Function(Canvas canvas) paint;
  final double width;
}

class _StackedCardLayout {
  const _StackedCardLayout({required this.height, required this.pairs});

  final double height;
  final List<_StackedPairLayout> pairs;
}

class _StackedPairLayout {
  const _StackedPairLayout({
    required this.alignment,
    required this.height,
    required this.labelPainter,
    required this.valuePainter,
  });

  final AstTableAlignment alignment;
  final double height;
  final TextPainter labelPainter;
  final TextPainter valuePainter;
}
