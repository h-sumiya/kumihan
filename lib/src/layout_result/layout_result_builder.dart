import 'dart:math' as math;

import '../ast/ast.dart';
import '../layout_ir/layout_ir.dart';
import 'compat/gaiji_resolver.dart';
import 'compat/line_breaker.dart';
import 'layout_result.dart';

class LayoutResultBuilder {
  LayoutResultBuilder({this.constraints = const LayoutConstraints()});

  final LayoutConstraints constraints;

  static const String _fallbackGaiji = '〓';
  static const String _noteOpen = '（';
  static const String _noteClose = '）';

  static const String _lineStartForbidden =
      '、。，．・：；！？)]｝〕〉》」』】〙〗ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮー゛゜';
  static const String _lineEndForbidden = '([｛〔〈《「『【〘〖';

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

    void append(_LeafLayout leaf, {required bool keepWithPrevious}) {
      if (emitted && !keepWithPrevious) {
        cursor += constraints.blockGap;
      }
      results.add(leaf.block);
      hitRegions.addAll(leaf.hitRegions);
      blockExtent = math.max(blockExtent, leaf.block.blockExtent);
      cursor += leaf.block.inlineExtent;
      emitted = true;
    }

    void appendFlow(_FlowLayout flow, {required bool keepWithPrevious}) {
      if (flow.blocks.isEmpty) {
        return;
      }
      if (emitted && !keepWithPrevious) {
        cursor += constraints.blockGap;
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
          append(
            _layoutParagraph(block, context, inlineOffset: cursor),
            keepWithPrevious: block.keepWithPrevious,
          );
        case LayoutEmptyLine():
          append(
            _layoutEmptyLine(block, context, inlineOffset: cursor),
            keepWithPrevious: false,
          );
        case LayoutUnsupportedBlock():
          append(
            _layoutUnsupportedBlock(block, context, inlineOffset: cursor),
            keepWithPrevious: false,
          );
        case LayoutIndentBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withIndent(block.width?.toDouble() ?? 0),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutAlignmentBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withAlignment(block.kind),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutJizumeBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withJizume(block.width?.toDouble()),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutFlowBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withFlow(block.kind),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutCaptionBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withCaption(),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutFrameBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withFrame(block.kind, block.borderWidth),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutStyledBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withTextStyle(block.style),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutFontSizeBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withFontSize(block.kind, block.steps),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutHeadingBlock():
          appendFlow(
            _layoutBlocks(
              block.children,
              context.withHeading(block.level, block.display),
              baseInlineOffset: cursor,
            ),
            keepWithPrevious: false,
          );
        case LayoutTableBlock():
          append(
            _layoutTable(block, context, inlineOffset: cursor),
            keepWithPrevious: false,
          );
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
      );
      atomCursor = lineDraft.nextCursor;
      final line = _materializeLine(
        span,
        model,
        lineDraft,
        context,
        lineInlineOffset: lineInlineOffset,
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
  }) {
    final indent = firstLine ? context.firstIndent : context.restIndent;
    final available = math.max(context.resolvedLineExtent - indent, 1.0);
    var cursor = start;
    var visibleExtent = 0.0;
    var hadVisible = false;
    var lastBreakCursor = -1;
    var extentAtLastBreak = 0.0;

    while (cursor < atoms.length) {
      final atom = atoms[cursor];
      if (atom.kind == _AtomKind.lineBreak) {
        cursor += 1;
        break;
      }
      if (atom.kind.isMarkerOnly) {
        cursor += 1;
        continue;
      }
      final nextExtent = visibleExtent + atom.blockExtent;
      if (nextExtent <= available || !hadVisible) {
        visibleExtent = nextExtent;
        hadVisible = true;
        final nextCursor = _nextVisibleAtomCursor(atoms, cursor + 1);
        if (nextCursor >= 0 &&
            nextCursor < atoms.length &&
            breakPositions.contains(nextCursor) &&
            _mayBreakBetween(atom, atoms[nextCursor])) {
          lastBreakCursor = nextCursor;
          extentAtLastBreak = visibleExtent;
        }
        cursor += 1;
        continue;
      }
      if (lastBreakCursor > start) {
        cursor = lastBreakCursor;
        visibleExtent = extentAtLastBreak;
      }
      break;
    }

    if (cursor == start && start < atoms.length) {
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
      return _TakenLineDraft(
        start: start,
        end: end,
        nextCursor: end,
        indent: indent,
        textExtent: atom.blockExtent,
      );
    }

    return _TakenLineDraft(
      start: start,
      end: cursor,
      nextCursor: cursor,
      indent: indent,
      textExtent: visibleExtent,
    );
  }

  _MaterializedLine _materializeLine(
    SourceSpan span,
    _ParagraphModel model,
    _TakenLineDraft draft,
    _BlockContext context, {
    required double lineInlineOffset,
  }) {
    final fragments = <LayoutFragment>[];
    final hitRegions = <LayoutHitRegion>[];
    final atomPlacements = <int, _FragmentPlacement>{};

    final contentShift = context.alignToFarEdge
        ? math.max(context.resolvedLineExtent - draft.textExtent, 0).toDouble()
        : draft.indent;
    var blockCursor = contentShift;

    for (var index = draft.start; index < draft.end; index += 1) {
      final atom = model.atoms[index];
      if (atom.kind == _AtomKind.lineBreak) {
        continue;
      }
      if (atom.kind.isMarkerOnly) {
        atomPlacements[index] = _FragmentPlacement(
          blockOffset: blockCursor,
          blockExtent: 0,
          inlineExtent: context.crossExtent,
          style: atom.style,
        );
        continue;
      }
      final placement = _FragmentPlacement(
        blockOffset: blockCursor,
        blockExtent: atom.blockExtent,
        inlineExtent: atom.inlineExtent,
        style: atom.style,
      );
      atomPlacements[index] = placement;
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
      blockCursor += atom.blockExtent;
    }

    final rubies = _buildRubiesForLine(
      model,
      atomPlacements,
      draft.start,
      draft.end,
      lineInlineOffset,
      context,
    );
    final markers = <LayoutMarker>[
      ..._buildRangeMarkersForLine(
        model,
        atomPlacements,
        draft.start,
        draft.end,
        lineInlineOffset,
        context,
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
        inlineExtent: context.crossExtent,
        blockExtent: context.resolvedLineExtent,
        textExtent: draft.textExtent,
        fragments: List<LayoutFragment>.unmodifiable(fragments),
        rubies: List<LayoutRubyPlacement>.unmodifiable(rubies),
        markers: List<LayoutMarker>.unmodifiable(markers),
      ),
      hitRegions: hitRegions,
    );
  }

  LayoutFragment? _buildFragment(
    _Atom atom,
    _FragmentPlacement placement,
    double lineInlineOffset,
  ) {
    return switch (atom.kind) {
      _AtomKind.text => LayoutTextFragment(
        span: atom.span,
        inlineOffset: lineInlineOffset,
        blockOffset: placement.blockOffset,
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
    _BlockContext context,
  ) {
    final rubies = <LayoutRubyPlacement>[];
    for (final ruby in model.rubies) {
      final segmentStart = math.max(ruby.start, lineStart);
      final segmentEnd = math.min(ruby.end, lineEnd);
      if (segmentEnd <= segmentStart) {
        continue;
      }
      final baseAtoms = <int>[
        for (var index = segmentStart; index < segmentEnd; index += 1)
          if (placements[index] != null) index,
      ];
      if (baseAtoms.isEmpty) {
        continue;
      }
      final first = placements[baseAtoms.first]!;
      final last = placements[baseAtoms.last]!;
      final blockStart = first.blockOffset;
      final blockEnd = last.blockOffset + last.blockExtent;
      final segmentText = _sliceRubyTextForLine(ruby, lineStart, lineEnd);
      final inlineExtent = math.max(
        context.crossExtent * constraints.rubyScale,
        constraints.baseFontSize * constraints.rubyScale,
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
          blockOffset: blockStart,
          blockExtent: math.max(blockEnd - blockStart, 0),
          inlineExtent: inlineExtent,
          interCharacterSpacing: _rubyInterCharacterSpacing(
            segmentText,
            math.max(blockEnd - blockStart, 0),
          ),
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
    _BlockContext context,
  ) {
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
          for (final char in _splitCharacters(node.text)) {
            model.atoms.add(
              _Atom.text(
                span: node.span,
                text: char,
                style: context.publicStyle,
                blockExtent: context.fontScale,
                inlineExtent: context.fontScale,
                issues: node.issues,
              ),
            );
          }
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
      RubyPosition.over || RubyPosition.left => -extent,
      RubyPosition.under || RubyPosition.right => context.crossExtent,
    };
  }

  double _rubyInterCharacterSpacing(String text, double baseExtent) {
    final characters = _splitCharacters(text);
    if (characters.length <= 1) {
      return 0;
    }
    final rubyGlyphExtent = characters.length * constraints.rubyScale;
    return (baseExtent - rubyGlyphExtent) / (characters.length - 1);
  }

  double _crossOffsetForMarker(_RangeMarker marker, _BlockContext context) {
    return switch (marker.kind) {
      LayoutMarkerKind.emphasis => switch (marker.emphasisSide ??
          EmphasisSide.auto) {
        EmphasisSide.under || EmphasisSide.right => context.crossExtent,
        _ => -_markerInlineExtent(marker, context),
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
        context.crossExtent * constraints.noteScale,
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
    List<LayoutIssue> issues = const <LayoutIssue>[],
  }) : this(
         kind: _AtomKind.text,
         span: span,
         text: text,
         style: style,
         blockExtent: blockExtent,
         inlineExtent: inlineExtent,
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
