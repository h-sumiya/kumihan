typedef AstAttributes = Map<String, String>;

enum AstDiagnosticSeverity { info, warning, error }

enum SourceDirectiveCategory {
  opaque,
  blockOpen,
  blockClose,
  inlineOpen,
  inlineClose,
  inlineReference,
  inlineLineBreak,
}

enum RubyKind { phonetic, annotation }

enum RubyPosition { over, under, left, right }

enum TextStyleKind { bold, italic }

enum FontSizeKind { larger, smaller }

enum HeadingLevel { small, medium, large }

enum HeadingDisplay { normal, dogyo, mado }

enum BlockAlignmentKind { chitsuki, jiage }

enum FlowKind { yokogumi }

enum DirectionKind { tateChuYoko }

enum NoteKind { warichu, warigaki }

enum FrameKind { keigakomi }

enum EmphasisMark {
  sesameDot,
  whiteSesameDot,
  blackCircle,
  whiteCircle,
  blackTriangle,
  whiteTriangle,
  bullseye,
  fisheye,
  saltire,
}

enum EmphasisSide { auto, over, under, left, right }

enum DecorationKind {
  underlineSolid,
  underlineDouble,
  underlineDotted,
  underlineDashed,
  underlineWave,
}

enum DecorationSide { auto, over, under, left, right }

enum ScriptKind { superscript, subscript }

enum LineBreakKind { explicit }

class SourceLocation {
  const SourceLocation({
    required this.offset,
    required this.line,
    required this.column,
  });

  final int offset;
  final int line;
  final int column;

  Map<String, Object> toDebugMap() {
    return <String, Object>{'offset': offset, 'line': line, 'column': column};
  }
}

class SourceSpan {
  const SourceSpan({required this.start, required this.end});

  final SourceLocation start;
  final SourceLocation end;

  Map<String, Object> toDebugMap() {
    return <String, Object>{
      'start': start.toDebugMap(),
      'end': end.toDebugMap(),
    };
  }
}

class AstDiagnostic {
  const AstDiagnostic({
    required this.code,
    required this.message,
    required this.severity,
    required this.span,
  });

  final String code;
  final String message;
  final AstDiagnosticSeverity severity;
  final SourceSpan span;

  Map<String, Object> toDebugMap() {
    return <String, Object>{
      'code': code,
      'message': message,
      'severity': severity.name,
      'span': span.toDebugMap(),
    };
  }
}

class SourceDirective {
  const SourceDirective({
    required this.format,
    required this.rawText,
    required this.body,
    required this.span,
    this.category = SourceDirectiveCategory.opaque,
    this.attributes = const <String, String>{},
  });

  final String format;
  final String rawText;
  final String body;
  final SourceDirectiveCategory category;
  final AstAttributes attributes;
  final SourceSpan span;

  SourceDirective copyWith({
    SourceDirectiveCategory? category,
    AstAttributes? attributes,
  }) {
    return SourceDirective(
      format: format,
      rawText: rawText,
      body: body,
      span: span,
      category: category ?? this.category,
      attributes: attributes ?? this.attributes,
    );
  }

  Map<String, Object> toDebugMap() {
    return <String, Object>{
      'format': format,
      'rawText': rawText,
      'body': body,
      'category': category.name,
      'attributes': Map<String, String>.from(attributes),
      'span': span.toDebugMap(),
    };
  }
}

sealed class AstNode {
  const AstNode(this.span);

  final SourceSpan span;

  String get debugType;

  Map<String, Object?> toDebugMap();

  Map<String, Object?> debugBase() {
    return <String, Object?>{'type': debugType, 'span': span.toDebugMap()};
  }
}

sealed class BlockNode extends AstNode {
  const BlockNode(super.span);
}

sealed class InlineNode extends AstNode {
  const InlineNode(super.span);
}

sealed class DirectiveContainerBlockNode extends BlockNode {
  const DirectiveContainerBlockNode({
    required SourceSpan span,
    required this.children,
    required this.openDirective,
    this.closeDirective,
    this.isClosed = true,
  }) : super(span);

  final List<BlockNode> children;
  final SourceDirective openDirective;
  final SourceDirective? closeDirective;
  final bool isClosed;

  void fillDebugMap(Map<String, Object?> map) {
    map['isClosed'] = isClosed;
    map['openDirective'] = openDirective.toDebugMap();
    map['closeDirective'] = closeDirective?.toDebugMap();
    map['children'] = children.map((node) => node.toDebugMap()).toList();
  }
}

sealed class DirectiveContainerInlineNode extends InlineNode {
  const DirectiveContainerInlineNode({
    required SourceSpan span,
    required this.children,
    required this.openDirective,
    this.closeDirective,
    this.isClosed = true,
  }) : super(span);

  final List<InlineNode> children;
  final SourceDirective openDirective;
  final SourceDirective? closeDirective;
  final bool isClosed;

  void fillDebugMap(Map<String, Object?> map) {
    map['isClosed'] = isClosed;
    map['openDirective'] = openDirective.toDebugMap();
    map['closeDirective'] = closeDirective?.toDebugMap();
    map['children'] = children.map((node) => node.toDebugMap()).toList();
  }
}

class DocumentNode extends AstNode {
  const DocumentNode({
    required SourceSpan span,
    required this.children,
    this.diagnostics = const <AstDiagnostic>[],
  }) : super(span);

  final List<BlockNode> children;
  final List<AstDiagnostic> diagnostics;

  @override
  String get debugType => 'document';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['children'] = children.map((node) => node.toDebugMap()).toList();
    map['diagnostics'] = diagnostics
        .map((diagnostic) => diagnostic.toDebugMap())
        .toList();
    return map;
  }
}

class ParagraphNode extends BlockNode {
  const ParagraphNode({
    required SourceSpan span,
    required this.children,
    this.keepWithPrevious = false,
  }) : super(span);

  final List<InlineNode> children;
  final bool keepWithPrevious;

  @override
  String get debugType => 'paragraph';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['keepWithPrevious'] = keepWithPrevious;
    map['children'] = children.map((node) => node.toDebugMap()).toList();
    return map;
  }
}

class EmptyLineNode extends BlockNode {
  const EmptyLineNode({required SourceSpan span}) : super(span);

  @override
  String get debugType => 'emptyLine';

  @override
  Map<String, Object?> toDebugMap() => debugBase();
}

class OpaqueBlockNode extends BlockNode {
  const OpaqueBlockNode({required SourceSpan span, required this.directive})
    : super(span);

  final SourceDirective directive;

  @override
  String get debugType => 'opaqueBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['directive'] = directive.toDebugMap();
    return map;
  }
}

class IndentBlockNode extends DirectiveContainerBlockNode {
  const IndentBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.width,
    super.closeDirective,
    super.isClosed,
  });

  final int? width;

  @override
  String get debugType => 'indentBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['width'] = width;
    fillDebugMap(map);
    return map;
  }
}

class AlignmentBlockNode extends DirectiveContainerBlockNode {
  const AlignmentBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    super.closeDirective,
    super.isClosed,
  });

  final BlockAlignmentKind kind;

  @override
  String get debugType => 'alignmentBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    fillDebugMap(map);
    return map;
  }
}

class JizumeBlockNode extends DirectiveContainerBlockNode {
  const JizumeBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.width,
    super.closeDirective,
    super.isClosed,
  });

  final int? width;

  @override
  String get debugType => 'jizumeBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['width'] = width;
    fillDebugMap(map);
    return map;
  }
}

class FlowBlockNode extends DirectiveContainerBlockNode {
  const FlowBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    super.closeDirective,
    super.isClosed,
  });

  final FlowKind kind;

  @override
  String get debugType => 'flowBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    fillDebugMap(map);
    return map;
  }
}

class CaptionBlockNode extends DirectiveContainerBlockNode {
  const CaptionBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    super.closeDirective,
    super.isClosed,
  });

  @override
  String get debugType => 'captionBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    fillDebugMap(map);
    return map;
  }
}

class FrameBlockNode extends DirectiveContainerBlockNode {
  const FrameBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    this.borderWidth = 1,
    super.closeDirective,
    super.isClosed,
  });

  final FrameKind kind;
  final int borderWidth;

  @override
  String get debugType => 'frameBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['borderWidth'] = borderWidth;
    fillDebugMap(map);
    return map;
  }
}

class StyledBlockNode extends DirectiveContainerBlockNode {
  const StyledBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.style,
    super.closeDirective,
    super.isClosed,
  });

  final TextStyleKind style;

  @override
  String get debugType => 'styledBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['style'] = style.name;
    fillDebugMap(map);
    return map;
  }
}

class FontSizeBlockNode extends DirectiveContainerBlockNode {
  const FontSizeBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    required this.steps,
    super.closeDirective,
    super.isClosed,
  });

  final FontSizeKind kind;
  final int steps;

  @override
  String get debugType => 'fontSizeBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['steps'] = steps;
    fillDebugMap(map);
    return map;
  }
}

class HeadingBlockNode extends DirectiveContainerBlockNode {
  const HeadingBlockNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.level,
    required this.display,
    super.closeDirective,
    super.isClosed,
  });

  final HeadingLevel level;
  final HeadingDisplay display;

  @override
  String get debugType => 'headingBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['level'] = level.name;
    map['display'] = display.name;
    fillDebugMap(map);
    return map;
  }
}

class TableBlockNode extends BlockNode {
  const TableBlockNode({
    required SourceSpan span,
    required this.rows,
    this.attributes = const <String, String>{},
  }) : super(span);

  final List<TableRowNode> rows;
  final AstAttributes attributes;

  @override
  String get debugType => 'table';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['attributes'] = Map<String, String>.from(attributes);
    map['rows'] = rows.map((row) => row.toDebugMap()).toList();
    return map;
  }
}

class TableRowNode extends AstNode {
  const TableRowNode({
    required SourceSpan span,
    required this.cells,
    this.attributes = const <String, String>{},
  }) : super(span);

  final List<TableCellNode> cells;
  final AstAttributes attributes;

  @override
  String get debugType => 'tableRow';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['attributes'] = Map<String, String>.from(attributes);
    map['cells'] = cells.map((cell) => cell.toDebugMap()).toList();
    return map;
  }
}

class TableCellNode extends AstNode {
  const TableCellNode({
    required SourceSpan span,
    required this.children,
    this.attributes = const <String, String>{},
  }) : super(span);

  final List<BlockNode> children;
  final AstAttributes attributes;

  @override
  String get debugType => 'tableCell';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['attributes'] = Map<String, String>.from(attributes);
    map['children'] = children.map((node) => node.toDebugMap()).toList();
    return map;
  }
}

class TextNode extends InlineNode {
  const TextNode({required SourceSpan span, required this.text}) : super(span);

  final String text;

  @override
  String get debugType => 'text';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['text'] = text;
    return map;
  }
}

class GaijiNode extends InlineNode {
  const GaijiNode({
    required SourceSpan span,
    required this.rawNotation,
    required this.description,
    this.jisCode,
    this.unicodeCodePoint,
  }) : super(span);

  final String rawNotation;
  final String description;
  final String? jisCode;
  final String? unicodeCodePoint;

  @override
  String get debugType => 'gaiji';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['rawNotation'] = rawNotation;
    map['description'] = description;
    map['jisCode'] = jisCode;
    map['unicodeCodePoint'] = unicodeCodePoint;
    return map;
  }
}

class UnresolvedGaijiNode extends InlineNode {
  const UnresolvedGaijiNode({
    required SourceSpan span,
    required this.rawNotation,
    required this.text,
    this.sourceDirective,
  }) : super(span);

  final String rawNotation;
  final String text;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'unresolvedGaiji';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['rawNotation'] = rawNotation;
    map['text'] = text;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class ImageNode extends InlineNode {
  const ImageNode({
    required SourceSpan span,
    required this.source,
    this.alt,
    this.className,
    this.width,
    this.height,
    this.attributes = const <String, String>{},
    this.sourceDirective,
  }) : super(span);

  final String source;
  final String? alt;
  final String? className;
  final int? width;
  final int? height;
  final AstAttributes attributes;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'image';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['source'] = source;
    map['alt'] = alt;
    map['className'] = className;
    map['width'] = width;
    map['height'] = height;
    map['attributes'] = Map<String, String>.from(attributes);
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class LinkNode extends InlineNode {
  const LinkNode({
    required SourceSpan span,
    required this.children,
    required this.target,
    this.sourceDirective,
    this.isClosed = true,
  }) : super(span);

  final List<InlineNode> children;
  final String target;
  final SourceDirective? sourceDirective;
  final bool isClosed;

  @override
  String get debugType => 'link';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['target'] = target;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    map['children'] = children.map((node) => node.toDebugMap()).toList();
    map['isClosed'] = isClosed;
    return map;
  }
}

class AnchorNode extends InlineNode {
  const AnchorNode({
    required SourceSpan span,
    required this.name,
    this.sourceDirective,
  }) : super(span);

  final String name;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'anchor';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['name'] = name;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class RubyNode extends InlineNode {
  const RubyNode({
    required SourceSpan span,
    required this.base,
    required this.text,
    required this.kind,
    required this.position,
    this.sourceDirective,
  }) : super(span);

  final List<InlineNode> base;
  final String text;
  final RubyKind kind;
  final RubyPosition position;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'ruby';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['position'] = position.name;
    map['text'] = text;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    map['base'] = base.map((node) => node.toDebugMap()).toList();
    return map;
  }
}

class DirectionInlineNode extends DirectiveContainerInlineNode {
  const DirectionInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    super.closeDirective,
    super.isClosed,
  });

  final DirectionKind kind;

  @override
  String get debugType => 'directionInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    fillDebugMap(map);
    return map;
  }
}

class FlowInlineNode extends DirectiveContainerInlineNode {
  const FlowInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    super.closeDirective,
    super.isClosed,
  });

  final FlowKind kind;

  @override
  String get debugType => 'flowInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    fillDebugMap(map);
    return map;
  }
}

class CaptionInlineNode extends DirectiveContainerInlineNode {
  const CaptionInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    super.closeDirective,
    super.isClosed,
  });

  @override
  String get debugType => 'captionInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    fillDebugMap(map);
    return map;
  }
}

class FrameInlineNode extends DirectiveContainerInlineNode {
  const FrameInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    this.borderWidth = 1,
    super.closeDirective,
    super.isClosed,
  });

  final FrameKind kind;
  final int borderWidth;

  @override
  String get debugType => 'frameInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['borderWidth'] = borderWidth;
    fillDebugMap(map);
    return map;
  }
}

class NoteInlineNode extends DirectiveContainerInlineNode {
  const NoteInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    super.closeDirective,
    super.isClosed,
  });

  final NoteKind kind;

  @override
  String get debugType => 'noteInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    fillDebugMap(map);
    return map;
  }
}

class StyledInlineNode extends DirectiveContainerInlineNode {
  const StyledInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.style,
    super.closeDirective,
    super.isClosed,
  });

  final TextStyleKind style;

  @override
  String get debugType => 'styledInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['style'] = style.name;
    fillDebugMap(map);
    return map;
  }
}

class FontSizeInlineNode extends DirectiveContainerInlineNode {
  const FontSizeInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    required this.steps,
    super.closeDirective,
    super.isClosed,
  });

  final FontSizeKind kind;
  final int steps;

  @override
  String get debugType => 'fontSizeInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['steps'] = steps;
    fillDebugMap(map);
    return map;
  }
}

class HeadingInlineNode extends DirectiveContainerInlineNode {
  const HeadingInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.level,
    required this.display,
    super.closeDirective,
    super.isClosed,
  });

  final HeadingLevel level;
  final HeadingDisplay display;

  @override
  String get debugType => 'headingInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['level'] = level.name;
    map['display'] = display.name;
    fillDebugMap(map);
    return map;
  }
}

class EmphasisInlineNode extends DirectiveContainerInlineNode {
  const EmphasisInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.mark,
    this.side = EmphasisSide.auto,
    super.closeDirective,
    super.isClosed,
  });

  final EmphasisMark mark;
  final EmphasisSide side;

  @override
  String get debugType => 'emphasisInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['mark'] = mark.name;
    map['side'] = side.name;
    fillDebugMap(map);
    return map;
  }
}

class DecorationInlineNode extends DirectiveContainerInlineNode {
  const DecorationInlineNode({
    required super.span,
    required super.children,
    required super.openDirective,
    required this.kind,
    this.side = DecorationSide.auto,
    super.closeDirective,
    super.isClosed,
  });

  final DecorationKind kind;
  final DecorationSide side;

  @override
  String get debugType => 'decorationInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['side'] = side.name;
    fillDebugMap(map);
    return map;
  }
}

class ScriptInlineNode extends InlineNode {
  const ScriptInlineNode({
    required SourceSpan span,
    required this.kind,
    required this.text,
    this.sourceDirective,
  }) : super(span);

  final ScriptKind kind;
  final String text;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'scriptInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['text'] = text;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class KaeritenNode extends InlineNode {
  const KaeritenNode({
    required SourceSpan span,
    required this.text,
    this.sourceDirective,
  }) : super(span);

  final String text;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'kaeriten';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['text'] = text;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class OkuriganaNode extends InlineNode {
  const OkuriganaNode({
    required SourceSpan span,
    required this.text,
    this.sourceDirective,
  }) : super(span);

  final String text;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'okurigana';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['text'] = text;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class EditorNoteNode extends InlineNode {
  const EditorNoteNode({
    required SourceSpan span,
    required this.text,
    this.sourceDirective,
  }) : super(span);

  final String text;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'editorNote';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['text'] = text;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class LineBreakNode extends InlineNode {
  const LineBreakNode({
    required SourceSpan span,
    this.kind = LineBreakKind.explicit,
    this.sourceDirective,
  }) : super(span);

  final LineBreakKind kind;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'lineBreak';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind.name;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class OpaqueInlineNode extends InlineNode {
  const OpaqueInlineNode({required SourceSpan span, required this.directive})
    : super(span);

  final SourceDirective directive;

  @override
  String get debugType => 'opaqueInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['directive'] = directive.toDebugMap();
    return map;
  }
}
