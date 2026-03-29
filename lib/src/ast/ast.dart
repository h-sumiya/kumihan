typedef AstAttributes = Map<String, String>;

enum AstDiagnosticSeverity { info, warning, error }

enum RubyKind { phonetic, annotation }

enum RubyPosition { over, under, left, right }

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
    this.category = 'unknown',
    this.attributes = const <String, String>{},
  });

  final String format;
  final String rawText;
  final String body;
  final String category;
  final AstAttributes attributes;
  final SourceSpan span;

  Map<String, Object> toDebugMap() {
    return <String, Object>{
      'format': format,
      'rawText': rawText,
      'body': body,
      'category': category,
      'attributes': Map<String, String>.from(attributes),
      'span': span.toDebugMap(),
    };
  }
}

abstract class AstNode {
  const AstNode(this.span);

  final SourceSpan span;

  String get debugType;

  Map<String, Object?> toDebugMap();

  Map<String, Object?> debugBase() {
    return <String, Object?>{'type': debugType, 'span': span.toDebugMap()};
  }
}

abstract class BlockNode extends AstNode {
  const BlockNode(super.span);
}

abstract class InlineNode extends AstNode {
  const InlineNode(super.span);
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
  const ParagraphNode({required SourceSpan span, required this.children})
    : super(span);

  final List<InlineNode> children;

  @override
  String get debugType => 'paragraph';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
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

class ContainerBlockNode extends BlockNode {
  const ContainerBlockNode({
    required SourceSpan span,
    required this.kind,
    required this.children,
    required this.openDirective,
    this.variant,
    this.attributes = const <String, String>{},
    this.closeDirective,
    this.isClosed = true,
  }) : super(span);

  final String kind;
  final String? variant;
  final AstAttributes attributes;
  final List<BlockNode> children;
  final SourceDirective openDirective;
  final SourceDirective? closeDirective;
  final bool isClosed;

  @override
  String get debugType => 'containerBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind;
    map['variant'] = variant;
    map['attributes'] = Map<String, String>.from(attributes);
    map['isClosed'] = isClosed;
    map['openDirective'] = openDirective.toDebugMap();
    map['closeDirective'] = closeDirective?.toDebugMap();
    map['children'] = children.map((node) => node.toDebugMap()).toList();
    return map;
  }
}

class DirectiveBlockNode extends BlockNode {
  const DirectiveBlockNode({
    required SourceSpan span,
    required this.directive,
    this.classification = 'opaque',
  }) : super(span);

  final SourceDirective directive;
  final String classification;

  @override
  String get debugType => 'directiveBlock';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['classification'] = classification;
    map['directive'] = directive.toDebugMap();
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

class InlineContainerNode extends InlineNode {
  const InlineContainerNode({
    required SourceSpan span,
    required this.kind,
    required this.children,
    required this.openDirective,
    this.variant,
    this.attributes = const <String, String>{},
    this.closeDirective,
    this.isClosed = true,
  }) : super(span);

  final String kind;
  final String? variant;
  final AstAttributes attributes;
  final List<InlineNode> children;
  final SourceDirective openDirective;
  final SourceDirective? closeDirective;
  final bool isClosed;

  @override
  String get debugType => 'inlineContainer';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind;
    map['variant'] = variant;
    map['attributes'] = Map<String, String>.from(attributes);
    map['isClosed'] = isClosed;
    map['openDirective'] = openDirective.toDebugMap();
    map['closeDirective'] = closeDirective?.toDebugMap();
    map['children'] = children.map((node) => node.toDebugMap()).toList();
    return map;
  }
}

class InlineAnnotationNode extends InlineNode {
  const InlineAnnotationNode({
    required SourceSpan span,
    required this.kind,
    required this.text,
    this.attributes = const <String, String>{},
    this.sourceDirective,
  }) : super(span);

  final String kind;
  final String text;
  final AstAttributes attributes;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'inlineAnnotation';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['kind'] = kind;
    map['text'] = text;
    map['attributes'] = Map<String, String>.from(attributes);
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class LineBreakNode extends InlineNode {
  const LineBreakNode({
    required SourceSpan span,
    this.reason = 'explicit',
    this.sourceDirective,
  }) : super(span);

  final String reason;
  final SourceDirective? sourceDirective;

  @override
  String get debugType => 'lineBreak';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['reason'] = reason;
    map['sourceDirective'] = sourceDirective?.toDebugMap();
    return map;
  }
}

class DirectiveInlineNode extends InlineNode {
  const DirectiveInlineNode({
    required SourceSpan span,
    required this.directive,
    this.classification = 'opaque',
  }) : super(span);

  final SourceDirective directive;
  final String classification;

  @override
  String get debugType => 'directiveInline';

  @override
  Map<String, Object?> toDebugMap() {
    final map = debugBase();
    map['classification'] = classification;
    map['directive'] = directive.toDebugMap();
    return map;
  }
}
