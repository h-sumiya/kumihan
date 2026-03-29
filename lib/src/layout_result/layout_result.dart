import '../ast/ast.dart';
import '../layout_ir/layout_ir.dart';

enum LayoutWritingMode { vertical, horizontal }

enum LayoutHitRegionKind { image, link, anchor }

enum LayoutMarkerKind {
  emphasis,
  decoration,
  note,
  kaeriten,
  okurigana,
  editorNote,
  frame,
  unsupported,
}

class LayoutConstraints {
  const LayoutConstraints({
    this.writingMode = LayoutWritingMode.vertical,
    this.lineExtent = 20,
    this.lineGap = 1,
    this.blockGap = 1,
    this.baseFontSize = 1,
    this.rubyScale = 0.5,
    this.scriptScale = 0.6,
    this.noteScale = 0.5,
    this.minTableCellLineExtent = 6,
  });

  final LayoutWritingMode writingMode;
  final double lineExtent;
  final double lineGap;
  final double blockGap;
  final double baseFontSize;
  final double rubyScale;
  final double scriptScale;
  final double noteScale;
  final double minTableCellLineExtent;
}

class LayoutResult {
  const LayoutResult({
    required this.span,
    required this.constraints,
    required this.blocks,
    required this.hitRegions,
    required this.inlineExtent,
    required this.blockExtent,
    this.diagnostics = const <AstDiagnostic>[],
    this.issues = const <LayoutIssue>[],
  });

  final SourceSpan span;
  final LayoutConstraints constraints;
  final List<LayoutBlockResult> blocks;
  final List<LayoutHitRegion> hitRegions;
  final double inlineExtent;
  final double blockExtent;
  final List<AstDiagnostic> diagnostics;
  final List<LayoutIssue> issues;
}

class LayoutBlockStyle {
  const LayoutBlockStyle({
    this.keepWithPrevious = false,
    this.firstIndent = 0,
    this.restIndent = 0,
    this.lineExtent,
    this.alignToFarEdge = false,
    this.flowKind,
    this.frameKind,
    this.frameBorderWidth = 0,
    this.caption = false,
    this.bold = false,
    this.italic = false,
    this.fontScale = 1,
    this.headingLevel,
    this.headingDisplay,
  });

  final bool keepWithPrevious;
  final double firstIndent;
  final double restIndent;
  final double? lineExtent;
  final bool alignToFarEdge;
  final FlowKind? flowKind;
  final FrameKind? frameKind;
  final int frameBorderWidth;
  final bool caption;
  final bool bold;
  final bool italic;
  final double fontScale;
  final HeadingLevel? headingLevel;
  final HeadingDisplay? headingDisplay;
}

class LayoutInlineStyle {
  const LayoutInlineStyle({
    required this.fontScale,
    required this.bold,
    required this.italic,
    required this.caption,
    this.flowKind,
    this.directionKind,
    this.headingLevel,
    this.headingDisplay,
    this.scriptKind,
  });

  final double fontScale;
  final bool bold;
  final bool italic;
  final bool caption;
  final FlowKind? flowKind;
  final DirectionKind? directionKind;
  final HeadingLevel? headingLevel;
  final HeadingDisplay? headingDisplay;
  final ScriptKind? scriptKind;
}

sealed class LayoutBlockResult {
  const LayoutBlockResult({
    required this.span,
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineExtent,
    required this.blockExtent,
    required this.style,
    this.issues = const <LayoutIssue>[],
  });

  final SourceSpan span;
  final double inlineOffset;
  final double blockOffset;
  final double inlineExtent;
  final double blockExtent;
  final LayoutBlockStyle style;
  final List<LayoutIssue> issues;
}

class LayoutParagraphResult extends LayoutBlockResult {
  const LayoutParagraphResult({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.lineGroup,
    super.issues,
  });

  final LayoutLineGroup lineGroup;
}

class LayoutEmptyLineResult extends LayoutBlockResult {
  const LayoutEmptyLineResult({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.lineGroup,
    super.issues,
  });

  final LayoutLineGroup lineGroup;
}

class LayoutUnsupportedBlockResult extends LayoutBlockResult {
  const LayoutUnsupportedBlockResult({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.directive,
    super.issues,
  });

  final SourceDirective directive;
}

class LayoutTableResult extends LayoutBlockResult {
  const LayoutTableResult({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.rows,
    this.attributes = const <String, String>{},
    super.issues,
  });

  final List<LayoutTableRowResult> rows;
  final Map<String, String> attributes;
}

class LayoutTableRowResult {
  const LayoutTableRowResult({
    required this.span,
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineExtent,
    required this.blockExtent,
    required this.cells,
    this.attributes = const <String, String>{},
    this.issues = const <LayoutIssue>[],
  });

  final SourceSpan span;
  final double inlineOffset;
  final double blockOffset;
  final double inlineExtent;
  final double blockExtent;
  final List<LayoutTableCellResult> cells;
  final Map<String, String> attributes;
  final List<LayoutIssue> issues;
}

class LayoutTableCellResult {
  const LayoutTableCellResult({
    required this.span,
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineExtent,
    required this.blockExtent,
    required this.blocks,
    this.attributes = const <String, String>{},
    this.issues = const <LayoutIssue>[],
  });

  final SourceSpan span;
  final double inlineOffset;
  final double blockOffset;
  final double inlineExtent;
  final double blockExtent;
  final List<LayoutBlockResult> blocks;
  final Map<String, String> attributes;
  final List<LayoutIssue> issues;
}

class LayoutLineGroup {
  const LayoutLineGroup({
    required this.span,
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineExtent,
    required this.blockExtent,
    required this.lines,
  });

  final SourceSpan span;
  final double inlineOffset;
  final double blockOffset;
  final double inlineExtent;
  final double blockExtent;
  final List<LayoutLine> lines;
}

class LayoutLine {
  const LayoutLine({
    required this.span,
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineExtent,
    required this.blockExtent,
    required this.textExtent,
    required this.fragments,
    required this.rubies,
    required this.markers,
  });

  final SourceSpan span;
  final double inlineOffset;
  final double blockOffset;
  final double inlineExtent;
  final double blockExtent;
  final double textExtent;
  final List<LayoutFragment> fragments;
  final List<LayoutRubyPlacement> rubies;
  final List<LayoutMarker> markers;
}

sealed class LayoutFragment {
  const LayoutFragment({
    required this.span,
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineExtent,
    required this.blockExtent,
    required this.style,
    this.issues = const <LayoutIssue>[],
  });

  final SourceSpan span;
  final double inlineOffset;
  final double blockOffset;
  final double inlineExtent;
  final double blockExtent;
  final LayoutInlineStyle style;
  final List<LayoutIssue> issues;
}

class LayoutTextFragment extends LayoutFragment {
  const LayoutTextFragment({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.text,
    super.issues,
  });

  final String text;
}

class LayoutGaijiFragment extends LayoutFragment {
  const LayoutGaijiFragment({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.displayText,
    required this.rawNotation,
    required this.description,
    required this.resolved,
    this.jisCode,
    this.unicodeCodePoint,
    super.issues,
  });

  final String displayText;
  final String rawNotation;
  final String description;
  final bool resolved;
  final String? jisCode;
  final String? unicodeCodePoint;
}

class LayoutImageFragment extends LayoutFragment {
  const LayoutImageFragment({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.source,
    this.alt,
    this.className,
    this.width,
    this.height,
    this.attributes = const <String, String>{},
    super.issues,
  });

  final String source;
  final String? alt;
  final String? className;
  final int? width;
  final int? height;
  final Map<String, String> attributes;
}

class LayoutLinkFragment extends LayoutFragment {
  const LayoutLinkFragment({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.target,
    required this.children,
    super.issues,
  });

  final String target;
  final List<LayoutFragment> children;
}

class LayoutAnchorFragment extends LayoutFragment {
  const LayoutAnchorFragment({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.name,
    super.issues,
  });

  final String name;
}

class LayoutNoteFragment extends LayoutFragment {
  const LayoutNoteFragment({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.noteKind,
    required this.text,
    this.upperText,
    this.lowerText,
    super.issues,
  });

  final NoteKind noteKind;
  final String text;
  final String? upperText;
  final String? lowerText;
}

class LayoutUnsupportedFragment extends LayoutFragment {
  const LayoutUnsupportedFragment({
    required super.span,
    required super.inlineOffset,
    required super.blockOffset,
    required super.inlineExtent,
    required super.blockExtent,
    required super.style,
    required this.directive,
    super.issues,
  });

  final SourceDirective directive;
}

class LayoutRubyPlacement {
  const LayoutRubyPlacement({
    required this.span,
    required this.text,
    required this.kind,
    required this.position,
    required this.lineInlineOffset,
    required this.crossOffset,
    required this.blockOffset,
    required this.blockExtent,
    required this.inlineExtent,
    this.interCharacterSpacing = 0,
    this.issues = const <LayoutIssue>[],
  });

  final SourceSpan span;
  final String text;
  final RubyKind kind;
  final RubyPosition position;
  final double lineInlineOffset;
  final double crossOffset;
  final double blockOffset;
  final double blockExtent;
  final double inlineExtent;
  final double interCharacterSpacing;
  final List<LayoutIssue> issues;
}

class LayoutMarker {
  const LayoutMarker({
    required this.kind,
    required this.span,
    required this.lineInlineOffset,
    required this.crossOffset,
    required this.blockOffset,
    required this.blockExtent,
    required this.inlineExtent,
    this.text,
    this.emphasisMark,
    this.emphasisSide,
    this.decorationKind,
    this.decorationSide,
    this.noteKind,
    this.frameKind,
    this.repeatCount,
    this.issues = const <LayoutIssue>[],
  });

  final LayoutMarkerKind kind;
  final SourceSpan span;
  final double lineInlineOffset;
  final double crossOffset;
  final double blockOffset;
  final double blockExtent;
  final double inlineExtent;
  final String? text;
  final EmphasisMark? emphasisMark;
  final EmphasisSide? emphasisSide;
  final DecorationKind? decorationKind;
  final DecorationSide? decorationSide;
  final NoteKind? noteKind;
  final FrameKind? frameKind;
  final int? repeatCount;
  final List<LayoutIssue> issues;
}

class LayoutHitRegion {
  const LayoutHitRegion({
    required this.kind,
    required this.span,
    required this.inlineOffset,
    required this.blockOffset,
    required this.inlineExtent,
    required this.blockExtent,
    required this.data,
  });

  final LayoutHitRegionKind kind;
  final SourceSpan span;
  final double inlineOffset;
  final double blockOffset;
  final double inlineExtent;
  final double blockExtent;
  final String data;
}
