import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../ast/ast.dart';
import '../layout_ir/layout_ir.dart';
import 'compat/gaiji_resolver.dart';
import 'compat/line_breaker.dart';
import 'compat/utr50.dart';
import 'layout_result.dart';

class LayoutResultBuilder {
  LayoutResultBuilder({this.constraints = const LayoutConstraints()});

  final LayoutConstraints constraints;

  static const String _fallbackGaiji = '〓';
  static const String _noteOpen = '（';
  static const String _noteClose = '）';

  static const String _lineStartForbidden =
      '、。，．・：；！？)]｝〕〉》」』】〙〗ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮー゛゜々ゝゞヽヾ';
  static const String _lineEndForbidden = '([｛〔〈《「『【〘〖';
  static const String _openingBrackets = '‘“（〔［｛〈《「『【｟〘〖«〝';
  static const String _closingBrackets = '’”）〕］｝〉》」』】｠〙〗»〟';
  static const String _punctuationMarks = '，、。﹐﹑﹒，．';
  static const String _hangingLineEndGlyphs =
      '$_closingBrackets$_punctuationMarks';
  static const String _halfWidthNextToClosing =
      '$_punctuationMarks$_openingBrackets$_closingBrackets・';
  static const String _halfWidthNextToOpening = '$_openingBrackets・';
  static const String _zeroExtentGlyphs = '⁠￼゛゜';
  static const String _legacySidewaysCloseGlyphs =
      '$_closingBrackets$_punctuationMarks・￼゛゜';
  static const String _legacyRotatedAtomTypes = '…─';
  static final RegExp _cjkIdeographPattern = RegExp(r'[⺀-⻳㐁-䶮一-龻豈-龎仝々〆〇ヶ]');
  static final RegExp _hiraganaPattern = RegExp(r'[ぁ-んゝゞ]');
  static const String _wordJoiner = '\u2060';
  static const String _measurementFontFamily = 'WebFontMincho';
  static const String _measurementFontPackage = 'kumihan';
  static const String _sidewaysRotatedGlyphs =
      ' '
      '‘’“”'
      '()[]{}'
      '（）〔〕［］｛｝'
      '〈〉《》「」『』【】｟｠〘〙〖〗«»〝〟'
      '…ー';

  final GaijiResolver _gaijiResolver = const GaijiResolver();

  LayoutResult build(LayoutDocument document) {
    final flow = _layoutBlocks(
      document.children,
      _BlockContext.initial(constraints),
      baseInlineOffset: 0,
    );
    return LayoutResult(
      span: document.span,
      constraints: constraints,
      blocks: List<LayoutBlockResult>.unmodifiable(flow.blocks),
      hitRegions: List<LayoutHitRegion>.unmodifiable(flow.hitRegions),
      inlineExtent: flow.inlineExtent,
      blockExtent: flow.blockExtent,
      diagnostics: List<AstDiagnostic>.unmodifiable(document.diagnostics),
      issues: List<LayoutIssue>.unmodifiable(document.issues),
    );
  }

  _FlowLayout _layoutBlocks(
    List<LayoutBlock> blocks,
    _BlockContext context, {
    required double baseInlineOffset,
  }) {
    final results = <LayoutBlockResult>[];
    final hitRegions = <LayoutHitRegion>[];
    var cursor = baseInlineOffset;
    var blockExtent = 0.0;
    var emitted = false;

    void applyGap(bool keepWithPrevious) {
      if (emitted && !keepWithPrevious) {
        cursor += constraints.blockGap;
      }
    }

    void append(_LeafLayout leaf) {
      results.add(leaf.block);
      hitRegions.addAll(leaf.hitRegions);
      blockExtent = math.max(blockExtent, leaf.block.blockExtent);
      cursor += leaf.block.inlineExtent;
      emitted = true;
    }

    void appendFlow(_FlowLayout flow) {
      if (flow.blocks.isEmpty) {
        return;
      }
      results.addAll(flow.blocks);
      hitRegions.addAll(flow.hitRegions);
      blockExtent = math.max(blockExtent, flow.blockExtent);
      cursor += flow.inlineExtent;
      emitted = true;
    }

    for (final block in blocks) {
      switch (block) {
        case LayoutParagraph():
          applyGap(block.keepWithPrevious);
          append(_layoutParagraph(block, context, inlineOffset: cursor));
        case LayoutEmptyLine():
          applyGap(false);
          append(_layoutEmptyLine(block, context, inlineOffset: cursor));
        case LayoutUnsupportedBlock():
          applyGap(false);
          append(_layoutUnsupportedBlock(block, context, inlineOffset: cursor));
        case LayoutIndentBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withIndent(
                _resolveLegacyDirectiveWidth(block.width, context),
              ),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutAlignmentBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withAlignment(block.kind),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutJizumeBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withJizume(
                block.width == null
                    ? null
                    : _resolveLegacyDirectiveWidth(block.width, context),
              ),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutFlowBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withFlow(block.kind),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutCaptionBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withCaption(),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutFrameBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withFrame(block.kind, block.borderWidth),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutStyledBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withTextStyle(block.style),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutFontSizeBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withFontSize(block.kind, block.steps),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutHeadingBlock():
          applyGap(false);
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withHeading(block.level, block.display),
              baseInlineOffset: cursor,
            ),
          );
        case LayoutTableBlock():
          applyGap(false);
          append(_layoutTable(block, context, inlineOffset: cursor));
      }
    }

    return _FlowLayout(
      blocks: results,
      hitRegions: hitRegions,
      inlineExtent: emitted ? cursor - baseInlineOffset : 0,
      blockExtent: blockExtent,
    );
  }

  _LeafLayout _layoutParagraph(
    LayoutParagraph block,
    _BlockContext context, {
    required double inlineOffset,
  }) {
    final model = _ParagraphModel(span: block.span);
    _emitInlines(block.children, model, context.inlineContext);
    _applyLegacyKinsoku(model.atoms);
    final lines = _buildLines(
      block.span,
      model,
      context,
      groupInlineOffset: inlineOffset,
    );
    final group = LayoutLineGroup(
      span: block.span,
      inlineOffset: inlineOffset,
      blockOffset: 0,
      inlineExtent: lines.groupInlineExtent,
      blockExtent: lines.groupBlockExtent,
      lines: List<LayoutLine>.unmodifiable(lines.lines),
    );
    final paragraph = LayoutParagraphResult(
      span: block.span,
      inlineOffset: inlineOffset,
      blockOffset: 0,
      inlineExtent: group.inlineExtent,
      blockExtent: group.blockExtent,
      style: _blockStyle(context, keepWithPrevious: block.keepWithPrevious),
      lineGroup: group,
      issues: block.issues,
    );
    return _LeafLayout(block: paragraph, hitRegions: lines.hitRegions);
  }

  _LeafLayout _layoutEmptyLine(
    LayoutEmptyLine block,
    _BlockContext context, {
    required double inlineOffset,
  }) {
    final lineExtent = context.resolvedLineExtent;
    final line = LayoutLine(
      span: block.span,
      inlineOffset: inlineOffset,
      blockOffset: 0,
      inlineExtent: context.crossExtent,
      blockExtent: lineExtent,
      textExtent: 0,
      fragments: const <LayoutFragment>[],
      rubies: const <LayoutRubyPlacement>[],
      markers: _frameMarkersForEmptyLine(
        block.span,
        context,
        inlineOffset,
        lineExtent,
      ),
    );
    final group = LayoutLineGroup(
      span: block.span,
      inlineOffset: inlineOffset,
      blockOffset: 0,
      inlineExtent: line.inlineExtent,
      blockExtent: line.blockExtent,
      lines: List<LayoutLine>.unmodifiable(<LayoutLine>[line]),
    );
    return _LeafLayout(
      block: LayoutEmptyLineResult(
        span: block.span,
        inlineOffset: inlineOffset,
        blockOffset: 0,
        inlineExtent: group.inlineExtent,
        blockExtent: group.blockExtent,
        style: _blockStyle(context),
        lineGroup: group,
        issues: block.issues,
      ),
      hitRegions: const <LayoutHitRegion>[],
    );
  }

  _LeafLayout _layoutUnsupportedBlock(
    LayoutUnsupportedBlock block,
    _BlockContext context, {
    required double inlineOffset,
  }) {
    return _LeafLayout(
      block: LayoutUnsupportedBlockResult(
        span: block.span,
        inlineOffset: inlineOffset,
        blockOffset: 0,
        inlineExtent: 0,
        blockExtent: 0,
        style: _blockStyle(context),
        directive: block.directive,
        issues: block.issues,
      ),
      hitRegions: const <LayoutHitRegion>[],
    );
  }

  _LeafLayout _layoutTable(
    LayoutTableBlock block,
    _BlockContext context, {
    required double inlineOffset,
  }) {
    final columnCount = block.rows.fold<int>(
      0,
      (count, row) => math.max(count, row.cells.length),
    );
    final effectiveColumns = math.max(columnCount, 1);
    final cellLineExtent = math.max(
      constraints.minTableCellLineExtent,
      context.resolvedLineExtent / effectiveColumns,
    );
    final cellContext = context.withExplicitLineExtent(cellLineExtent);

    final rowLayouts = <_TableRowDraft>[];
    final columnExtents = List<double>.filled(effectiveColumns, 0);
    final rowBlockExtents = <double>[];

    for (final row in block.rows) {
      final cells = <_TableCellDraft>[];
      var rowBlockExtent = 0.0;
      for (final cell in row.cells) {
        final flow = _layoutBlocks(
          cell.children,
          cellContext,
          baseInlineOffset: 0,
        );
        cells.add(
          _TableCellDraft(
            span: cell.span,
            blocks: flow.blocks,
            attributes: cell.attributes,
            issues: cell.issues,
            inlineExtent: flow.inlineExtent,
            blockExtent: flow.blockExtent,
            hitRegions: flow.hitRegions,
          ),
        );
        rowBlockExtent = math.max(rowBlockExtent, flow.blockExtent);
      }
      for (var index = 0; index < cells.length; index += 1) {
        columnExtents[index] = math.max(
          columnExtents[index],
          cells[index].inlineExtent,
        );
      }
      rowBlockExtents.add(rowBlockExtent);
      rowLayouts.add(
        _TableRowDraft(
          span: row.span,
          cells: cells,
          attributes: row.attributes,
          issues: row.issues,
        ),
      );
    }

    final rowResults = <LayoutTableRowResult>[];
    final hitRegions = <LayoutHitRegion>[];
    var rowBlockOffset = 0.0;
    for (var rowIndex = 0; rowIndex < rowLayouts.length; rowIndex += 1) {
      final draft = rowLayouts[rowIndex];
      final cells = <LayoutTableCellResult>[];
      var cellInlineOffset = 0.0;
      for (var cellIndex = 0; cellIndex < draft.cells.length; cellIndex += 1) {
        final cell = draft.cells[cellIndex];
        cells.add(
          LayoutTableCellResult(
            span: cell.span,
            inlineOffset: cellInlineOffset,
            blockOffset: rowBlockOffset,
            inlineExtent: columnExtents[cellIndex],
            blockExtent: rowBlockExtents[rowIndex],
            blocks: List<LayoutBlockResult>.unmodifiable(cell.blocks),
            attributes: cell.attributes,
            issues: cell.issues,
          ),
        );
        for (final region in cell.hitRegions) {
          hitRegions.add(
            LayoutHitRegion(
              kind: region.kind,
              span: region.span,
              inlineOffset:
                  inlineOffset + cellInlineOffset + region.inlineOffset,
              blockOffset: rowBlockOffset + region.blockOffset,
              inlineExtent: region.inlineExtent,
              blockExtent: region.blockExtent,
              data: region.data,
            ),
          );
        }
        cellInlineOffset += columnExtents[cellIndex];
        if (cellIndex + 1 < effectiveColumns) {
          cellInlineOffset += constraints.lineGap;
        }
      }
      final rowInlineExtent = _sumTableExtents(
        columnExtents,
        constraints.lineGap,
      );
      rowResults.add(
        LayoutTableRowResult(
          span: draft.span,
          inlineOffset: 0,
          blockOffset: rowBlockOffset,
          inlineExtent: rowInlineExtent,
          blockExtent: rowBlockExtents[rowIndex],
          cells: List<LayoutTableCellResult>.unmodifiable(cells),
          attributes: draft.attributes,
          issues: draft.issues,
        ),
      );
      rowBlockOffset += rowBlockExtents[rowIndex];
      if (rowIndex + 1 < rowLayouts.length) {
        rowBlockOffset += constraints.lineGap;
      }
    }

    final tableInlineExtent = _sumTableExtents(
      columnExtents,
      constraints.lineGap,
    );
    final table = LayoutTableResult(
      span: block.span,
      inlineOffset: inlineOffset,
      blockOffset: 0,
      inlineExtent: tableInlineExtent,
      blockExtent: rowBlockOffset,
      style: _blockStyle(context),
      rows: List<LayoutTableRowResult>.unmodifiable(rowResults),
      attributes: block.attributes,
      issues: block.issues,
    );
    return _LeafLayout(block: table, hitRegions: hitRegions);
  }

  _LineBuildResult _buildLines(
    SourceSpan span,
    _ParagraphModel model,
    _BlockContext context, {
    required double groupInlineOffset,
  }) {
    final lines = <LayoutLine>[];
    final hitRegions = <LayoutHitRegion>[];
    final breakPositions = _computeLineBreakOpportunities(model.atoms);
    final rubyTrackingAdjustments = _resolveLegacyRubyTrackingAdjustments(
      model,
    );
    var lineInlineOffset = groupInlineOffset;
    var atomCursor = 0;
    var lineIndex = 0;

    if (model.atoms.isEmpty) {
      final line = LayoutLine(
        span: span,
        inlineOffset: lineInlineOffset,
        blockOffset: 0,
        inlineExtent: context.crossExtent,
        blockExtent: context.resolvedLineExtent,
        textExtent: 0,
        fragments: const <LayoutFragment>[],
        rubies: _buildRubiesForLine(
          model,
          const <int, _FragmentPlacement>{},
          0,
          0,
          lineInlineOffset,
          context,
          boundaryAdjustments: const <int, double>{},
        ),
        markers: _frameMarkersForEmptyLine(
          span,
          context,
          lineInlineOffset,
          context.resolvedLineExtent,
        ),
      );
      lines.add(line);
      return _LineBuildResult(
        lines: lines,
        hitRegions: hitRegions,
        groupInlineExtent: line.inlineExtent,
        groupBlockExtent: line.blockExtent,
      );
    }

    while (atomCursor < model.atoms.length) {
      final firstLine = lineIndex == 0;
      final lineDraft = _takeLineDraft(
        model.atoms,
        atomCursor,
        breakPositions,
        context,
        firstLine: firstLine,
        baseBoundaryAdjustments: rubyTrackingAdjustments.boundaryAdjustments,
      );
      atomCursor = lineDraft.nextCursor;
      final line = _materializeLine(
        span,
        model,
        lineDraft,
        breakPositions,
        context,
        lineInlineOffset: lineInlineOffset,
        baseBoundaryAdjustments: rubyTrackingAdjustments.boundaryAdjustments,
        baseTrailingExtent: rubyTrackingAdjustments.trailingExtent,
      );
      lines.add(line.line);
      hitRegions.addAll(line.hitRegions);
      lineInlineOffset += line.line.inlineExtent + constraints.lineGap;
      lineIndex += 1;
    }

    final groupInlineExtent = lines.isEmpty
        ? 0
        : lineInlineOffset - groupInlineOffset - constraints.lineGap;
    final groupBlockExtent = lines.fold<double>(
      0,
      (current, line) => math.max(current, line.blockExtent),
    );
    return _LineBuildResult(
      lines: lines,
      hitRegions: hitRegions,
      groupInlineExtent: groupInlineExtent.toDouble(),
      groupBlockExtent: groupBlockExtent,
    );
  }

  _TakenLineDraft _takeLineDraft(
    List<_Atom> atoms,
    int start,
    Set<int> breakPositions,
    _BlockContext context, {
    required bool firstLine,
    required Map<int, double> baseBoundaryAdjustments,
  }) {
    final indent = firstLine ? context.firstIndent : context.restIndent;
    final available = math.max(context.resolvedLineExtent - indent, 1.0);
    var cursor = start;
    var trackedWidth = 0.0;
    var lastBreakWidth = 0.0;
    var breakIndex = start;
    var lastAtomWidth = 0.0;
    var firstVisibleIndex = -1;
    var endedByExplicitLineBreak = false;

    bool isHangingLineEndAtom(_Atom atom) {
      if (atom.text.isEmpty) {
        return false;
      }
      final lastCharacter = String.fromCharCode(atom.text.runes.last);
      return _hangingLineEndGlyphs.contains(lastCharacter);
    }

    for (var index = start; index < atoms.length; index += 1) {
      final atom = atoms[index];
      if (atom.kind == _AtomKind.lineBreak) {
        cursor = index + 1;
        endedByExplicitLineBreak = true;
        break;
      }
      if (atom.kind.isMarkerOnly) {
        continue;
      }

      if (!atom.legacyKinsoku) {
        lastBreakWidth = trackedWidth;
        breakIndex = index;
      }

      final atomWidth = atom.inlineExtent;
      lastAtomWidth = atomWidth;

      var boundaryAdjustment = baseBoundaryAdjustments[index] ?? 0.0;
      if (firstVisibleIndex < 0 &&
          start > 0 &&
          atom.kind == _AtomKind.text &&
          _openingBrackets.contains(atom.text)) {
        boundaryAdjustment -= atom.inlineExtent / 2;
      }

      trackedWidth += atom.blockExtent + boundaryAdjustment;
      if (firstVisibleIndex < 0) {
        firstVisibleIndex = index;
      }

      if (trackedWidth > available && breakIndex != start) {
        if (!isHangingLineEndAtom(atom)) {
          cursor = index;
          break;
        }
        if (trackedWidth - atomWidth / 2 > available) {
          cursor = index;
          break;
        }
      }

      cursor = index + 1;
      if (index >= atoms.length - 1) {
        lastBreakWidth = trackedWidth;
        breakIndex = index + 1;
      }
    }

    if (endedByExplicitLineBreak) {
      if (firstVisibleIndex >= 0) {
        lastBreakWidth = trackedWidth;
        breakIndex = cursor - 1;
      } else {
        breakIndex = start;
      }
    }

    if (breakIndex != start) {
      final lastVisibleIndex = _previousVisibleAtomCursor(atoms, breakIndex - 1);
      if (lastVisibleIndex >= start &&
          isHangingLineEndAtom(atoms[lastVisibleIndex])) {
        lastBreakWidth = math.max(lastBreakWidth - lastAtomWidth / 2, 0);
      }
    }

    if (breakIndex == start && start < atoms.length) {
      final atom = atoms[start];
      if (atom.kind == _AtomKind.lineBreak) {
        return _TakenLineDraft(
          start: start,
          end: start,
          nextCursor: start + 1,
          indent: indent,
          textExtent: 0,
        );
      }
      final end = _consumeLeadingMarkers(atoms, start + 1);
      var boundaryAdjustment = baseBoundaryAdjustments[start] ?? 0.0;
      if (start > 0 &&
          atom.kind == _AtomKind.text &&
          _openingBrackets.contains(atom.text)) {
        boundaryAdjustment -= atom.inlineExtent / 2;
      }
      return _TakenLineDraft(
        start: start,
        end: end,
        nextCursor: end,
        indent: indent,
        textExtent: atom.blockExtent + boundaryAdjustment,
      );
    }

    return _TakenLineDraft(
      start: start,
      end: breakIndex,
      nextCursor: endedByExplicitLineBreak ? cursor : breakIndex,
      indent: indent,
      textExtent: lastBreakWidth,
    );
  }

  double _resolveLegacyDirectiveWidth(int? width, _BlockContext context) {
    if (width == null || width <= 0) {
      return 0;
    }
    if (width > 5) {
      return width * context.resolvedLineExtent / 40;
    }
    return width * context.fontScale;
  }

  _MaterializedLine _materializeLine(
    SourceSpan span,
    _ParagraphModel model,
    _TakenLineDraft draft,
    Set<int> breakPositions,
    _BlockContext context, {
    required double lineInlineOffset,
    required Map<int, double> baseBoundaryAdjustments,
    required double baseTrailingExtent,
  }) {
    final hitRegions = <LayoutHitRegion>[];
    final trackingAdjustments = _resolveTrackingAdjustments(
      model.atoms,
      draft,
      context,
      baseBoundaryAdjustments: baseBoundaryAdjustments,
      baseTrailingExtent: baseTrailingExtent,
    );
    final initialPlacements = _buildAtomPlacements(
      model.atoms,
      draft,
      context,
      boundaryAdjustments: _mergeBoundaryAdjustments(
        baseBoundaryAdjustments,
        trackingAdjustments,
      ),
    );
    final lineBoundaryAdjustments = _mergeBoundaryAdjustments(
      baseBoundaryAdjustments,
      trackingAdjustments,
    );
    final combinedBoundaryAdjustments = lineBoundaryAdjustments;
    final atomPlacements = initialPlacements;
    final lineBoundaryAdjustmentExtent = combinedBoundaryAdjustments.entries
        .where((entry) => entry.key >= draft.start && entry.key < draft.end)
        .fold<double>(0, (sum, entry) => sum + entry.value);
    final trailingAdjustmentExtent = draft.end >= model.atoms.length
        ? baseTrailingExtent
        : 0;
    final justifiedTextExtent =
        draft.textExtent +
        lineBoundaryAdjustmentExtent +
        trailingAdjustmentExtent;
    final fragments = <LayoutFragment>[];
    for (var index = draft.start; index < draft.end; index += 1) {
      final atom = model.atoms[index];
      if (atom.kind == _AtomKind.lineBreak || atom.kind.isMarkerOnly) {
        continue;
      }
      final placement = atomPlacements[index];
      if (placement == null) {
        continue;
      }
      final fragment = _buildFragment(atom, placement, lineInlineOffset);
      if (fragment != null) {
        fragments.add(fragment);
        if (fragment case LayoutImageFragment()) {
          hitRegions.add(
            LayoutHitRegion(
              kind: LayoutHitRegionKind.image,
              span: fragment.span,
              inlineOffset: lineInlineOffset,
              blockOffset: fragment.blockOffset,
              inlineExtent: fragment.inlineExtent,
              blockExtent: fragment.blockExtent,
              data: fragment.source,
            ),
          );
        }
      }
    }

    // v0 paginates and positions vertical lines by the maximum rendered glyph
    // width in the line, not by a fixed 1em column width. Preserve that here
    // so wide glyphs (for example headings or rotated runs) consume the same
    // inline slot width during page projection.
    final lineInlineExtent = atomPlacements.values.fold<double>(
      0,
      (current, placement) => math.max(current, placement.inlineExtent),
    );

    final rubies = _buildRubiesForLine(
      model,
      atomPlacements,
      draft.start,
      draft.end,
      lineInlineOffset,
      context,
      boundaryAdjustments: combinedBoundaryAdjustments,
    );
    final markers = <LayoutMarker>[
      ..._buildRangeMarkersForLine(
        model,
        atomPlacements,
        draft.start,
        draft.end,
        lineInlineOffset,
        context,
        boundaryAdjustments: combinedBoundaryAdjustments,
      ),
      ..._buildPointMarkersForLine(
        model,
        atomPlacements,
        draft.start,
        draft.end,
        lineInlineOffset,
        context,
      ),
      ..._frameMarkersForLine(
        model,
        atomPlacements,
        draft.start,
        draft.end,
        lineInlineOffset,
        context,
      ),
    ];
    hitRegions.addAll(
      _buildLinkHitRegionsForLine(
        model,
        atomPlacements,
        draft.start,
        draft.end,
        lineInlineOffset,
      ),
    );
    hitRegions.addAll(
      _buildAnchorHitRegionsForLine(
        model,
        atomPlacements,
        draft.start,
        draft.end,
        lineInlineOffset,
      ),
    );

    return _MaterializedLine(
      line: LayoutLine(
        span: span,
        inlineOffset: lineInlineOffset,
        blockOffset: 0,
        inlineExtent: math.max(lineInlineExtent, context.crossExtent),
        blockExtent: context.resolvedLineExtent,
        textExtent: justifiedTextExtent,
        fragments: List<LayoutFragment>.unmodifiable(fragments),
        rubies: List<LayoutRubyPlacement>.unmodifiable(rubies),
        markers: List<LayoutMarker>.unmodifiable(markers),
      ),
      hitRegions: hitRegions,
    );
  }

  Map<int, double> _resolveTrackingAdjustments(
    List<_Atom> atoms,
    _TakenLineDraft draft,
    _BlockContext context, {
    required Map<int, double> baseBoundaryAdjustments,
    required double baseTrailingExtent,
  }) {
    if (draft.nextCursor >= atoms.length) {
      return const <int, double>{};
    }
    var occupied = draft.textExtent;
    for (var index = draft.start; index < draft.end; index += 1) {
      occupied += baseBoundaryAdjustments[index] ?? 0;
    }
    if (draft.end >= atoms.length) {
      occupied += baseTrailingExtent;
    }
    final slack = context.resolvedLineExtent - occupied;
    if (slack <= 0) {
      return const <int, double>{};
    }

    final adjustable = <int>[];
    for (var index = draft.start + 1; index < draft.end; index += 1) {
      final atom = atoms[index];
      if (atom.kind.isMarkerOnly || atom.kind == _AtomKind.lineBreak) {
        continue;
      }
      if (atom.legacyKinsoku) {
        continue;
      }
      adjustable.add(index);
    }

    if (adjustable.isEmpty) {
      return const <int, double>{};
    }

    final addition = slack / adjustable.length;
    return <int, double>{for (final index in adjustable) index: addition};
  }

  Map<int, double> _mergeBoundaryAdjustments(
    Map<int, double> base,
    Map<int, double> extra,
  ) {
    if (base.isEmpty) {
      return extra;
    }
    if (extra.isEmpty) {
      return base;
    }
    final merged = <int, double>{...base};
    for (final entry in extra.entries) {
      merged.update(
        entry.key,
        (current) => current + entry.value,
        ifAbsent: () => entry.value,
      );
    }
    return merged;
  }

  Map<int, _FragmentPlacement> _buildAtomPlacements(
    List<_Atom> atoms,
    _TakenLineDraft draft,
    _BlockContext context, {
    required Map<int, double> boundaryAdjustments,
  }) {
    final atomPlacements = <int, _FragmentPlacement>{};
    final contentShift = context.alignToFarEdge
        ? math.max(context.resolvedLineExtent - draft.textExtent, 0).toDouble()
        : draft.indent;
    var blockCursor = contentShift;

    for (var index = draft.start; index < draft.end; index += 1) {
      final atom = atoms[index];
      if (atom.kind == _AtomKind.lineBreak) {
        continue;
      }
      if (index == draft.start &&
          draft.start > 0 &&
          atom.kind == _AtomKind.text &&
          _openingBrackets.contains(atom.text)) {
        blockCursor -= atom.inlineExtent / 2;
      }
      blockCursor += boundaryAdjustments[index] ?? 0;
      if (atom.kind.isMarkerOnly) {
        atomPlacements[index] = _FragmentPlacement(
          blockOffset: blockCursor,
          blockExtent: 0,
          inlineExtent: context.crossExtent,
          style: atom.style,
        );
        continue;
      }
      atomPlacements[index] = _FragmentPlacement(
        blockOffset: blockCursor,
        blockExtent: atom.blockExtent,
        inlineExtent: atom.inlineExtent,
        style: atom.style,
      );
      blockCursor += atom.blockExtent;
    }

    return atomPlacements;
  }

  _RubyBaseTrackingAdjustments _resolveRubyBaseTrackingAdjustments(
    _ParagraphModel model,
    Map<int, _FragmentPlacement> placements,
    int lineStart,
    int lineEnd,
  ) {
    final boundaryAdjustments = <int, double>{};
    var trailingExtent = 0.0;

    for (final ruby in model.rubies) {
      final segmentStart = math.max(ruby.start, lineStart);
      final segmentEnd = math.min(ruby.end, lineEnd);
      if (segmentEnd <= segmentStart) {
        continue;
      }
      final baseAtoms = <int>[
        for (var index = segmentStart; index < segmentEnd; index += 1)
          if (placements[index] case final _?) index,
      ];
      if (baseAtoms.isEmpty) {
        continue;
      }
      final first = placements[baseAtoms.first]!;
      final last = placements[baseAtoms.last]!;
      final baseExtent =
          (last.blockOffset + last.blockExtent) - first.blockOffset;
      final segmentText = _sliceRubyTextForLine(ruby, lineStart, lineEnd);
      if (segmentText.isEmpty) {
        continue;
      }
      final rubyExtent = _rubyTextExtent(
        segmentText,
        _rubyInterCharacterSpacing(segmentText, math.max(baseExtent, 0)),
      );
      if (rubyExtent <= baseExtent) {
        continue;
      }

      var overflow = rubyExtent - baseExtent;
      final previousIndex = _previousVisibleAtomCursor(
        model.atoms,
        baseAtoms.first - 1,
      );
      if (previousIndex >= 0 &&
          !_cjkIdeographPattern.hasMatch(model.atoms[previousIndex].text)) {
        overflow -= constraints.baseFontSize / 2;
      }
      final nextIndex = _nextVisibleAtomCursor(model.atoms, baseAtoms.last + 1);
      if (nextIndex >= 0 &&
          !_cjkIdeographPattern.hasMatch(model.atoms[nextIndex].text)) {
        overflow -= constraints.baseFontSize / 2;
      }
      if (overflow <= 0) {
        continue;
      }

      final tracking = overflow / baseAtoms.length;
      for (final atomIndex in baseAtoms) {
        boundaryAdjustments.update(
          atomIndex,
          (current) => current + tracking,
          ifAbsent: () => tracking,
        );
      }
    }

    return _RubyBaseTrackingAdjustments(
      boundaryAdjustments: boundaryAdjustments,
      trailingExtent: 0,
    );
  }

  LayoutFragment? _buildFragment(
    _Atom atom,
    _FragmentPlacement placement,
    double lineInlineOffset,
  ) {
    final legacyTcyBlockOffset =
        atom.style.directionKind == DirectionKind.tateChuYoko
        ? 0.05 * atom.style.fontScale
        : 0.0;
    return switch (atom.kind) {
      _AtomKind.text => LayoutTextFragment(
        span: atom.span,
        inlineOffset: lineInlineOffset,
        blockOffset: placement.blockOffset + legacyTcyBlockOffset,
        inlineExtent: placement.inlineExtent,
        blockExtent: placement.blockExtent,
        style: atom.style,
        text: atom.text,
        issues: atom.issues,
      ),
      _AtomKind.gaiji => LayoutGaijiFragment(
        span: atom.span,
        inlineOffset: lineInlineOffset,
        blockOffset: placement.blockOffset,
        inlineExtent: placement.inlineExtent,
        blockExtent: placement.blockExtent,
        style: atom.style,
        displayText: atom.text,
        rawNotation: atom.rawNotation ?? atom.text,
        description: atom.description ?? atom.text,
        resolved: atom.resolved,
        jisCode: atom.jisCode,
        unicodeCodePoint: atom.unicodeCodePoint,
        issues: atom.issues,
      ),
      _AtomKind.image => LayoutImageFragment(
        span: atom.span,
        inlineOffset: lineInlineOffset,
        blockOffset: placement.blockOffset,
        inlineExtent: placement.inlineExtent,
        blockExtent: placement.blockExtent,
        style: atom.style,
        source: atom.text,
        alt: atom.alt,
        className: atom.className,
        width: atom.imageWidth,
        height: atom.imageHeight,
        attributes: atom.attributes,
        issues: atom.issues,
      ),
      _AtomKind.note => LayoutNoteFragment(
        span: atom.span,
        inlineOffset: lineInlineOffset,
        blockOffset: placement.blockOffset,
        inlineExtent: placement.inlineExtent,
        blockExtent: placement.blockExtent,
        style: atom.style,
        noteKind: atom.noteKind!,
        text: atom.text,
        upperText: _splitWarichuText(atom.text).$1,
        lowerText: _splitWarichuText(atom.text).$2,
        issues: atom.issues,
      ),
      _AtomKind.unsupported => LayoutUnsupportedFragment(
        span: atom.span,
        inlineOffset: lineInlineOffset,
        blockOffset: placement.blockOffset,
        inlineExtent: placement.inlineExtent,
        blockExtent: placement.blockExtent,
        style: atom.style,
        directive: atom.directive!,
        issues: atom.issues,
      ),
      _ => null,
    };
  }

  List<LayoutRubyPlacement> _buildRubiesForLine(
    _ParagraphModel model,
    Map<int, _FragmentPlacement> placements,
    int lineStart,
    int lineEnd,
    double lineInlineOffset,
    _BlockContext context, {
    required Map<int, double> boundaryAdjustments,
  }) {
    final rubies = <LayoutRubyPlacement>[];
    final rubyBottomByKind = <String, double>{};
    for (final ruby in model.rubies) {
      final segmentStart = math.max(ruby.start, lineStart);
      final segmentEnd = math.min(ruby.end, lineEnd);
      if (segmentEnd <= segmentStart) {
        continue;
      }
      var baseAtoms = <int>[
        for (var index = segmentStart; index < segmentEnd; index += 1)
          if (placements[index] != null) index,
      ];
      if (baseAtoms.isEmpty) {
        continue;
      }
      var trimmedLeadingHiraganaForGaiji = false;
      if (baseAtoms.length >= 2 && ruby.kind == RubyKind.phonetic) {
        final firstAtom = model.atoms[baseAtoms.first];
        final secondAtom = model.atoms[baseAtoms[1]];
        final firstIsHiraganaText =
            firstAtom.kind == _AtomKind.text &&
            firstAtom.text.runes.length == 1 &&
            _hiraganaPattern.hasMatch(firstAtom.text);
        final secondIsGaiji =
            secondAtom.kind == _AtomKind.gaiji ||
            secondAtom.kind == _AtomKind.unsupported;
        if (firstIsHiraganaText && secondIsGaiji) {
          baseAtoms = baseAtoms.sublist(1);
          trimmedLeadingHiraganaForGaiji = true;
        }
      }
      final first = placements[baseAtoms.first]!;
      final last = placements[baseAtoms.last]!;
      final segmentStartsRuby = segmentStart == ruby.start;
      final blockStart = first.blockOffset;
      final blockEnd = last.blockOffset + last.blockExtent;
      final segmentText = _sliceRubyTextForLine(ruby, lineStart, lineEnd);
      if (segmentText.isEmpty) {
        continue;
      }
      final segmentCharacters = _splitCharacters(segmentText);
      final unjustifiedBaseExtent = baseAtoms.fold<double>(
        0.0,
        (sum, index) => sum + placements[index]!.blockExtent,
      );
      final interCharacterSpacing = _rubyInterCharacterSpacing(
        segmentText,
        unjustifiedBaseExtent,
      );
      final rubyBlockExtent = _rubyTextExtent(
        segmentText,
        interCharacterSpacing,
      );
      final baseExtent = math.max(blockEnd - blockStart, 0);
      var edgePadding = _legacyRubyEdgePadding(model, ruby);
      if (trimmedLeadingHiraganaForGaiji) {
        edgePadding = (startPadding: 0.0, endPadding: 0.0);
      }
      final inlineExtent = math.max(
        context.crossExtent * constraints.rubyScale,
        constraints.baseFontSize * constraints.rubyScale,
      );
      var rubyBlockOffset = blockStart + (baseExtent - rubyBlockExtent) / 2;
      if (!segmentStartsRuby &&
          segmentCharacters.length == 1 &&
          blockStart == 0) {
        rubyBlockOffset += constraints.baseFontSize / 4;
      } else if (segmentStartsRuby &&
          segmentStart == lineStart &&
          baseAtoms.length == 1 &&
          segmentCharacters.length > 1 &&
          blockStart > 0) {
        rubyBlockOffset -= blockStart;
      }
      final rubyKindKey = '${ruby.kind.name}:${ruby.position.name}';
      final previousBottom = rubyBottomByKind[rubyKindKey] ?? 0;
      if (segmentStartsRuby && rubyBlockExtent > baseExtent) {
        final startWithoutTrailing = first.blockOffset;
        if (edgePadding.startPadding == 0 && edgePadding.endPadding > 0) {
          rubyBlockOffset = math.max(
            rubyBlockOffset,
            math.max(startWithoutTrailing, previousBottom),
          );
        } else if (edgePadding.startPadding > 0 &&
            edgePadding.endPadding == 0) {
          rubyBlockOffset = startWithoutTrailing - edgePadding.startPadding;
        }
      }
      rubyBottomByKind[rubyKindKey] = math.max(
        previousBottom,
        rubyBlockOffset + rubyBlockExtent,
      );
      rubies.add(
        LayoutRubyPlacement(
          span: ruby.span,
          text: segmentText,
          kind: ruby.kind,
          position: ruby.position,
          lineInlineOffset: lineInlineOffset,
          crossOffset: _crossOffsetForRuby(
            ruby.position,
            inlineExtent,
            context,
          ),
          blockOffset: rubyBlockOffset,
          blockExtent: rubyBlockExtent,
          inlineExtent: inlineExtent,
          interCharacterSpacing: interCharacterSpacing,
          issues: ruby.issues,
        ),
      );
    }
    return rubies;
  }

  List<LayoutMarker> _buildRangeMarkersForLine(
    _ParagraphModel model,
    Map<int, _FragmentPlacement> placements,
    int lineStart,
    int lineEnd,
    double lineInlineOffset,
    _BlockContext context, {
    required Map<int, double> boundaryAdjustments,
  }) {
    final markers = <LayoutMarker>[];
    for (final marker in model.rangeMarkers) {
      final segmentStart = math.max(marker.start, lineStart);
      final segmentEnd = math.min(marker.end, lineEnd);
      if (segmentEnd <= segmentStart) {
        continue;
      }
      final anchored = <int>[
        for (var index = segmentStart; index < segmentEnd; index += 1)
          if (placements[index] case final _?) index,
      ];
      if (anchored.isEmpty) {
        continue;
      }
      if (marker.kind == LayoutMarkerKind.emphasis) {
        for (final atomIndex in anchored) {
          final placement = placements[atomIndex]!;
          markers.add(
            LayoutMarker(
              kind: marker.kind,
              span: marker.span,
              lineInlineOffset: lineInlineOffset,
              crossOffset: _crossOffsetForMarker(marker, context),
              blockOffset:
                  placement.blockOffset - (boundaryAdjustments[atomIndex] ?? 0),
              blockExtent: placement.blockExtent,
              inlineExtent: _markerInlineExtent(marker, context),
              emphasisMark: marker.emphasisMark,
              emphasisSide: marker.emphasisSide,
              decorationKind: marker.decorationKind,
              decorationSide: marker.decorationSide,
              noteKind: marker.noteKind,
              frameKind: marker.frameKind,
              repeatCount: 1,
              issues: marker.issues,
            ),
          );
        }
        continue;
      }
      final first = placements[anchored.first]!;
      final last = placements[anchored.last]!;
      markers.add(
        LayoutMarker(
          kind: marker.kind,
          span: marker.span,
          lineInlineOffset: lineInlineOffset,
          crossOffset: _crossOffsetForMarker(marker, context),
          blockOffset: first.blockOffset,
          blockExtent:
              (last.blockOffset + last.blockExtent) - first.blockOffset,
          inlineExtent: _markerInlineExtent(marker, context),
          emphasisMark: marker.emphasisMark,
          emphasisSide: marker.emphasisSide,
          decorationKind: marker.decorationKind,
          decorationSide: marker.decorationSide,
          noteKind: marker.noteKind,
          frameKind: marker.frameKind,
          repeatCount: null,
          issues: marker.issues,
        ),
      );
    }
    return markers;
  }

  List<LayoutMarker> _buildPointMarkersForLine(
    _ParagraphModel model,
    Map<int, _FragmentPlacement> placements,
    int lineStart,
    int lineEnd,
    double lineInlineOffset,
    _BlockContext context,
  ) {
    final markers = <LayoutMarker>[];
    for (final marker in model.pointMarkers) {
      if (marker.atomIndex < lineStart || marker.atomIndex >= lineEnd) {
        continue;
      }
      final placement =
          placements[marker.atomIndex] ??
          _nearestPlacement(placements, marker.atomIndex);
      if (placement == null) {
        continue;
      }
      markers.add(
        LayoutMarker(
          kind: marker.kind,
          span: marker.span,
          lineInlineOffset: lineInlineOffset,
          crossOffset: -_markerInlineExtent(marker, context),
          blockOffset: placement.blockOffset,
          blockExtent: math.max(
            placement.blockExtent,
            constraints.baseFontSize,
          ),
          inlineExtent: _markerInlineExtent(marker, context),
          text: marker.text,
          noteKind: marker.noteKind,
          issues: marker.issues,
        ),
      );
    }
    return markers;
  }

  List<LayoutMarker> _frameMarkersForLine(
    _ParagraphModel model,
    Map<int, _FragmentPlacement> placements,
    int lineStart,
    int lineEnd,
    double lineInlineOffset,
    _BlockContext context,
  ) {
    if (context.frameKind == null) {
      return const <LayoutMarker>[];
    }
    final placementsInLine = <_FragmentPlacement>[];
    for (var index = lineStart; index < lineEnd; index += 1) {
      final placement = placements[index];
      if (placement != null) {
        placementsInLine.add(placement);
      }
    }
    if (placementsInLine.isEmpty) {
      return _frameMarkersForEmptyLine(
        model.span,
        context,
        lineInlineOffset,
        context.resolvedLineExtent,
      );
    }
    final start = placementsInLine.first.blockOffset;
    final end =
        placementsInLine.last.blockOffset + placementsInLine.last.blockExtent;
    return <LayoutMarker>[
      LayoutMarker(
        kind: LayoutMarkerKind.frame,
        span: model.span,
        lineInlineOffset: lineInlineOffset,
        crossOffset: 0,
        blockOffset: start,
        blockExtent: end - start,
        inlineExtent: context.crossExtent,
        frameKind: context.frameKind,
      ),
    ];
  }

  List<LayoutMarker> _frameMarkersForEmptyLine(
    SourceSpan span,
    _BlockContext context,
    double lineInlineOffset,
    double lineExtent,
  ) {
    if (context.frameKind == null) {
      return const <LayoutMarker>[];
    }
    return <LayoutMarker>[
      LayoutMarker(
        kind: LayoutMarkerKind.frame,
        span: span,
        lineInlineOffset: lineInlineOffset,
        crossOffset: 0,
        blockOffset: 0,
        blockExtent: lineExtent,
        inlineExtent: context.crossExtent,
        frameKind: context.frameKind,
      ),
    ];
  }

  List<LayoutHitRegion> _buildLinkHitRegionsForLine(
    _ParagraphModel model,
    Map<int, _FragmentPlacement> placements,
    int lineStart,
    int lineEnd,
    double lineInlineOffset,
  ) {
    final regions = <LayoutHitRegion>[];
    for (final link in model.links) {
      final segmentStart = math.max(link.start, lineStart);
      final segmentEnd = math.min(link.end, lineEnd);
      if (segmentEnd <= segmentStart) {
        continue;
      }
      final anchored = <int>[
        for (var index = segmentStart; index < segmentEnd; index += 1)
          if (placements[index] case final _?) index,
      ];
      if (anchored.isEmpty) {
        continue;
      }
      final first = placements[anchored.first]!;
      final last = placements[anchored.last]!;
      regions.add(
        LayoutHitRegion(
          kind: LayoutHitRegionKind.link,
          span: link.span,
          inlineOffset: lineInlineOffset,
          blockOffset: first.blockOffset,
          inlineExtent: first.inlineExtent,
          blockExtent:
              (last.blockOffset + last.blockExtent) - first.blockOffset,
          data: link.target,
        ),
      );
    }
    return regions;
  }

  List<LayoutHitRegion> _buildAnchorHitRegionsForLine(
    _ParagraphModel model,
    Map<int, _FragmentPlacement> placements,
    int lineStart,
    int lineEnd,
    double lineInlineOffset,
  ) {
    final regions = <LayoutHitRegion>[];
    for (final anchor in model.anchors) {
      if (anchor.atomIndex < lineStart || anchor.atomIndex >= lineEnd) {
        continue;
      }
      final placement =
          placements[anchor.atomIndex] ??
          _nearestPlacement(placements, anchor.atomIndex);
      if (placement == null) {
        continue;
      }
      regions.add(
        LayoutHitRegion(
          kind: LayoutHitRegionKind.anchor,
          span: anchor.span,
          inlineOffset: lineInlineOffset,
          blockOffset: placement.blockOffset,
          inlineExtent: 0,
          blockExtent: placement.blockExtent,
          data: anchor.name,
        ),
      );
    }
    return regions;
  }

  _FragmentPlacement? _nearestPlacement(
    Map<int, _FragmentPlacement> placements,
    int atomIndex,
  ) {
    for (var index = atomIndex; index >= 0; index -= 1) {
      final placement = placements[index];
      if (placement != null) {
        return placement;
      }
    }
    for (var index = atomIndex + 1; index <= placements.length; index += 1) {
      final placement = placements[index];
      if (placement != null) {
        return placement;
      }
    }
    return null;
  }

  void _emitInlines(
    List<LayoutInline> nodes,
    _ParagraphModel model,
    _InlineContext context,
  ) {
    for (final node in nodes) {
      switch (node) {
        case LayoutTextInline():
          _emitTextInline(node, model, context);
        case LayoutGaijiInline():
          final resolved = _gaijiResolver.resolve(
            description: node.description,
            jisCode: node.jisCode,
            unicodeCodePoint: node.unicodeCodePoint,
          );
          model.atoms.add(
            _Atom.gaiji(
              span: node.span,
              text: resolved.text,
              style: context.publicStyle,
              blockExtent: context.fontScale,
              inlineExtent: context.fontScale,
              rawNotation: node.rawNotation,
              description: node.description,
              resolved: resolved.resolved,
              jisCode: node.jisCode,
              unicodeCodePoint: node.unicodeCodePoint,
              issues: node.issues,
            ),
          );
        case LayoutUnresolvedGaijiInline():
          model.atoms.add(
            _Atom.gaiji(
              span: node.span,
              text: _fallbackGaiji,
              style: context.publicStyle,
              blockExtent: context.fontScale,
              inlineExtent: context.fontScale,
              rawNotation: node.rawNotation,
              description: node.text,
              resolved: false,
              issues: node.issues,
            ),
          );
        case LayoutImageInline():
          final blockExtent = _resolveImageBlockExtent(node, context);
          final inlineExtent = _resolveImageInlineExtent(node, context);
          model.atoms.add(
            _Atom.image(
              span: node.span,
              text: node.source,
              style: context.publicStyle,
              blockExtent: blockExtent,
              inlineExtent: inlineExtent,
              alt: node.alt,
              className: node.className,
              imageWidth: node.width,
              imageHeight: node.height,
              attributes: node.attributes,
              issues: node.issues,
            ),
          );
        case LayoutLinkInline():
          _wrapLinkRange(
            model,
            node.span,
            node.target,
            () => _emitInlines(node.children, model, context),
            node.issues,
          );
        case LayoutAnchorInline():
          model.atoms.add(
            _Atom.marker(
              span: node.span,
              style: context.publicStyle,
              issues: node.issues,
            ),
          );
          model.anchors.add(
            _AnchorPoint(
              span: node.span,
              atomIndex: model.atoms.length - 1,
              name: node.name,
              issues: node.issues,
            ),
          );
        case LayoutRubyInline():
          final start = model.atoms.length;
          _emitInlines(node.base, model, context);
          final end = model.atoms.length;
          if (end > start) {
            model.rubies.add(
              _RubyRange(
                span: node.span,
                start: start,
                end: end,
                text: node.text,
                kind: node.kind,
                position: node.position,
                issues: node.issues,
              ),
            );
          }
        case LayoutDirectionInline():
          _emitTateChuYoko(node, model, context);
        case LayoutFlowInline():
          _emitInlines(node.children, model, context.withFlow(node.kind));
        case LayoutCaptionInline():
          _emitInlines(node.children, model, context.withCaption());
        case LayoutFrameInline():
          _wrapRangeMarker(
            model,
            node.span,
            () => _emitInlines(
              node.children,
              model,
              context.withFrame(node.kind, node.borderWidth),
            ),
            _RangeMarker.frame(node.span, node.kind, node.issues),
          );
        case LayoutNoteInline():
          final text = _plainTextOf(node.children);
          final placeholder = text.isEmpty ? ' ' : '$_noteOpen$text$_noteClose';
          final scale = context.fontScale * constraints.noteScale;
          final extent = math.max(
            scale *
                math.max(_splitCharacters(placeholder).length.toDouble(), 1),
            context.fontScale,
          );
          model.atoms.add(
            _Atom.note(
              span: node.span,
              text: text,
              style: context.publicStyle,
              blockExtent: math.max(extent / 2, context.fontScale),
              inlineExtent: context.fontScale,
              noteKind: node.kind,
              issues: node.issues,
            ),
          );
          model.pointMarkers.add(
            _PointMarker.note(
              span: node.span,
              atomIndex: model.atoms.length - 1,
              noteKind: node.kind,
              text: text,
              issues: node.issues,
            ),
          );
        case LayoutStyledInline():
          _emitInlines(node.children, model, context.withTextStyle(node.style));
        case LayoutFontSizeInline():
          _emitInlines(
            node.children,
            model,
            context.withFontSize(node.kind, node.steps),
          );
        case LayoutHeadingInline():
          _emitInlines(
            node.children,
            model,
            context.withHeading(node.level, node.display),
          );
        case LayoutEmphasisInline():
          _wrapRangeMarker(
            model,
            node.span,
            () => _emitInlines(node.children, model, context),
            _RangeMarker.emphasis(node.span, node.mark, node.side, node.issues),
          );
        case LayoutDecorationInline():
          _wrapRangeMarker(
            model,
            node.span,
            () => _emitInlines(node.children, model, context),
            _RangeMarker.decoration(
              node.span,
              node.kind,
              node.side,
              node.issues,
            ),
          );
        case LayoutScriptInline():
          model.atoms.add(
            _Atom.text(
              span: node.span,
              text: node.text,
              style: context.withScript(node.kind).publicStyle,
              blockExtent: math.max(
                context.fontScale * constraints.scriptScale,
                0.5,
              ),
              inlineExtent: math.max(
                context.fontScale * constraints.scriptScale,
                0.5,
              ),
              issues: node.issues,
            ),
          );
        case LayoutKaeritenInline():
          model.atoms.add(
            _Atom.marker(
              span: node.span,
              style: context.publicStyle,
              issues: node.issues,
            ),
          );
          model.pointMarkers.add(
            _PointMarker.kaeriten(
              span: node.span,
              atomIndex: model.atoms.length - 1,
              text: node.text,
              issues: node.issues,
            ),
          );
        case LayoutOkuriganaInline():
          model.atoms.add(
            _Atom.marker(
              span: node.span,
              style: context.publicStyle,
              issues: node.issues,
            ),
          );
          model.pointMarkers.add(
            _PointMarker.okurigana(
              span: node.span,
              atomIndex: model.atoms.length - 1,
              text: node.text,
              issues: node.issues,
            ),
          );
        case LayoutEditorNoteInline():
          model.atoms.add(
            _Atom.marker(
              span: node.span,
              style: context.publicStyle,
              issues: node.issues,
            ),
          );
          model.pointMarkers.add(
            _PointMarker.editorNote(
              span: node.span,
              atomIndex: model.atoms.length - 1,
              text: node.text,
              issues: node.issues,
            ),
          );
        case LayoutLineBreakInline():
          model.atoms.add(
            _Atom.lineBreak(
              span: node.span,
              style: context.publicStyle,
              issues: node.issues,
            ),
          );
        case LayoutUnsupportedInline():
          model.atoms.add(
            _Atom.unsupported(
              span: node.span,
              style: context.publicStyle,
              directive: node.directive,
              issues: node.issues,
            ),
          );
          model.pointMarkers.add(
            _PointMarker.unsupported(
              span: node.span,
              atomIndex: model.atoms.length - 1,
              text: node.directive.rawText,
              issues: node.issues,
            ),
          );
      }
    }
  }

  void _emitTateChuYoko(
    LayoutDirectionInline node,
    _ParagraphModel model,
    _InlineContext context,
  ) {
    final text = _plainTextOf(node.children);
    if (text.isEmpty) {
      return;
    }
    final scale = context.fontScale;
    model.atoms.add(
      _Atom.text(
        span: node.span,
        text: text,
        style: context.withDirection(node.kind).publicStyle,
        blockExtent: scale,
        inlineExtent: scale,
        issues: node.issues,
      ),
    );
  }

  void _emitTextInline(
    LayoutTextInline node,
    _ParagraphModel model,
    _InlineContext context,
  ) {
    final normalizedText = _normalizeLegacyText(node.text, context);
    final characters = _splitCharacters(normalizedText);
    if (characters.isEmpty) {
      return;
    }

    if (context.flowKind == FlowKind.yokogumi) {
      _emitSidewaysRun(normalizedText, node, model, context);
      return;
    }

    final plainBuffer = StringBuffer();
    final sidewaysBuffer = StringBuffer();

    void flushPlain() {
      final text = plainBuffer.toString();
      if (text.isEmpty) {
        return;
      }
      final plainChars = _splitCharacters(text);
      for (var index = 0; index < plainChars.length; index += 1) {
        final char = plainChars[index];
        model.atoms.add(
          _Atom.text(
            span: node.span,
            text: char,
            style: context.publicStyle,
            blockExtent: _resolveTextBlockExtent(
              char,
              nextText: index + 1 < plainChars.length
                  ? plainChars[index + 1]
                  : null,
              context: context,
            ),
            inlineExtent: context.fontScale,
            issues: node.issues,
          ),
        );
      }
      plainBuffer.clear();
    }

    void flushSideways() {
      final text = sidewaysBuffer.toString();
      if (text.isEmpty) {
        return;
      }
      if (_containsLatinLetter(text)) {
        _emitSidewaysRun(text, node, model, context);
      } else {
        final chars = _splitCharacters(text);
        for (var index = 0; index < chars.length; index += 1) {
          final char = chars[index];
          model.atoms.add(
            _Atom.text(
              span: node.span,
              text: char,
              style: context.publicStyle,
              blockExtent: _resolveTextBlockExtent(
                char,
                nextText: index + 1 < chars.length ? chars[index + 1] : null,
                context: context,
              ),
              inlineExtent: context.fontScale,
              issues: node.issues,
            ),
          );
        }
      }
      sidewaysBuffer.clear();
    }

    for (final character in characters) {
      if (_isSidewaysCharacter(character)) {
        flushPlain();
        sidewaysBuffer.write(character);
      } else {
        flushSideways();
        plainBuffer.write(character);
      }
    }

    flushPlain();
    flushSideways();
  }

  String _normalizeLegacyText(String text, _InlineContext context) {
    var normalized = text;
    if (context.flowKind == FlowKind.yokogumi) {
      return normalized
          .replaceAll('／＼', '／$_wordJoiner＼')
          .replaceAll('／″＼', '／$_wordJoiner"$_wordJoiner＼');
    }
    normalized = normalized.replaceAll('／＼', '〳〵').replaceAll('／″＼', '〴〵');
    return normalized.replaceAll('“', '〝').replaceAll('”', '〟');
  }

  void _emitSidewaysTextAtoms(
    LayoutTextInline node,
    _ParagraphModel model,
    _InlineContext context,
  ) {
    _emitSidewaysRun(node.text, node, model, context);
  }

  void _emitSidewaysRun(
    String text,
    LayoutTextInline node,
    _ParagraphModel model,
    _InlineContext context,
  ) {
    if (node.text.isEmpty) {
      return;
    }

    var remaining = text;
    while (remaining.startsWith(' ')) {
      model.atoms.add(
        _legacyDraftToAtom(
          const _LegacyAtomDraft(' '),
          context,
          node.span,
          node.issues,
        ),
      );
      remaining = remaining.substring(1);
    }
    if (remaining.isEmpty) {
      return;
    }

    final breaker = UnicodeLineBreaker(remaining);
    var segmentStart = 0;

    while (true) {
      final breakpoint = breaker.nextBreak();
      if (breakpoint == null) {
        break;
      }
      final segment = remaining.substring(segmentStart, breakpoint.position);
      if (segment.isNotEmpty) {
        model.atoms.add(
          _legacyDraftToAtom(
            _LegacyAtomDraft(segment),
            context,
            node.span,
            node.issues,
          ),
        );
      }
      segmentStart = breakpoint.position;
    }
  }

  _Atom _legacyDraftToAtom(
    _LegacyAtomDraft draft,
    _InlineContext context,
    SourceSpan span,
    List<LayoutIssue> issues,
  ) {
    final nextText = draft.text.runes.length == 1 ? null : null;
    final blockExtent = _isSidewaysAtomText(draft.text)
        ? _measureSidewaysTextExtent(draft.text, context)
        : _resolveTextBlockExtent(
            draft.text,
            nextText: nextText,
            context: context,
          );
    return _Atom.text(
      span: span,
      text: draft.text,
      style: context.publicStyle,
      blockExtent: blockExtent,
      inlineExtent: context.fontScale,
      issues: issues,
    );
  }

  void _applyLegacyKinsoku(List<_Atom> atoms) {
    final visible = <({int atomIndex, int offset, String text})>[];
    var offset = 0;
    for (var index = 0; index < atoms.length; index += 1) {
      final breakText = atoms[index].breakText;
      if (breakText.isEmpty) {
        continue;
      }
      visible.add((atomIndex: index, offset: offset, text: breakText));
      offset += breakText.length;
    }
    if (visible.isEmpty) {
      return;
    }

    final joined = visible.map((entry) => entry.text).join();
    final breaks = <int>{};
    final breaker = UnicodeLineBreaker(joined);
    while (true) {
      final next = breaker.nextBreak();
      if (next == null) {
        break;
      }
      breaks.add(next.position);
    }

    var segmentStart = 0;
    var previousAllowed = true;
    var previousJoin = false;
    String? previousText;
    for (final entry in visible) {
      if (entry.offset != 0 && breaks.contains(entry.offset)) {
        segmentStart = entry.offset;
      }
      final atom = atoms[entry.atomIndex];
      if (atom.style.directionKind == DirectionKind.tateChuYoko) {
        atoms[entry.atomIndex] = atom.copyWith(legacyKinsoku: false);
        previousAllowed = true;
        previousJoin = false;
        continue;
      }
      final text = entry.text;
      final firstChar = String.fromCharCode(text.runes.first);
      final characterType = getUtr50Type(firstChar.runes.firstOrNull);
      final isOpening = _openingBrackets.contains(firstChar);
      final isRotated = _legacyRotatedAtomTypes.contains(firstChar);
      final allowsBreak =
          characterType != 'R' ||
          isOpening ||
          isRotated ||
          _legacySidewaysCloseGlyphs.contains(firstChar);
      final startsAtom = previousAllowed || allowsBreak;
      final latinAfterSpace =
          previousText == ' ' && _containsLatinLetter(text);
      final legacyKinsoku = latinAfterSpace
          ? false
          : startsAtom
          ? previousJoin ||
                (entry.offset != segmentStart && !isOpening && !isRotated)
          : true;
      atoms[entry.atomIndex] = atoms[entry.atomIndex].copyWith(
        legacyKinsoku: legacyKinsoku,
      );
      previousAllowed = allowsBreak;
      previousJoin = text.endsWith('⁠');
      previousText = text;
    }
  }

  void _wrapRangeMarker(
    _ParagraphModel model,
    SourceSpan span,
    void Function() emit,
    _RangeMarker marker,
  ) {
    final start = model.atoms.length;
    emit();
    final end = model.atoms.length;
    if (end > start) {
      model.rangeMarkers.add(marker.withRange(start, end));
    }
  }

  void _wrapLinkRange(
    _ParagraphModel model,
    SourceSpan span,
    String target,
    void Function() emit,
    List<LayoutIssue> issues,
  ) {
    final start = model.atoms.length;
    emit();
    final end = model.atoms.length;
    if (end > start) {
      model.links.add(
        _LinkRange(
          span: span,
          start: start,
          end: end,
          target: target,
          issues: issues,
        ),
      );
    }
  }

  String _resolvedGaijiText(LayoutGaijiInline node) {
    return _gaijiResolver
        .resolve(
          description: node.description,
          jisCode: node.jisCode,
          unicodeCodePoint: node.unicodeCodePoint,
        )
        .text;
  }

  double _resolveImageBlockExtent(
    LayoutImageInline node,
    _InlineContext context,
  ) {
    final height = node.height?.toDouble();
    final width = node.width?.toDouble();
    if (height != null && height > 0) {
      return height / 10;
    }
    if (width != null && width > 0) {
      return width / 10;
    }
    return context.fontScale;
  }

  double _resolveImageInlineExtent(
    LayoutImageInline node,
    _InlineContext context,
  ) {
    final width = node.width?.toDouble();
    final height = node.height?.toDouble();
    if (width != null && width > 0) {
      return width / 10;
    }
    if (height != null && height > 0) {
      return math.max(height / 10, context.fontScale);
    }
    return context.fontScale;
  }

  String _plainTextOf(List<LayoutInline> nodes) {
    final buffer = StringBuffer();
    void visit(LayoutInline node) {
      switch (node) {
        case LayoutTextInline():
          buffer.write(node.text);
        case LayoutGaijiInline():
          buffer.write(_resolvedGaijiText(node));
        case LayoutUnresolvedGaijiInline():
          buffer.write(_fallbackGaiji);
        case LayoutImageInline():
          buffer.write('￼');
        case LayoutLinkInline():
          for (final child in node.children) {
            visit(child);
          }
        case LayoutAnchorInline():
          break;
        case LayoutRubyInline():
          for (final child in node.base) {
            visit(child);
          }
        case LayoutDirectionInline():
        case LayoutFlowInline():
        case LayoutCaptionInline():
        case LayoutFrameInline():
        case LayoutNoteInline():
        case LayoutStyledInline():
        case LayoutFontSizeInline():
        case LayoutHeadingInline():
        case LayoutEmphasisInline():
        case LayoutDecorationInline():
          final children = switch (node) {
            LayoutDirectionInline() => node.children,
            LayoutFlowInline() => node.children,
            LayoutCaptionInline() => node.children,
            LayoutFrameInline() => node.children,
            LayoutNoteInline() => node.children,
            LayoutStyledInline() => node.children,
            LayoutFontSizeInline() => node.children,
            LayoutHeadingInline() => node.children,
            LayoutEmphasisInline() => node.children,
            LayoutDecorationInline() => node.children,
            _ => const <LayoutInline>[],
          };
          for (final child in children) {
            visit(child);
          }
        case LayoutScriptInline():
          buffer.write(node.text);
        case LayoutKaeritenInline():
          buffer.write(node.text);
        case LayoutOkuriganaInline():
          buffer.write(node.text);
        case LayoutEditorNoteInline():
          buffer.write(node.text);
        case LayoutLineBreakInline():
          buffer.write('\n');
        case LayoutUnsupportedInline():
      }
    }

    for (final node in nodes) {
      visit(node);
    }
    return buffer.toString();
  }

  (String?, String?) _splitWarichuText(String text) {
    if (text.isEmpty) {
      return (null, null);
    }
    final explicitLines = text.split('\n');
    if (explicitLines.length >= 2) {
      return (
        explicitLines.first.trim().isEmpty ? null : explicitLines.first.trim(),
        explicitLines.skip(1).join(' ').trim().isEmpty
            ? null
            : explicitLines.skip(1).join(' ').trim(),
      );
    }
    final characters = _splitCharacters(text);
    if (characters.length <= 1) {
      return (text, null);
    }
    final midpoint = (characters.length / 2).ceil();
    return (characters.take(midpoint).join(), characters.skip(midpoint).join());
  }

  List<String> _splitCharacters(String text) {
    return text.runes.map(String.fromCharCode).toList(growable: false);
  }

  double _resolveTextBlockExtent(
    String text, {
    required String? nextText,
    required _InlineContext context,
  }) {
    if (text.runes.length > 1) {
      return _isSidewaysAtomText(text)
          ? _measureSidewaysTextExtent(text, context)
          : context.fontScale * text.runes.length;
    }
    if (_zeroExtentGlyphs.contains(text)) {
      return 0;
    }

    if (_closingBrackets.contains(text) &&
        nextText != null &&
        _halfWidthNextToClosing.contains(nextText)) {
      return context.fontScale / 2;
    }

    if (_halfWidthNextToOpening.contains(text) &&
        nextText != null &&
        _openingBrackets.contains(nextText)) {
      return context.fontScale / 2;
    }

    if (_punctuationMarks.contains(text) &&
        nextText != null &&
        '$_openingBrackets$_closingBrackets'.contains(nextText)) {
      return context.fontScale / 2;
    }

    return context.fontScale;
  }

  bool _isSidewaysAtomText(String text) {
    if (text.isEmpty) {
      return false;
    }
    var sawSideways = false;
    for (final character in _splitCharacters(text)) {
      if (character == _wordJoiner) {
        sawSideways = true;
        continue;
      }
      if (character == ' ') {
        sawSideways = true;
        continue;
      }
      if (_sidewaysRotatedGlyphs.contains(character)) {
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

  bool _isSidewaysCharacter(String character) {
    if (character.isEmpty || character == '―') {
      return false;
    }
    if (character == _wordJoiner || character == ' ') {
      return true;
    }
    final rune = character.runes.firstOrNull ?? 0;
    final isAsciiLetterOrDigit =
        (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5a) ||
        (rune >= 0x61 && rune <= 0x7a);
    final isFullwidthLetterOrDigit =
        (rune >= 0xff10 && rune <= 0xff19) ||
        (rune >= 0xff21 && rune <= 0xff3a) ||
        (rune >= 0xff41 && rune <= 0xff5a);
    const sidewaysPunctuation = '.,:;!?\'"()[]{}&+-/';
    return isAsciiLetterOrDigit ||
        isFullwidthLetterOrDigit ||
        sidewaysPunctuation.contains(character);
  }

  bool _containsLatinLetter(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x41 && rune <= 0x5a) ||
          (rune >= 0x61 && rune <= 0x7a) ||
          (rune >= 0xff21 && rune <= 0xff3a) ||
          (rune >= 0xff41 && rune <= 0xff5a)) {
        return true;
      }
    }
    return false;
  }

  double _measureSidewaysTextExtent(String text, _InlineContext context) {
    final fontSize = context.fontScale * constraints.baseFontSize;
    if (fontSize <= 0) {
      return context.fontScale;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: _measurementFontFamily,
          package: _measurementFontPackage,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
          textBaseline: TextBaseline.ideographic,
          fontWeight: context.bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: context.italic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width / fontSize;
  }

  Set<int> _computeLineBreakOpportunities(List<_Atom> atoms) {
    final buffer = StringBuffer();
    final boundaries = <int, int>{};
    var visibleCount = 0;
    for (var index = 0; index < atoms.length; index += 1) {
      final atom = atoms[index];
      if (atom.kind.isMarkerOnly || atom.kind == _AtomKind.lineBreak) {
        continue;
      }
      final breakText = atom.breakText;
      buffer.write(breakText);
      visibleCount += 1;
      boundaries[buffer.length] = index + 1;
    }
    if (buffer.length == 0) {
      return const <int>{};
    }
    final result = <int>{};
    final breaker = UnicodeLineBreaker(buffer.toString());
    while (true) {
      final lineBreak = breaker.nextBreak();
      if (lineBreak == null) {
        break;
      }
      final cursor = boundaries[lineBreak.position];
      if (cursor != null) {
        result.add(cursor);
      }
    }
    if (visibleCount > 0) {
      result.add(atoms.length);
    }
    return result;
  }

  bool _mayBreakBetween(_Atom previous, _Atom next) {
    final previousChar = previous.breakClassEnd;
    final nextChar = next.breakClassStart;
    if (previousChar == null || nextChar == null) {
      return true;
    }
    if (_lineEndForbidden.contains(previousChar)) {
      return false;
    }
    if (_lineStartForbidden.contains(nextChar)) {
      return false;
    }
    return true;
  }

  int _nextVisibleAtomCursor(List<_Atom> atoms, int start) {
    for (var index = start; index < atoms.length; index += 1) {
      if (!atoms[index].kind.isMarkerOnly &&
          atoms[index].kind != _AtomKind.lineBreak) {
        return index;
      }
    }
    return -1;
  }

  int _previousVisibleAtomCursor(List<_Atom> atoms, int start) {
    for (var index = start; index >= 0; index -= 1) {
      if (!atoms[index].kind.isMarkerOnly &&
          atoms[index].kind != _AtomKind.lineBreak) {
        return index;
      }
    }
    return -1;
  }

  int _nextVisibleAtomCursorInRange(List<_Atom> atoms, int start, int end) {
    for (var index = start; index < end; index += 1) {
      if (!atoms[index].kind.isMarkerOnly &&
          atoms[index].kind != _AtomKind.lineBreak) {
        return index;
      }
    }
    return -1;
  }

  int _consumeLeadingMarkers(List<_Atom> atoms, int start) {
    var cursor = start;
    while (cursor < atoms.length &&
        atoms[cursor].kind.isMarkerOnly &&
        atoms[cursor].kind != _AtomKind.lineBreak) {
      cursor += 1;
    }
    return cursor;
  }

  String _sliceRubyTextForLine(_RubyRange ruby, int lineStart, int lineEnd) {
    final runes = ruby.text.runes.toList(growable: false);
    if (runes.isEmpty) {
      return '';
    }
    final totalSpan = math.max(ruby.end - ruby.start, 1);
    final segmentStart = math.max(lineStart, ruby.start) - ruby.start;
    final segmentEnd = math.min(lineEnd, ruby.end) - ruby.start;
    final startIndex = ((segmentStart / totalSpan) * runes.length).floor();
    final rawEndIndex = ((segmentEnd / totalSpan) * runes.length).ceil();
    final endIndex = math.max(rawEndIndex, startIndex + 1);
    final clampedStart = math.min(startIndex, runes.length - 1);
    final clampedEnd = math.min(endIndex, runes.length);
    return String.fromCharCodes(runes.sublist(clampedStart, clampedEnd));
  }

  double _crossOffsetForRuby(
    RubyPosition position,
    double extent,
    _BlockContext context,
  ) {
    return switch (position) {
      RubyPosition.over || RubyPosition.left => extent,
      RubyPosition.under || RubyPosition.right => extent,
    };
  }

  double _rubyInterCharacterSpacing(String text, double baseExtent) {
    final characters = _splitCharacters(text);
    if (characters.length <= 1) {
      return 0;
    }
    final rubyTextExtent = characters.length * constraints.rubyScale;
    final overflow = rubyTextExtent - baseExtent;

    if (overflow + constraints.baseFontSize / 2 < 0) {
      return -(overflow + constraints.baseFontSize / 2) /
          (characters.length - 1);
    }
    if (overflow > 0) {
      return 0;
    }
    return 0;
  }

  double _rubyTextExtent(String text, double interCharacterSpacing) {
    final characters = _splitCharacters(text);
    if (characters.isEmpty) {
      return 0;
    }
    return characters.length * constraints.rubyScale +
        (characters.length - 1) * interCharacterSpacing;
  }

  _RubyBaseTrackingAdjustments _resolveLegacyRubyTrackingAdjustments(
    _ParagraphModel model,
  ) {
    final boundaryAdjustments = <int, double>{};
    var trailingExtent = 0.0;

    for (final ruby in model.rubies) {
      final start = ruby.start;
      final end = ruby.end;
      if (end <= start) {
        continue;
      }

      final baseExtent = model.atoms
          .sublist(start, end)
          .fold<double>(0, (sum, atom) => sum + atom.blockExtent);
      final rubyExtent = _rubyTextExtent(
        ruby.text,
        _rubyInterCharacterSpacing(ruby.text, math.max(baseExtent, 0)),
      );
      var overflow = rubyExtent - baseExtent;
      if (overflow <= 0) {
        continue;
      }

      final edgePadding = _legacyRubyEdgePadding(model, ruby);
      final startPadding = edgePadding.startPadding;
      final endPadding = edgePadding.endPadding;

      overflow -= startPadding + endPadding;
      if (overflow <= 0) {
        continue;
      }

      final tracking = overflow / (end - start + 1);
      for (var index = start; index <= end; index += 1) {
        if (index < model.atoms.length) {
          boundaryAdjustments.update(
            index,
            (current) => current + tracking,
            ifAbsent: () => tracking,
          );
        } else {
          trailingExtent += tracking;
        }
      }
    }

    return _RubyBaseTrackingAdjustments(
      boundaryAdjustments: boundaryAdjustments,
      trailingExtent: trailingExtent,
    );
  }

  ({double startPadding, double endPadding}) _legacyRubyEdgePadding(
    _ParagraphModel model,
    _RubyRange ruby,
  ) {
    var startPadding = 0.0;
    var endPadding = 0.0;

    if (ruby.start > 0) {
      final overlapsStart = model.rubies.any(
        (candidate) =>
            candidate.kind == ruby.kind &&
            candidate.start < ruby.start &&
            candidate.end >= ruby.start,
      );
      final previousText = model.atoms[ruby.start - 1].breakText;
      if (!overlapsStart &&
          previousText.isNotEmpty &&
          !_cjkIdeographPattern.hasMatch(
            String.fromCharCode(previousText.runes.last),
          )) {
        startPadding = constraints.baseFontSize / 2;
      }
    }

    final overlapsEnd = model.rubies.any(
      (candidate) =>
          candidate.kind == ruby.kind &&
          candidate.start <= ruby.end &&
          candidate.end > ruby.end,
    );
    if (!overlapsEnd && ruby.end < model.atoms.length) {
      final nextText = model.atoms[ruby.end].breakText;
      if (nextText.isNotEmpty &&
          !_cjkIdeographPattern.hasMatch(
            String.fromCharCode(nextText.runes.first),
          )) {
        endPadding = constraints.baseFontSize / 2;
      }
    }

    return (startPadding: startPadding, endPadding: endPadding);
  }

  double _crossOffsetForMarker(_RangeMarker marker, _BlockContext context) {
    return switch (marker.kind) {
      LayoutMarkerKind.emphasis => switch (marker.emphasisSide ??
          EmphasisSide.auto) {
        EmphasisSide.auto =>
          context.crossExtent - _markerInlineExtent(marker, context),
        EmphasisSide.under || EmphasisSide.right =>
          context.crossExtent - _markerInlineExtent(marker, context),
        _ => 0,
      },
      LayoutMarkerKind.decoration => switch (marker.decorationSide ??
          DecorationSide.auto) {
        DecorationSide.under || DecorationSide.right => context.crossExtent,
        _ => -_markerInlineExtent(marker, context),
      },
      LayoutMarkerKind.frame => 0,
      _ => -_markerInlineExtent(marker, context),
    };
  }

  double _markerInlineExtent(Object marker, _BlockContext context) {
    return switch (marker) {
      _RangeMarker(kind: LayoutMarkerKind.frame) => context.crossExtent,
      _RangeMarker(kind: LayoutMarkerKind.emphasis) => math.max(
        context.crossExtent * 0.5066666667,
        0.4,
      ),
      _RangeMarker(kind: LayoutMarkerKind.decoration) => math.max(
        context.crossExtent * 0.2,
        0.2,
      ),
      _PointMarker(kind: LayoutMarkerKind.note) => math.max(
        context.crossExtent * constraints.noteScale,
        0.5,
      ),
      _ => math.max(context.crossExtent * constraints.noteScale, 0.5),
    };
  }

  double _sumTableExtents(List<double> extents, double gap) {
    if (extents.isEmpty) {
      return 0;
    }
    return extents.reduce((a, b) => a + b) + gap * (extents.length - 1);
  }

  LayoutBlockStyle _blockStyle(
    _BlockContext context, {
    bool keepWithPrevious = false,
  }) {
    return LayoutBlockStyle(
      keepWithPrevious: keepWithPrevious,
      firstIndent: context.firstIndent,
      restIndent: context.restIndent,
      lineExtent: context.explicitLineExtent,
      alignToFarEdge: context.alignToFarEdge,
      flowKind: context.flowKind,
      frameKind: context.frameKind,
      frameBorderWidth: context.frameBorderWidth,
      caption: context.caption,
      bold: context.bold,
      italic: context.italic,
      fontScale: context.fontScale,
      headingLevel: context.headingLevel,
      headingDisplay: context.headingDisplay,
    );
  }
}

class _FlowLayout {
  const _FlowLayout({
    required this.blocks,
    required this.hitRegions,
    required this.inlineExtent,
    required this.blockExtent,
  });

  final List<LayoutBlockResult> blocks;
  final List<LayoutHitRegion> hitRegions;
  final double inlineExtent;
  final double blockExtent;
}

class _LeafLayout {
  const _LeafLayout({required this.block, required this.hitRegions});

  final LayoutBlockResult block;
  final List<LayoutHitRegion> hitRegions;
}

class _LineBuildResult {
  const _LineBuildResult({
    required this.lines,
    required this.hitRegions,
    required this.groupInlineExtent,
    required this.groupBlockExtent,
  });

  final List<LayoutLine> lines;
  final List<LayoutHitRegion> hitRegions;
  final double groupInlineExtent;
  final double groupBlockExtent;
}

class _TakenLineDraft {
  const _TakenLineDraft({
    required this.start,
    required this.end,
    required this.nextCursor,
    required this.indent,
    required this.textExtent,
  });

  final int start;
  final int end;
  final int nextCursor;
  final double indent;
  final double textExtent;
}

class _MaterializedLine {
  const _MaterializedLine({required this.line, required this.hitRegions});

  final LayoutLine line;
  final List<LayoutHitRegion> hitRegions;
}

class _TableRowDraft {
  const _TableRowDraft({
    required this.span,
    required this.cells,
    required this.attributes,
    required this.issues,
  });

  final SourceSpan span;
  final List<_TableCellDraft> cells;
  final Map<String, String> attributes;
  final List<LayoutIssue> issues;
}

class _TableCellDraft {
  const _TableCellDraft({
    required this.span,
    required this.blocks,
    required this.attributes,
    required this.issues,
    required this.inlineExtent,
    required this.blockExtent,
    required this.hitRegions,
  });

  final SourceSpan span;
  final List<LayoutBlockResult> blocks;
  final Map<String, String> attributes;
  final List<LayoutIssue> issues;
  final double inlineExtent;
  final double blockExtent;
  final List<LayoutHitRegion> hitRegions;
}

class _ParagraphModel {
  _ParagraphModel({required this.span})
    : atoms = <_Atom>[],
      rubies = <_RubyRange>[],
      rangeMarkers = <_RangeMarker>[],
      pointMarkers = <_PointMarker>[],
      links = <_LinkRange>[],
      anchors = <_AnchorPoint>[];

  final List<_Atom> atoms;
  final List<_RubyRange> rubies;
  final List<_RangeMarker> rangeMarkers;
  final List<_PointMarker> pointMarkers;
  final List<_LinkRange> links;
  final List<_AnchorPoint> anchors;
  final SourceSpan span;
}

enum _AtomKind {
  text,
  gaiji,
  image,
  note,
  unsupported,
  marker,
  lineBreak;

  bool get isMarkerOnly => this == marker;
}

class _Atom {
  const _Atom({
    required this.kind,
    required this.span,
    required this.text,
    required this.style,
    required this.blockExtent,
    required this.inlineExtent,
    this.legacyKinsoku = false,
    this.rawNotation,
    this.description,
    this.resolved = true,
    this.jisCode,
    this.unicodeCodePoint,
    this.alt,
    this.className,
    this.imageWidth,
    this.imageHeight,
    this.noteKind,
    this.directive,
    this.attributes = const <String, String>{},
    this.issues = const <LayoutIssue>[],
  });

  const _Atom.text({
    required SourceSpan span,
    required String text,
    required LayoutInlineStyle style,
    required double blockExtent,
    required double inlineExtent,
    bool legacyKinsoku = false,
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.text,
         span: span,
         text: text,
         style: style,
         blockExtent: blockExtent,
         inlineExtent: inlineExtent,
         legacyKinsoku: legacyKinsoku,
         issues: issues,
       );

  const _Atom.gaiji({
    required SourceSpan span,
    required String text,
    required LayoutInlineStyle style,
    required double blockExtent,
    required double inlineExtent,
    required String rawNotation,
    required String description,
    required bool resolved,
    String? jisCode,
    String? unicodeCodePoint,
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.gaiji,
         span: span,
         text: text,
         style: style,
         blockExtent: blockExtent,
         inlineExtent: inlineExtent,
         rawNotation: rawNotation,
         description: description,
         resolved: resolved,
         jisCode: jisCode,
         unicodeCodePoint: unicodeCodePoint,
         issues: issues,
       );

  const _Atom.image({
    required SourceSpan span,
    required String text,
    required LayoutInlineStyle style,
    required double blockExtent,
    required double inlineExtent,
    String? alt,
    String? className,
    int? imageWidth,
    int? imageHeight,
    Map<String, String> attributes = const <String, String>{},
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.image,
         span: span,
         text: text,
         style: style,
         blockExtent: blockExtent,
         inlineExtent: inlineExtent,
         alt: alt,
         className: className,
         imageWidth: imageWidth,
         imageHeight: imageHeight,
         attributes: attributes,
         issues: issues,
       );

  const _Atom.note({
    required SourceSpan span,
    required String text,
    required LayoutInlineStyle style,
    required double blockExtent,
    required double inlineExtent,
    required NoteKind noteKind,
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.note,
         span: span,
         text: text,
         style: style,
         blockExtent: blockExtent,
         inlineExtent: inlineExtent,
         noteKind: noteKind,
         issues: issues,
       );

  const _Atom.unsupported({
    required SourceSpan span,
    required LayoutInlineStyle style,
    required SourceDirective directive,
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.unsupported,
         span: span,
         text: '',
         style: style,
         blockExtent: 0,
         inlineExtent: 0,
         directive: directive,
         issues: issues,
       );

  const _Atom.marker({
    required SourceSpan span,
    required LayoutInlineStyle style,
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.marker,
         span: span,
         text: '',
         style: style,
         blockExtent: 0,
         inlineExtent: 0,
         issues: issues,
       );

  const _Atom.lineBreak({
    required SourceSpan span,
    required LayoutInlineStyle style,
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.lineBreak,
         span: span,
         text: '',
         style: style,
         blockExtent: 0,
         inlineExtent: 0,
         issues: issues,
       );

  final _AtomKind kind;
  final SourceSpan span;
  final String text;
  final LayoutInlineStyle style;
  final double blockExtent;
  final double inlineExtent;
  final bool legacyKinsoku;
  final String? rawNotation;
  final String? description;
  final bool resolved;
  final String? jisCode;
  final String? unicodeCodePoint;
  final String? alt;
  final String? className;
  final int? imageWidth;
  final int? imageHeight;
  final NoteKind? noteKind;
  final SourceDirective? directive;
  final Map<String, String> attributes;
  final List<LayoutIssue> issues;

  String get breakText {
    return switch (kind) {
      _AtomKind.image => '￼',
      _AtomKind.note => '（',
      _AtomKind.unsupported || _AtomKind.marker || _AtomKind.lineBreak => '',
      _ => text,
    };
  }

  String? get breakClassStart {
    final effectiveText = breakText;
    if (effectiveText.isEmpty) {
      return null;
    }
    return String.fromCharCode(effectiveText.runes.first);
  }

  String? get breakClassEnd {
    final effectiveText = breakText;
    if (effectiveText.isEmpty) {
      return null;
    }
    return String.fromCharCode(effectiveText.runes.last);
  }

  _Atom copyWith({bool? legacyKinsoku}) {
    return _Atom(
      kind: kind,
      span: span,
      text: text,
      style: style,
      blockExtent: blockExtent,
      inlineExtent: inlineExtent,
      legacyKinsoku: legacyKinsoku ?? this.legacyKinsoku,
      rawNotation: rawNotation,
      description: description,
      resolved: resolved,
      jisCode: jisCode,
      unicodeCodePoint: unicodeCodePoint,
      alt: alt,
      className: className,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      noteKind: noteKind,
      directive: directive,
      attributes: attributes,
      issues: issues,
    );
  }
}

class _RubyRange {
  const _RubyRange({
    required this.span,
    required this.start,
    required this.end,
    required this.text,
    required this.kind,
    required this.position,
    required this.issues,
  });

  final SourceSpan span;
  final int start;
  final int end;
  final String text;
  final RubyKind kind;
  final RubyPosition position;
  final List<LayoutIssue> issues;
}

class _LinkRange {
  const _LinkRange({
    required this.span,
    required this.start,
    required this.end,
    required this.target,
    required this.issues,
  });

  final SourceSpan span;
  final int start;
  final int end;
  final String target;
  final List<LayoutIssue> issues;
}

class _AnchorPoint {
  const _AnchorPoint({
    required this.span,
    required this.atomIndex,
    required this.name,
    required this.issues,
  });

  final SourceSpan span;
  final int atomIndex;
  final String name;
  final List<LayoutIssue> issues;
}

class _RangeMarker {
  const _RangeMarker({
    required this.kind,
    required this.span,
    required this.start,
    required this.end,
    this.emphasisMark,
    this.emphasisSide,
    this.decorationKind,
    this.decorationSide,
    this.noteKind,
    this.frameKind,
    this.issues = const <LayoutIssue>[],
  });

  const _RangeMarker.emphasis(
    SourceSpan span,
    EmphasisMark mark,
    EmphasisSide side,
    List<LayoutIssue> issues,
  ) : this(
        kind: LayoutMarkerKind.emphasis,
        span: span,
        start: -1,
        end: -1,
        emphasisMark: mark,
        emphasisSide: side,
        issues: issues,
      );

  const _RangeMarker.decoration(
    SourceSpan span,
    DecorationKind kind,
    DecorationSide side,
    List<LayoutIssue> issues,
  ) : this(
        kind: LayoutMarkerKind.decoration,
        span: span,
        start: -1,
        end: -1,
        decorationKind: kind,
        decorationSide: side,
        issues: issues,
      );

  const _RangeMarker.frame(
    SourceSpan span,
    FrameKind frameKind,
    List<LayoutIssue> issues,
  ) : this(
        kind: LayoutMarkerKind.frame,
        span: span,
        start: -1,
        end: -1,
        frameKind: frameKind,
        issues: issues,
      );

  final LayoutMarkerKind kind;
  final SourceSpan span;
  final int start;
  final int end;
  final EmphasisMark? emphasisMark;
  final EmphasisSide? emphasisSide;
  final DecorationKind? decorationKind;
  final DecorationSide? decorationSide;
  final NoteKind? noteKind;
  final FrameKind? frameKind;
  final List<LayoutIssue> issues;

  _RangeMarker withRange(int start, int end) {
    return _RangeMarker(
      kind: kind,
      span: span,
      start: start,
      end: end,
      emphasisMark: emphasisMark,
      emphasisSide: emphasisSide,
      decorationKind: decorationKind,
      decorationSide: decorationSide,
      noteKind: noteKind,
      frameKind: frameKind,
      issues: issues,
    );
  }
}

class _PointMarker {
  const _PointMarker({
    required this.kind,
    required this.span,
    required this.atomIndex,
    this.text,
    this.noteKind,
    this.issues = const <LayoutIssue>[],
  });

  const _PointMarker.note({
    required SourceSpan span,
    required int atomIndex,
    required NoteKind noteKind,
    required String text,
    required List<LayoutIssue> issues,
  }) : this(
         kind: LayoutMarkerKind.note,
         span: span,
         atomIndex: atomIndex,
         text: text,
         noteKind: noteKind,
         issues: issues,
       );

  const _PointMarker.kaeriten({
    required SourceSpan span,
    required int atomIndex,
    required String text,
    required List<LayoutIssue> issues,
  }) : this(
         kind: LayoutMarkerKind.kaeriten,
         span: span,
         atomIndex: atomIndex,
         text: text,
         issues: issues,
       );

  const _PointMarker.okurigana({
    required SourceSpan span,
    required int atomIndex,
    required String text,
    required List<LayoutIssue> issues,
  }) : this(
         kind: LayoutMarkerKind.okurigana,
         span: span,
         atomIndex: atomIndex,
         text: text,
         issues: issues,
       );

  const _PointMarker.editorNote({
    required SourceSpan span,
    required int atomIndex,
    required String text,
    required List<LayoutIssue> issues,
  }) : this(
         kind: LayoutMarkerKind.editorNote,
         span: span,
         atomIndex: atomIndex,
         text: text,
         issues: issues,
       );

  const _PointMarker.unsupported({
    required SourceSpan span,
    required int atomIndex,
    required String text,
    required List<LayoutIssue> issues,
  }) : this(
         kind: LayoutMarkerKind.unsupported,
         span: span,
         atomIndex: atomIndex,
         text: text,
         issues: issues,
       );

  final LayoutMarkerKind kind;
  final SourceSpan span;
  final int atomIndex;
  final String? text;
  final NoteKind? noteKind;
  final List<LayoutIssue> issues;
}

class _FragmentPlacement {
  const _FragmentPlacement({
    required this.blockOffset,
    required this.blockExtent,
    required this.inlineExtent,
    required this.style,
  });

  final double blockOffset;
  final double blockExtent;
  final double inlineExtent;
  final LayoutInlineStyle style;
}

class _RubyBaseTrackingAdjustments {
  const _RubyBaseTrackingAdjustments({
    required this.boundaryAdjustments,
    required this.trailingExtent,
  });

  final Map<int, double> boundaryAdjustments;
  final double trailingExtent;
}

class _LegacyAtomDraft {
  const _LegacyAtomDraft(this.text);

  final String text;
}

class _BlockContext {
  const _BlockContext({
    required this.constraints,
    required this.firstIndent,
    required this.restIndent,
    required this.explicitLineExtent,
    required this.alignToFarEdge,
    required this.frameKind,
    required this.frameBorderWidth,
    required this.flowKind,
    required this.caption,
    required this.bold,
    required this.italic,
    required this.fontScale,
    required this.headingLevel,
    required this.headingDisplay,
  });

  factory _BlockContext.initial(LayoutConstraints constraints) {
    return _BlockContext(
      constraints: constraints,
      firstIndent: 0,
      restIndent: 0,
      explicitLineExtent: null,
      alignToFarEdge: false,
      frameKind: null,
      frameBorderWidth: 0,
      flowKind: null,
      caption: false,
      bold: false,
      italic: false,
      fontScale: 1,
      headingLevel: null,
      headingDisplay: null,
    );
  }

  final LayoutConstraints constraints;
  final double firstIndent;
  final double restIndent;
  final double? explicitLineExtent;
  final bool alignToFarEdge;
  final FrameKind? frameKind;
  final int frameBorderWidth;
  final FlowKind? flowKind;
  final bool caption;
  final bool bold;
  final bool italic;
  final double fontScale;
  final HeadingLevel? headingLevel;
  final HeadingDisplay? headingDisplay;

  double get resolvedLineExtent => explicitLineExtent ?? constraints.lineExtent;

  double get crossExtent => math.max(fontScale, constraints.baseFontSize);

  LayoutBlockStyle get publicStyle => LayoutBlockStyle(
    firstIndent: firstIndent,
    restIndent: restIndent,
    lineExtent: explicitLineExtent,
    alignToFarEdge: alignToFarEdge,
    flowKind: flowKind,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    caption: caption,
    bold: bold,
    italic: italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _InlineContext get inlineContext => _InlineContext(
    constraints: constraints,
    fontScale: fontScale,
    bold: bold,
    italic: italic,
    caption: caption,
    flowKind: flowKind,
    directionKind: null,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: null,
  );

  _BlockContext withIndent(double width) => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent + width,
    restIndent: restIndent + width,
    explicitLineExtent: explicitLineExtent,
    alignToFarEdge: alignToFarEdge,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    flowKind: flowKind,
    caption: caption,
    bold: bold,
    italic: italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withAlignment(BlockAlignmentKind kind) => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent,
    restIndent: restIndent,
    explicitLineExtent: explicitLineExtent,
    alignToFarEdge: true,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    flowKind: flowKind,
    caption: caption,
    bold: bold,
    italic: italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withJizume(double? width) => withExplicitLineExtent(width);

  _BlockContext withExplicitLineExtent(double? width) => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent,
    restIndent: restIndent,
    explicitLineExtent: width,
    alignToFarEdge: alignToFarEdge,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    flowKind: flowKind,
    caption: caption,
    bold: bold,
    italic: italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withFlow(FlowKind kind) => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent,
    restIndent: restIndent,
    explicitLineExtent: explicitLineExtent,
    alignToFarEdge: alignToFarEdge,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    flowKind: kind,
    caption: caption,
    bold: bold,
    italic: italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withCaption() => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent,
    restIndent: restIndent,
    explicitLineExtent: explicitLineExtent,
    alignToFarEdge: alignToFarEdge,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    flowKind: flowKind,
    caption: true,
    bold: bold,
    italic: italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withFrame(FrameKind kind, int borderWidth) => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent,
    restIndent: restIndent,
    explicitLineExtent: explicitLineExtent,
    alignToFarEdge: alignToFarEdge,
    frameKind: kind,
    frameBorderWidth: borderWidth,
    flowKind: flowKind,
    caption: caption,
    bold: bold,
    italic: italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withTextStyle(TextStyleKind style) => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent,
    restIndent: restIndent,
    explicitLineExtent: explicitLineExtent,
    alignToFarEdge: alignToFarEdge,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    flowKind: flowKind,
    caption: caption,
    bold: bold || style == TextStyleKind.bold,
    italic: italic || style == TextStyleKind.italic,
    fontScale: fontScale,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withFontSize(FontSizeKind kind, int steps) => _BlockContext(
    constraints: constraints,
    firstIndent: firstIndent,
    restIndent: restIndent,
    explicitLineExtent: explicitLineExtent,
    alignToFarEdge: alignToFarEdge,
    frameKind: frameKind,
    frameBorderWidth: frameBorderWidth,
    flowKind: flowKind,
    caption: caption,
    bold: bold,
    italic: italic,
    fontScale: fontScale * _fontScale(kind, steps),
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
  );

  _BlockContext withHeading(HeadingLevel level, HeadingDisplay display) =>
      _BlockContext(
        constraints: constraints,
        firstIndent: firstIndent,
        restIndent: restIndent,
        explicitLineExtent: explicitLineExtent,
        alignToFarEdge: alignToFarEdge,
        frameKind: frameKind,
        frameBorderWidth: frameBorderWidth,
        flowKind: flowKind,
        caption: caption,
        bold: true,
        italic: italic,
        fontScale: fontScale * _headingScale(level),
        headingLevel: level,
        headingDisplay: display,
      );

  static double _fontScale(FontSizeKind kind, int steps) {
    final magnitude = math.pow(kind == FontSizeKind.larger ? 1.2 : 0.85, steps);
    return magnitude.toDouble();
  }

  static double _headingScale(HeadingLevel level) {
    return switch (level) {
      HeadingLevel.large => 1.44,
      HeadingLevel.medium => 1.2,
      HeadingLevel.small => 1,
    };
  }
}

class _InlineContext {
  const _InlineContext({
    required this.constraints,
    required this.fontScale,
    required this.bold,
    required this.italic,
    required this.caption,
    required this.flowKind,
    required this.directionKind,
    required this.headingLevel,
    required this.headingDisplay,
    required this.scriptKind,
  });

  final LayoutConstraints constraints;
  final double fontScale;
  final bool bold;
  final bool italic;
  final bool caption;
  final FlowKind? flowKind;
  final DirectionKind? directionKind;
  final HeadingLevel? headingLevel;
  final HeadingDisplay? headingDisplay;
  final ScriptKind? scriptKind;

  LayoutInlineStyle get publicStyle => LayoutInlineStyle(
    fontScale: fontScale,
    bold: bold,
    italic: italic,
    caption: caption,
    flowKind: flowKind,
    directionKind: directionKind,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: scriptKind,
  );

  _InlineContext withFlow(FlowKind kind) => _InlineContext(
    constraints: constraints,
    fontScale: fontScale,
    bold: bold,
    italic: italic,
    caption: caption,
    flowKind: kind,
    directionKind: directionKind,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: scriptKind,
  );

  _InlineContext withCaption() => _InlineContext(
    constraints: constraints,
    fontScale: fontScale,
    bold: bold,
    italic: italic,
    caption: true,
    flowKind: flowKind,
    directionKind: directionKind,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: scriptKind,
  );

  _InlineContext withFrame(FrameKind kind, int borderWidth) => this;

  _InlineContext withTextStyle(TextStyleKind style) => _InlineContext(
    constraints: constraints,
    fontScale: fontScale,
    bold: bold || style == TextStyleKind.bold,
    italic: italic || style == TextStyleKind.italic,
    caption: caption,
    flowKind: flowKind,
    directionKind: directionKind,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: scriptKind,
  );

  _InlineContext withFontSize(FontSizeKind kind, int steps) => _InlineContext(
    constraints: constraints,
    fontScale: fontScale * _BlockContext._fontScale(kind, steps),
    bold: bold,
    italic: italic,
    caption: caption,
    flowKind: flowKind,
    directionKind: directionKind,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: scriptKind,
  );

  _InlineContext withHeading(HeadingLevel level, HeadingDisplay display) =>
      _InlineContext(
        constraints: constraints,
        fontScale: fontScale * _BlockContext._headingScale(level),
        bold: true,
        italic: italic,
        caption: caption,
        flowKind: flowKind,
        directionKind: directionKind,
        headingLevel: level,
        headingDisplay: display,
        scriptKind: scriptKind,
      );

  _InlineContext withDirection(DirectionKind kind) => _InlineContext(
    constraints: constraints,
    fontScale: fontScale,
    bold: bold,
    italic: italic,
    caption: caption,
    flowKind: flowKind,
    directionKind: kind,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: scriptKind,
  );

  _InlineContext withScript(ScriptKind kind) => _InlineContext(
    constraints: constraints,
    fontScale: fontScale * constraints.scriptScale,
    bold: bold,
    italic: italic,
    caption: caption,
    flowKind: flowKind,
    directionKind: directionKind,
    headingLevel: headingLevel,
    headingDisplay: headingDisplay,
    scriptKind: kind,
  );
}
