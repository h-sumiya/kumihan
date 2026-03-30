import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/rendering.dart';

import '../ast/ast.dart';
import '../layout_result/layout_result.dart';
import '../presentation/page_projection.dart';
import 'kumihan_render_theme.dart';
import 'vertical_glyph_layout.dart';

class KumihanLayoutPainter extends CustomPainter {
  const KumihanLayoutPainter({required this.result, required this.theme});

  final LayoutResult result;
  final KumihanRenderThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final pageRect = Offset.zero & size;
    final contentRect = theme.pagePadding.deflateRect(pageRect);
    final projection = KumihanPageProjection.resolve(
      result: result,
      theme: theme,
      size: size,
    );
    canvas.drawRect(pageRect, Paint()..color = theme.paperColor);

    if (theme.showGuides) {
      _paintGuides(canvas, contentRect);
    }

    for (final block in result.blocks) {
      _paintBlock(
        canvas,
        block,
        contentRect,
        projection: projection,
        baseInlineOffset: 0,
        baseBlockOffset: 0,
      );
    }

    if (theme.showDiagnosticsOverlay) {
      _paintDiagnosticsOverlay(canvas, pageRect);
    }

    if (theme.showProvisionalBanner) {
      _paintProvisionalBanner(canvas, pageRect);
    }
  }

  void _paintBlock(
    Canvas canvas,
    LayoutBlockResult block,
    Rect contentRect, {
    required KumihanPageProjection projection,
    required double baseInlineOffset,
    required double baseBlockOffset,
  }) {
    final inlineOffset = baseInlineOffset + block.inlineOffset;
    final blockOffset = baseBlockOffset + block.blockOffset;

    switch (block) {
      case LayoutParagraphResult():
        _paintLineGroup(
          canvas,
          block.lineGroup,
          contentRect,
          projection: projection,
          baseInlineOffset: baseInlineOffset,
          baseBlockOffset: blockOffset,
        );
      case LayoutEmptyLineResult():
        _paintLineGroup(
          canvas,
          block.lineGroup,
          contentRect,
          projection: projection,
          baseInlineOffset: baseInlineOffset,
          baseBlockOffset: blockOffset,
        );
      case LayoutTableResult():
        _paintTable(
          canvas,
          block,
          contentRect,
          projection: projection,
          baseInlineOffset: inlineOffset,
          baseBlockOffset: blockOffset,
        );
      case LayoutUnsupportedBlockResult():
        final rect = projection.projectLogicalRect(
          contentRect,
          inlineOffset: inlineOffset,
          blockOffset: blockOffset,
          inlineExtent: block.inlineExtent,
          blockExtent: math.max(block.blockExtent, 1),
        );
        if (rect == null) {
          return;
        }
        canvas.drawRect(
          rect,
          Paint()..color = theme.markerColor.withValues(alpha: 0.1),
        );
        _paintCenteredText(
          canvas,
          rect,
          '未対応ブロック',
          _textStyle(fontScale: 0.9, color: theme.noteColor),
        );
    }
  }

  void _paintTable(
    Canvas canvas,
    LayoutTableResult table,
    Rect contentRect, {
    required KumihanPageProjection projection,
    required double baseInlineOffset,
    required double baseBlockOffset,
  }) {
    final slotInlineOffset = projection.projectedSlotInlineOffset(table);
    if (slotInlineOffset == null) {
      return;
    }
    final projectedBaseInlineOffset = slotInlineOffset - table.inlineOffset;
    final tableRect = projection.projectLogicalRect(
      contentRect,
      inlineOffset: slotInlineOffset,
      blockOffset: baseBlockOffset,
      inlineExtent: table.inlineExtent,
      blockExtent: table.blockExtent,
    );
    if (tableRect == null) {
      return;
    }
    canvas.drawRect(
      tableRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = theme.noteColor.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );

    for (final row in table.rows) {
      final rowRect = projection.projectLogicalRect(
        contentRect,
        inlineOffset: projectedBaseInlineOffset + row.inlineOffset,
        blockOffset: baseBlockOffset + row.blockOffset,
        inlineExtent: row.inlineExtent,
        blockExtent: row.blockExtent,
      );
      if (rowRect == null) {
        continue;
      }
      canvas.drawRect(
        rowRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = theme.noteColor.withValues(alpha: 0.2)
          ..strokeWidth = 1,
      );

      for (final cell in row.cells) {
        final cellInlineOffset =
            projectedBaseInlineOffset + row.inlineOffset + cell.inlineOffset;
        final cellBlockOffset =
            baseBlockOffset + row.blockOffset + cell.blockOffset;
        final cellRect = projection.projectLogicalRect(
          contentRect,
          inlineOffset: cellInlineOffset,
          blockOffset: cellBlockOffset,
          inlineExtent: cell.inlineExtent,
          blockExtent: cell.blockExtent,
        );
        if (cellRect == null) {
          continue;
        }
        canvas.drawRect(
          cellRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = theme.noteColor.withValues(alpha: 0.18)
            ..strokeWidth = 1,
        );
        for (final child in cell.blocks) {
          _paintBlock(
            canvas,
            child,
            contentRect,
            projection: projection,
            baseInlineOffset: cellInlineOffset,
            baseBlockOffset: cellBlockOffset,
          );
        }
      }
    }
  }

  void _paintLineGroup(
    Canvas canvas,
    LayoutLineGroup group,
    Rect contentRect, {
    required KumihanPageProjection projection,
    required double baseInlineOffset,
    required double baseBlockOffset,
  }) {
    for (final line in group.lines) {
      final slotInlineOffset = projection.projectedSlotInlineOffset(line);
      if (slotInlineOffset == null) {
        continue;
      }
      final projectedBaseInlineOffset = slotInlineOffset - line.inlineOffset;
      final lineBlockOffset = baseBlockOffset + line.blockOffset;

      for (final marker in line.markers) {
        _paintMarker(
          canvas,
          marker,
          contentRect,
          projection: projection,
          baseInlineOffset: projectedBaseInlineOffset,
          baseBlockOffset: lineBlockOffset,
        );
      }
      for (final fragment in line.fragments) {
        _paintFragment(
          canvas,
          fragment,
          contentRect,
          projection: projection,
          baseInlineOffset: projectedBaseInlineOffset,
          baseBlockOffset: lineBlockOffset,
        );
      }
      for (final ruby in line.rubies) {
        _paintRuby(
          canvas,
          ruby,
          contentRect,
          projection: projection,
          baseInlineOffset: projectedBaseInlineOffset,
          baseBlockOffset: lineBlockOffset,
        );
      }
    }
  }

  void _paintFragment(
    Canvas canvas,
    LayoutFragment fragment,
    Rect contentRect, {
    required KumihanPageProjection projection,
    required double baseInlineOffset,
    required double baseBlockOffset,
  }) {
    final rect = projection.projectLogicalRect(
      contentRect,
      inlineOffset: baseInlineOffset + fragment.inlineOffset,
      blockOffset: baseBlockOffset + fragment.blockOffset,
      inlineExtent: math.max(fragment.inlineExtent, 1),
      blockExtent: math.max(fragment.blockExtent, 1),
    );
    if (rect == null) {
      return;
    }

    switch (fragment) {
      case LayoutTextFragment():
        _paintVerticalText(
          canvas,
          rect,
          fragment.text,
          fragment.style,
          color: theme.textColor,
        );
      case LayoutGaijiFragment():
        _paintVerticalText(
          canvas,
          rect,
          fragment.displayText,
          fragment.style,
          color: theme.textColor,
        );
      case LayoutImageFragment():
        canvas.drawRect(
          rect,
          Paint()..color = theme.noteColor.withValues(alpha: 0.12),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = theme.noteColor.withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
        _paintCenteredText(
          canvas,
          rect,
          'IMG',
          _textStyle(fontScale: 0.75, color: theme.noteColor),
        );
      case LayoutNoteFragment():
        canvas.drawRect(
          rect,
          Paint()..color = theme.noteColor.withValues(alpha: 0.08),
        );
        final label = [
          if (fragment.upperText case final String upper when upper.isNotEmpty)
            upper,
          if (fragment.lowerText case final String lower when lower.isNotEmpty)
            lower,
          if ((fragment.upperText == null || fragment.upperText!.isEmpty) &&
              (fragment.lowerText == null || fragment.lowerText!.isEmpty))
            fragment.text,
        ].join('\n');
        _paintCenteredText(
          canvas,
          rect,
          label,
          _textStyle(
            fontScale: fragment.style.fontScale * theme.noteScale,
            color: theme.noteColor,
          ),
        );
      case LayoutUnsupportedFragment():
        canvas.drawRect(
          rect,
          Paint()..color = theme.markerColor.withValues(alpha: 0.08),
        );
        _paintCenteredText(
          canvas,
          rect,
          '未対応',
          _textStyle(fontScale: 0.7, color: theme.noteColor),
        );
      case LayoutLinkFragment():
        _paintFragmentsWithin(rect, fragment.children);
      case LayoutAnchorFragment():
        canvas.drawCircle(
          rect.topLeft + const Offset(4, 4),
          3,
          Paint()..color = theme.noteColor.withValues(alpha: 0.6),
        );
    }
  }

  void _paintFragmentsWithin(Rect rect, List<LayoutFragment> children) {
    if (children.isEmpty) {
      return;
    }
  }

  void _paintRuby(
    Canvas canvas,
    LayoutRubyPlacement ruby,
    Rect contentRect, {
    required KumihanPageProjection projection,
    required double baseInlineOffset,
    required double baseBlockOffset,
  }) {
    final characters = ruby.text.characters.toList(growable: false);
    if (characters.isEmpty) {
      return;
    }
    final crossExtent = ruby.inlineExtent;
    final inlineOffset =
        baseInlineOffset + ruby.lineInlineOffset - ruby.crossOffset;
    final rect = projection.projectLogicalRect(
      contentRect,
      inlineOffset: inlineOffset,
      blockOffset: baseBlockOffset + ruby.blockOffset,
      inlineExtent: math.max(crossExtent, theme.rubyScale),
      blockExtent: math.max(ruby.blockExtent, theme.rubyScale),
    );
    if (rect == null) {
      return;
    }
    final style = _textStyle(
      fontScale: theme.rubyScale,
      color: theme.rubyColor,
    );
    final glyphExtent = theme.fontSize * theme.rubyScale;
    final tracking = theme.fontSize * ruby.interCharacterSpacing;
    var cursor = rect.top;

    for (final character in characters) {
      final glyphRect = Rect.fromLTWH(
        rect.left,
        cursor,
        rect.width,
        glyphExtent,
      );
      _paintVerticalGlyph(canvas, glyphRect, character, style);
      cursor += glyphExtent + tracking;
    }
  }

  void _paintMarker(
    Canvas canvas,
    LayoutMarker marker,
    Rect contentRect, {
    required KumihanPageProjection projection,
    required double baseInlineOffset,
    required double baseBlockOffset,
  }) {
    final rect = projection.projectLogicalRect(
      contentRect,
      inlineOffset:
          baseInlineOffset + marker.lineInlineOffset - marker.crossOffset,
      blockOffset: baseBlockOffset + marker.blockOffset,
      inlineExtent: math.max(marker.inlineExtent, 0.35),
      blockExtent: math.max(marker.blockExtent, 0.35),
    );
    if (rect == null) {
      return;
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = theme.markerColor
      ..strokeWidth = 1;
    final fill = Paint()..color = theme.markerColor;

    switch (marker.kind) {
      case LayoutMarkerKind.frame:
        canvas.drawRect(rect, stroke);
      case LayoutMarkerKind.decoration:
        canvas.drawLine(rect.topLeft, rect.bottomLeft, stroke);
      case LayoutMarkerKind.emphasis:
        final emphasisGlyph = _emphasisGlyph(marker.emphasisMark);
        final count = math.max(marker.repeatCount ?? 0, 1);
        final step = rect.height / count;
        for (var index = 0; index < count; index += 1) {
          final cellRect = Rect.fromLTWH(
            rect.left,
            rect.top + step * index,
            rect.width,
            step,
          );
          _paintVerticalText(
            canvas,
            cellRect,
            emphasisGlyph,
            const LayoutInlineStyle(
              fontScale: 0.48,
              bold: false,
              italic: false,
              caption: false,
            ),
            color: theme.textColor,
            forcedFontScale: 0.48,
          );
        }
      case LayoutMarkerKind.note ||
          LayoutMarkerKind.kaeriten ||
          LayoutMarkerKind.okurigana ||
          LayoutMarkerKind.editorNote ||
          LayoutMarkerKind.unsupported:
        canvas.drawRect(
          rect,
          Paint()..color = theme.markerColor.withValues(alpha: 0.08),
        );
        _paintCenteredText(
          canvas,
          rect,
          marker.text ?? _markerFallbackLabel(marker.kind),
          _textStyle(fontScale: 0.52, color: theme.noteColor),
        );
    }
  }

  String _markerFallbackLabel(LayoutMarkerKind kind) {
    return switch (kind) {
      LayoutMarkerKind.note => '注',
      LayoutMarkerKind.kaeriten => '返',
      LayoutMarkerKind.okurigana => '送',
      LayoutMarkerKind.editorNote => '編',
      LayoutMarkerKind.unsupported => '未',
      _ => '',
    };
  }

  String _emphasisGlyph(EmphasisMark? mark) {
    return switch (mark) {
      EmphasisMark.whiteSesameDot => '﹆',
      EmphasisMark.blackCircle => '⬤',
      EmphasisMark.whiteCircle => '○',
      EmphasisMark.blackTriangle => '▲',
      EmphasisMark.whiteTriangle => '△',
      EmphasisMark.bullseye => '◎',
      EmphasisMark.fisheye => '◉',
      EmphasisMark.saltire => '❌',
      _ => '﹅',
    };
  }

  void _paintGuides(Canvas canvas, Rect contentRect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = theme.guideColor
      ..strokeWidth = 1;
    canvas.drawRect(contentRect, paint);
    final lineStep = theme.fontSize;
    for (var y = contentRect.top; y <= contentRect.bottom; y += lineStep) {
      canvas.drawLine(
        Offset(contentRect.left, y),
        Offset(contentRect.right, y),
        paint,
      );
    }
  }

  void _paintDiagnosticsOverlay(Canvas canvas, Rect pageRect) {
    final summary =
        'blocks ${result.blocks.length}  diagnostics ${result.diagnostics.length}  issues ${result.issues.length}';
    final rect = Rect.fromLTWH(pageRect.left + 8, pageRect.top + 8, 280, 24);
    canvas.drawRect(rect, Paint()..color = const Color(0xaa111111));
    _paintCenteredText(
      canvas,
      rect,
      summary,
      const TextStyle(color: Color(0xffffffff), fontSize: 11),
    );
  }

  void _paintProvisionalBanner(Canvas canvas, Rect pageRect) {
    const bannerHeight = 24.0;
    final rect = Rect.fromLTWH(pageRect.left, pageRect.top, 196, bannerHeight);
    canvas.drawRect(rect, Paint()..color = theme.provisionalBannerColor);
    _paintCenteredText(
      canvas,
      rect,
      theme.provisionalLabel,
      const TextStyle(
        color: Color(0xffffffff),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _paintVerticalText(
    Canvas canvas,
    Rect rect,
    String text,
    LayoutInlineStyle style, {
    required Color color,
    double? forcedFontScale,
  }) {
    final sanitized = text.trim().isEmpty ? text : text;
    if (sanitized.isEmpty) {
      return;
    }
    final fontScale = forcedFontScale ?? style.fontScale;
    final horizontalRun =
        style.directionKind == DirectionKind.tateChuYoko;

    if (horizontalRun) {
      _paintCenteredText(
        canvas,
        rect,
        sanitized,
        _textStyle(fontScale: fontScale, color: color, style: style),
      );
      return;
    }

    if (sanitized.characters.length > 1 && shouldRotateVerticalGlyph(sanitized)) {
      _paintVerticalGlyph(
        canvas,
        rect,
        sanitized,
        _textStyle(fontScale: fontScale, color: color, style: style),
      );
      return;
    }

    final characters = sanitized.characters.toList(growable: false);
    final step = rect.height / characters.length;
    for (var index = 0; index < characters.length; index += 1) {
      final cellRect = Rect.fromLTWH(
        rect.left,
        rect.top + step * index,
        rect.width,
        step,
      );
      _paintVerticalGlyph(
        canvas,
        cellRect,
        characters[index],
        _textStyle(fontScale: fontScale, color: color, style: style),
      );
    }
  }

  void _paintVerticalGlyph(
    Canvas canvas,
    Rect rect,
    String text,
    TextStyle style,
  ) {
    final layout = computeVerticalGlyphLayout(rect, text, style, theme);
    if (layout.isRotated) {
      canvas.save();
      canvas.translate(layout.translateX, layout.translateY);
      canvas.rotate(layout.rotation);
      layout.painter.paint(canvas, layout.paintOffset);
      canvas.restore();
      return;
    }
    layout.painter.paint(canvas, layout.paintOffset);
  }

  void _paintCenteredText(
    Canvas canvas,
    Rect rect,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: text.contains('\n') ? null : 1,
    )..layout(maxWidth: rect.width);

    final dx = rect.left + (rect.width - painter.width) / 2;
    final dy = rect.top + (rect.height - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  TextStyle _textStyle({
    required double fontScale,
    required Color color,
    LayoutInlineStyle? style,
  }) {
    return TextStyle(
      color: color,
      fontSize: theme.fontSize * fontScale,
      fontFamily: theme.fontFamily,
      package: theme.fontFamilyPackage,
      fontFamilyFallback: theme.fontFamilyFallback,
      fontWeight: style?.bold == true ? FontWeight.w700 : FontWeight.w400,
      fontStyle: style?.italic == true ? FontStyle.italic : FontStyle.normal,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
      textBaseline: TextBaseline.ideographic,
    );
  }

  @override
  bool shouldRepaint(covariant KumihanLayoutPainter oldDelegate) {
    return oldDelegate.result != result || oldDelegate.theme != theme;
  }
}
