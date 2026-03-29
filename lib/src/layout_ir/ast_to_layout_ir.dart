import '../ast/ast.dart';
import 'layout_ir.dart';

class AstToLayoutIrConverter {
  LayoutDocument convert(DocumentNode document) {
    _issues.clear();
    final children = document.children
        .map(_convertBlock)
        .toList(growable: false);
    return LayoutDocument(
      span: document.span,
      children: children,
      diagnostics: List<AstDiagnostic>.unmodifiable(document.diagnostics),
      issues: List<LayoutIssue>.unmodifiable(_issues),
    );
  }

  final List<LayoutIssue> _issues = <LayoutIssue>[];

  LayoutBlock _convertBlock(BlockNode node) {
    return switch (node) {
      ParagraphNode() => LayoutParagraph(
        span: node.span,
        children: _convertInlines(node.children),
        keepWithPrevious: node.keepWithPrevious,
      ),
      EmptyLineNode() => LayoutEmptyLine(span: node.span),
      OpaqueBlockNode() => LayoutUnsupportedBlock(
        span: node.span,
        directive: node.directive,
        issues: _issuesFor(
          node.span,
          code: 'opaque_block_directive',
          message: 'Unknown block directive cannot be rendered by kumihan-v0.',
        ),
      ),
      IndentBlockNode() => LayoutIndentBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        width: node.width,
        isClosed: node.isClosed,
      ),
      AlignmentBlockNode() => LayoutAlignmentBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        kind: node.kind,
        isClosed: node.isClosed,
      ),
      JizumeBlockNode() => LayoutJizumeBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        width: node.width,
        isClosed: node.isClosed,
      ),
      FlowBlockNode() => LayoutFlowBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        kind: node.kind,
        isClosed: node.isClosed,
      ),
      CaptionBlockNode() => LayoutCaptionBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        isClosed: node.isClosed,
      ),
      FrameBlockNode() => LayoutFrameBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        kind: node.kind,
        borderWidth: node.borderWidth,
        isClosed: node.isClosed,
      ),
      StyledBlockNode() => LayoutStyledBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        style: node.style,
        isClosed: node.isClosed,
      ),
      FontSizeBlockNode() => LayoutFontSizeBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        kind: node.kind,
        steps: node.steps,
        isClosed: node.isClosed,
      ),
      HeadingBlockNode() => LayoutHeadingBlock(
        span: node.span,
        children: _convertBlocks(node.children),
        level: node.level,
        display: node.display,
        isClosed: node.isClosed,
        issues: _headingDisplayIssues(node.span, node.display),
      ),
      TableBlockNode() => LayoutTableBlock(
        span: node.span,
        rows: node.rows.map(_convertTableRow).toList(growable: false),
        attributes: Map<String, String>.unmodifiable(node.attributes),
        issues: _tableBlockIssues(node),
      ),
    };
  }

  LayoutTableRow _convertTableRow(TableRowNode node) {
    return LayoutTableRow(
      span: node.span,
      cells: node.cells.map(_convertTableCell).toList(growable: false),
      attributes: Map<String, String>.unmodifiable(node.attributes),
      issues: node.attributes.isEmpty
          ? const <LayoutIssue>[]
          : _issuesFor(
              node.span,
              code: 'table_row_attributes_not_supported_by_v0',
              message:
                  'kumihan-v0 table rendering does not preserve row attributes.',
            ),
    );
  }

  LayoutTableCell _convertTableCell(TableCellNode node) {
    final children = _convertBlocks(node.children);
    final issues = <LayoutIssue>[
      if (node.attributes.isNotEmpty)
        ..._issuesFor(
          node.span,
          code: 'table_cell_attributes_not_supported_by_v0',
          message:
              'kumihan-v0 table rendering does not preserve cell attributes.',
        ),
      if (!_isV0CompatibleTableCell(node))
        ..._issuesFor(
          node.span,
          code: 'rich_table_cell_content_not_supported_by_v0',
          message: 'kumihan-v0 table rendering supports plain text cells only.',
        ),
    ];
    return LayoutTableCell(
      span: node.span,
      children: children,
      attributes: Map<String, String>.unmodifiable(node.attributes),
      issues: List<LayoutIssue>.unmodifiable(issues),
    );
  }

  LayoutInline _convertInline(InlineNode node) {
    return switch (node) {
      TextNode() => LayoutTextInline(span: node.span, text: node.text),
      GaijiNode() => LayoutGaijiInline(
        span: node.span,
        rawNotation: node.rawNotation,
        description: node.description,
        jisCode: node.jisCode,
        unicodeCodePoint: node.unicodeCodePoint,
      ),
      UnresolvedGaijiNode() => LayoutUnresolvedGaijiInline(
        span: node.span,
        rawNotation: node.rawNotation,
        text: node.text,
        sourceDirective: node.sourceDirective,
        issues: _issuesFor(
          node.span,
          code: 'unresolved_gaiji_not_supported_by_v0',
          message: 'kumihan-v0 cannot resolve unresolved gaiji entries.',
        ),
      ),
      ImageNode() => LayoutImageInline(
        span: node.span,
        source: node.source,
        alt: node.alt,
        className: node.className,
        width: node.width,
        height: node.height,
        attributes: Map<String, String>.unmodifiable(node.attributes),
        sourceDirective: node.sourceDirective,
      ),
      LinkNode() => LayoutLinkInline(
        span: node.span,
        children: _convertInlines(node.children),
        target: node.target,
        sourceDirective: node.sourceDirective,
        isClosed: node.isClosed,
      ),
      AnchorNode() => LayoutAnchorInline(
        span: node.span,
        name: node.name,
        sourceDirective: node.sourceDirective,
      ),
      RubyNode() => LayoutRubyInline(
        span: node.span,
        base: _convertInlines(node.base),
        text: node.text,
        kind: node.kind,
        position: node.position,
        sourceDirective: node.sourceDirective,
        issues: _rubyIssues(node.span, node.position),
      ),
      DirectionInlineNode() => LayoutDirectionInline(
        span: node.span,
        children: _convertInlines(node.children),
        kind: node.kind,
        isClosed: node.isClosed,
      ),
      FlowInlineNode() => LayoutFlowInline(
        span: node.span,
        children: _convertInlines(node.children),
        kind: node.kind,
        isClosed: node.isClosed,
      ),
      CaptionInlineNode() => LayoutCaptionInline(
        span: node.span,
        children: _convertInlines(node.children),
        isClosed: node.isClosed,
      ),
      FrameInlineNode() => LayoutFrameInline(
        span: node.span,
        children: _convertInlines(node.children),
        kind: node.kind,
        borderWidth: node.borderWidth,
        isClosed: node.isClosed,
      ),
      NoteInlineNode() => LayoutNoteInline(
        span: node.span,
        children: _convertInlines(node.children),
        kind: node.kind,
        isClosed: node.isClosed,
        issues: _noteIssues(node.span, node.kind),
      ),
      StyledInlineNode() => LayoutStyledInline(
        span: node.span,
        children: _convertInlines(node.children),
        style: node.style,
        isClosed: node.isClosed,
      ),
      FontSizeInlineNode() => LayoutFontSizeInline(
        span: node.span,
        children: _convertInlines(node.children),
        kind: node.kind,
        steps: node.steps,
        isClosed: node.isClosed,
      ),
      HeadingInlineNode() => LayoutHeadingInline(
        span: node.span,
        children: _convertInlines(node.children),
        level: node.level,
        display: node.display,
        isClosed: node.isClosed,
        issues: _headingDisplayIssues(node.span, node.display),
      ),
      EmphasisInlineNode() => LayoutEmphasisInline(
        span: node.span,
        children: _convertInlines(node.children),
        mark: node.mark,
        side: node.side,
        isClosed: node.isClosed,
        issues: _emphasisIssues(node.span, node.side),
      ),
      DecorationInlineNode() => LayoutDecorationInline(
        span: node.span,
        children: _convertInlines(node.children),
        kind: node.kind,
        side: node.side,
        isClosed: node.isClosed,
        issues: _decorationIssues(node.span, node.side),
      ),
      ScriptInlineNode() => LayoutScriptInline(
        span: node.span,
        kind: node.kind,
        text: node.text,
        sourceDirective: node.sourceDirective,
      ),
      KaeritenNode() => LayoutKaeritenInline(
        span: node.span,
        text: node.text,
        sourceDirective: node.sourceDirective,
      ),
      OkuriganaNode() => LayoutOkuriganaInline(
        span: node.span,
        text: node.text,
        sourceDirective: node.sourceDirective,
      ),
      EditorNoteNode() => LayoutEditorNoteInline(
        span: node.span,
        text: node.text,
        sourceDirective: node.sourceDirective,
      ),
      LineBreakNode() => LayoutLineBreakInline(
        span: node.span,
        kind: node.kind,
        sourceDirective: node.sourceDirective,
      ),
      OpaqueInlineNode() => LayoutUnsupportedInline(
        span: node.span,
        directive: node.directive,
        issues: _issuesFor(
          node.span,
          code: 'opaque_inline_directive',
          message: 'Unknown inline directive cannot be rendered by kumihan-v0.',
        ),
      ),
    };
  }

  List<LayoutBlock> _convertBlocks(List<BlockNode> nodes) {
    return List<LayoutBlock>.unmodifiable(nodes.map(_convertBlock));
  }

  List<LayoutInline> _convertInlines(List<InlineNode> nodes) {
    return List<LayoutInline>.unmodifiable(nodes.map(_convertInline));
  }

  List<LayoutIssue> _headingDisplayIssues(
    SourceSpan span,
    HeadingDisplay display,
  ) {
    if (display == HeadingDisplay.normal) {
      return const <LayoutIssue>[];
    }
    return _issuesFor(
      span,
      code: 'heading_display_not_supported_by_v0',
      message:
          'kumihan-v0 treats ${display.name} headings as normal heading styling.',
    );
  }

  List<LayoutIssue> _noteIssues(SourceSpan span, NoteKind kind) {
    if (kind == NoteKind.warichu) {
      return const <LayoutIssue>[];
    }
    return _issuesFor(
      span,
      code: 'warigaki_not_supported_by_v0',
      message: 'kumihan-v0 supports warichu but not warigaki.',
    );
  }

  List<LayoutIssue> _rubyIssues(SourceSpan span, RubyPosition position) {
    if (position == RubyPosition.over || position == RubyPosition.left) {
      return const <LayoutIssue>[];
    }
    return _issuesFor(
      span,
      code: 'ruby_position_not_supported_by_v0',
      message: 'kumihan-v0 only distinguishes top and left ruby placement.',
    );
  }

  List<LayoutIssue> _emphasisIssues(SourceSpan span, EmphasisSide side) {
    if (side == EmphasisSide.auto ||
        side == EmphasisSide.left ||
        side == EmphasisSide.over) {
      return const <LayoutIssue>[];
    }
    return _issuesFor(
      span,
      code: 'emphasis_side_not_supported_by_v0',
      message:
          'kumihan-v0 only preserves default, over, and left emphasis placement.',
    );
  }

  List<LayoutIssue> _decorationIssues(SourceSpan span, DecorationSide side) {
    if (side == DecorationSide.auto ||
        side == DecorationSide.left ||
        side == DecorationSide.over) {
      return const <LayoutIssue>[];
    }
    return _issuesFor(
      span,
      code: 'decoration_side_not_supported_by_v0',
      message:
          'kumihan-v0 only preserves default, over, and left decoration placement.',
    );
  }

  List<LayoutIssue> _tableBlockIssues(TableBlockNode node) {
    if (node.attributes.isEmpty) {
      return const <LayoutIssue>[];
    }
    return _issuesFor(
      node.span,
      code: 'table_attributes_not_supported_by_v0',
      message: 'kumihan-v0 table rendering does not preserve table attributes.',
    );
  }

  List<LayoutIssue> _issuesFor(
    SourceSpan span, {
    required String code,
    required String message,
  }) {
    final issue = LayoutIssue(
      code: code,
      message: message,
      severity: LayoutIssueSeverity.unsupported,
      span: span,
    );
    _issues.add(issue);
    return List<LayoutIssue>.unmodifiable(<LayoutIssue>[issue]);
  }

  bool _isV0CompatibleTableCell(TableCellNode cell) {
    if (cell.children.length != 1) {
      return false;
    }
    final block = cell.children.single;
    if (block is! ParagraphNode) {
      return false;
    }
    return block.children.every((inline) => inline is TextNode);
  }
}
