import '../ast/ast.dart';

typedef LayoutIrAttributes = Map<String, String>;

enum LayoutIssueSeverity { info, warning, unsupported }

class LayoutIssue {
  const LayoutIssue({
    required this.code,
    required this.message,
    required this.severity,
    required this.span,
  });

  final String code;
  final String message;
  final LayoutIssueSeverity severity;
  final SourceSpan span;
}

sealed class LayoutNode {
  const LayoutNode({required this.span, this.issues = const <LayoutIssue>[]});

  final SourceSpan span;
  final List<LayoutIssue> issues;
}

sealed class LayoutBlock extends LayoutNode {
  const LayoutBlock({required super.span, super.issues});
}

sealed class LayoutInline extends LayoutNode {
  const LayoutInline({required super.span, super.issues});
}

sealed class LayoutContainerBlock extends LayoutBlock {
  const LayoutContainerBlock({
    required super.span,
    required this.children,
    this.isClosed = true,
    super.issues,
  });

  final List<LayoutBlock> children;
  final bool isClosed;
}

sealed class LayoutContainerInline extends LayoutInline {
  const LayoutContainerInline({
    required super.span,
    required this.children,
    this.isClosed = true,
    super.issues,
  });

  final List<LayoutInline> children;
  final bool isClosed;
}

class LayoutDocument extends LayoutNode {
  const LayoutDocument({
    required super.span,
    required this.children,
    this.diagnostics = const <AstDiagnostic>[],
    super.issues,
  });

  final List<LayoutBlock> children;
  final List<AstDiagnostic> diagnostics;

  List<LayoutIssue> get compatibilityIssues => issues;
}

class LayoutParagraph extends LayoutBlock {
  const LayoutParagraph({
    required super.span,
    required this.children,
    this.keepWithPrevious = false,
    super.issues,
  });

  final List<LayoutInline> children;
  final bool keepWithPrevious;
}

class LayoutEmptyLine extends LayoutBlock {
  const LayoutEmptyLine({required super.span, super.issues});
}

class LayoutUnsupportedBlock extends LayoutBlock {
  const LayoutUnsupportedBlock({
    required super.span,
    required this.directive,
    super.issues,
  });

  final SourceDirective directive;
}

class LayoutIndentBlock extends LayoutContainerBlock {
  const LayoutIndentBlock({
    required super.span,
    required super.children,
    required this.width,
    super.isClosed,
    super.issues,
  });

  final int? width;
}

class LayoutAlignmentBlock extends LayoutContainerBlock {
  const LayoutAlignmentBlock({
    required super.span,
    required super.children,
    required this.kind,
    super.isClosed,
    super.issues,
  });

  final BlockAlignmentKind kind;
}

class LayoutJizumeBlock extends LayoutContainerBlock {
  const LayoutJizumeBlock({
    required super.span,
    required super.children,
    required this.width,
    super.isClosed,
    super.issues,
  });

  final int? width;
}

class LayoutFlowBlock extends LayoutContainerBlock {
  const LayoutFlowBlock({
    required super.span,
    required super.children,
    required this.kind,
    super.isClosed,
    super.issues,
  });

  final FlowKind kind;
}

class LayoutCaptionBlock extends LayoutContainerBlock {
  const LayoutCaptionBlock({
    required super.span,
    required super.children,
    super.isClosed,
    super.issues,
  });
}

class LayoutFrameBlock extends LayoutContainerBlock {
  const LayoutFrameBlock({
    required super.span,
    required super.children,
    required this.kind,
    this.borderWidth = 1,
    super.isClosed,
    super.issues,
  });

  final FrameKind kind;
  final int borderWidth;
}

class LayoutStyledBlock extends LayoutContainerBlock {
  const LayoutStyledBlock({
    required super.span,
    required super.children,
    required this.style,
    super.isClosed,
    super.issues,
  });

  final TextStyleKind style;
}

class LayoutFontSizeBlock extends LayoutContainerBlock {
  const LayoutFontSizeBlock({
    required super.span,
    required super.children,
    required this.kind,
    required this.steps,
    super.isClosed,
    super.issues,
  });

  final FontSizeKind kind;
  final int steps;
}

class LayoutHeadingBlock extends LayoutContainerBlock {
  const LayoutHeadingBlock({
    required super.span,
    required super.children,
    required this.level,
    required this.display,
    super.isClosed,
    super.issues,
  });

  final HeadingLevel level;
  final HeadingDisplay display;
}

class LayoutTableBlock extends LayoutBlock {
  const LayoutTableBlock({
    required super.span,
    required this.rows,
    this.attributes = const <String, String>{},
    super.issues,
  });

  final List<LayoutTableRow> rows;
  final LayoutIrAttributes attributes;
}

class LayoutTableRow extends LayoutNode {
  const LayoutTableRow({
    required super.span,
    required this.cells,
    this.attributes = const <String, String>{},
    super.issues,
  });

  final List<LayoutTableCell> cells;
  final LayoutIrAttributes attributes;
}

class LayoutTableCell extends LayoutNode {
  const LayoutTableCell({
    required super.span,
    required this.children,
    this.attributes = const <String, String>{},
    super.issues,
  });

  final List<LayoutBlock> children;
  final LayoutIrAttributes attributes;
}

class LayoutTextInline extends LayoutInline {
  const LayoutTextInline({
    required super.span,
    required this.text,
    super.issues,
  });

  final String text;
}

class LayoutGaijiInline extends LayoutInline {
  const LayoutGaijiInline({
    required super.span,
    required this.rawNotation,
    required this.description,
    this.jisCode,
    this.unicodeCodePoint,
    super.issues,
  });

  final String rawNotation;
  final String description;
  final String? jisCode;
  final String? unicodeCodePoint;
}

class LayoutUnresolvedGaijiInline extends LayoutInline {
  const LayoutUnresolvedGaijiInline({
    required super.span,
    required this.rawNotation,
    required this.text,
    this.sourceDirective,
    super.issues,
  });

  final String rawNotation;
  final String text;
  final SourceDirective? sourceDirective;
}

class LayoutImageInline extends LayoutInline {
  const LayoutImageInline({
    required super.span,
    required this.source,
    this.alt,
    this.className,
    this.width,
    this.height,
    this.attributes = const <String, String>{},
    this.sourceDirective,
    super.issues,
  });

  final String source;
  final String? alt;
  final String? className;
  final int? width;
  final int? height;
  final LayoutIrAttributes attributes;
  final SourceDirective? sourceDirective;
}

class LayoutLinkInline extends LayoutContainerInline {
  const LayoutLinkInline({
    required super.span,
    required super.children,
    required this.target,
    this.sourceDirective,
    super.isClosed,
    super.issues,
  });

  final String target;
  final SourceDirective? sourceDirective;
}

class LayoutAnchorInline extends LayoutInline {
  const LayoutAnchorInline({
    required super.span,
    required this.name,
    this.sourceDirective,
    super.issues,
  });

  final String name;
  final SourceDirective? sourceDirective;
}

class LayoutRubyInline extends LayoutInline {
  const LayoutRubyInline({
    required super.span,
    required this.base,
    required this.text,
    required this.kind,
    required this.position,
    this.sourceDirective,
    super.issues,
  });

  final List<LayoutInline> base;
  final String text;
  final RubyKind kind;
  final RubyPosition position;
  final SourceDirective? sourceDirective;
}

class LayoutDirectionInline extends LayoutContainerInline {
  const LayoutDirectionInline({
    required super.span,
    required super.children,
    required this.kind,
    super.isClosed,
    super.issues,
  });

  final DirectionKind kind;
}

class LayoutFlowInline extends LayoutContainerInline {
  const LayoutFlowInline({
    required super.span,
    required super.children,
    required this.kind,
    super.isClosed,
    super.issues,
  });

  final FlowKind kind;
}

class LayoutCaptionInline extends LayoutContainerInline {
  const LayoutCaptionInline({
    required super.span,
    required super.children,
    super.isClosed,
    super.issues,
  });
}

class LayoutFrameInline extends LayoutContainerInline {
  const LayoutFrameInline({
    required super.span,
    required super.children,
    required this.kind,
    this.borderWidth = 1,
    super.isClosed,
    super.issues,
  });

  final FrameKind kind;
  final int borderWidth;
}

class LayoutNoteInline extends LayoutContainerInline {
  const LayoutNoteInline({
    required super.span,
    required super.children,
    required this.kind,
    super.isClosed,
    super.issues,
  });

  final NoteKind kind;
}

class LayoutStyledInline extends LayoutContainerInline {
  const LayoutStyledInline({
    required super.span,
    required super.children,
    required this.style,
    super.isClosed,
    super.issues,
  });

  final TextStyleKind style;
}

class LayoutFontSizeInline extends LayoutContainerInline {
  const LayoutFontSizeInline({
    required super.span,
    required super.children,
    required this.kind,
    required this.steps,
    super.isClosed,
    super.issues,
  });

  final FontSizeKind kind;
  final int steps;
}

class LayoutHeadingInline extends LayoutContainerInline {
  const LayoutHeadingInline({
    required super.span,
    required super.children,
    required this.level,
    required this.display,
    super.isClosed,
    super.issues,
  });

  final HeadingLevel level;
  final HeadingDisplay display;
}

class LayoutEmphasisInline extends LayoutContainerInline {
  const LayoutEmphasisInline({
    required super.span,
    required super.children,
    required this.mark,
    this.side = EmphasisSide.auto,
    super.isClosed,
    super.issues,
  });

  final EmphasisMark mark;
  final EmphasisSide side;
}

class LayoutDecorationInline extends LayoutContainerInline {
  const LayoutDecorationInline({
    required super.span,
    required super.children,
    required this.kind,
    this.side = DecorationSide.auto,
    super.isClosed,
    super.issues,
  });

  final DecorationKind kind;
  final DecorationSide side;
}

class LayoutScriptInline extends LayoutInline {
  const LayoutScriptInline({
    required super.span,
    required this.kind,
    required this.text,
    this.sourceDirective,
    super.issues,
  });

  final ScriptKind kind;
  final String text;
  final SourceDirective? sourceDirective;
}

class LayoutKaeritenInline extends LayoutInline {
  const LayoutKaeritenInline({
    required super.span,
    required this.text,
    this.sourceDirective,
    super.issues,
  });

  final String text;
  final SourceDirective? sourceDirective;
}

class LayoutOkuriganaInline extends LayoutInline {
  const LayoutOkuriganaInline({
    required super.span,
    required this.text,
    this.sourceDirective,
    super.issues,
  });

  final String text;
  final SourceDirective? sourceDirective;
}

class LayoutEditorNoteInline extends LayoutInline {
  const LayoutEditorNoteInline({
    required super.span,
    required this.text,
    this.sourceDirective,
    super.issues,
  });

  final String text;
  final SourceDirective? sourceDirective;
}

class LayoutLineBreakInline extends LayoutInline {
  const LayoutLineBreakInline({
    required super.span,
    this.kind = LineBreakKind.explicit,
    this.sourceDirective,
    super.issues,
  });

  final LineBreakKind kind;
  final SourceDirective? sourceDirective;
}

class LayoutUnsupportedInline extends LayoutInline {
  const LayoutUnsupportedInline({
    required super.span,
    required this.directive,
    super.issues,
  });

  final SourceDirective directive;
}
